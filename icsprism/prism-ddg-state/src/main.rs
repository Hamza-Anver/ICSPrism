use std::fs::File;
use std::path::PathBuf;

use clap::Parser;
use libafl::{
    corpus::{InMemoryCorpus, OnDiskCorpus},
    events::SimpleEventManager,
    executors::{ExitKind, InProcessForkExecutor},
    feedback_or,
    feedbacks::{CrashFeedback, MaxMapFeedback},
    fuzzer::{Fuzzer, StdFuzzer},
    generators::RandBytesGenerator,
    inputs::{BytesInput, HasTargetBytes},
    monitors::SimpleMonitor,
    mutators::{HavocScheduledMutator, havoc_mutations},
    observers::{HitcountsMapObserver, StdMapObserver},
    schedulers::QueueScheduler,
    stages::StdMutationalStage,
    state::StdState,
};
use libafl_bolts::{
    AsSliceMut,
    rands::StdRand,
    shmem::{ShMemProvider, UnixShMemProvider},
    tuples::{Merge, tuple_list},
};
use prism_runtime::{
    execute_testcase_with_state_snapshots, harness_dimensions, load_config, required_input_len,
};
use prism_runtime::fuzzing::{
    AccumulationWindowMutator, DdgByteMutator, Ddg, FieldRole, FieldValueMutator,
    FramePatternMutator, InputRangeMutator, ProgramLayout, StateHashConfigRaw,
    StateHashField, WeightsJson, build_ddg_distances, build_name_scores,
    build_runtime_input_fields, compute_bucket, ddg_byte_weights,
    expand_weights_for_sequence, infer_i16_targets_from_ddg, input_fields_from_weights_json,
    parse_state_hash_config, read_i32_from_state,
    COV_MAP_SIZE, STATE_MAP_SIZE,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STATE_HEARTBEAT_INTERVAL_SECS: u64 = 5;

static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();
static mut STATE_MAP_PTR: *mut u8 = std::ptr::null_mut();

// ---------------------------------------------------------------------------
// SanitizerCoverage callbacks
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn __sanitizer_cov_trace_pc_guard_init(mut start: *mut u32, stop: *mut u32) {
    unsafe {
        if start == stop || *start != 0 {
            return;
        }
        let mut idx = 0u32;
        while start < stop {
            *start = idx % COV_MAP_SIZE as u32;
            idx += 1;
            start = start.add(1);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn __sanitizer_cov_trace_pc_guard(guard: *mut u32) {
    unsafe {
        if COV_MAP_PTR.is_null() {
            return;
        }
        let idx = *guard as usize;
        if idx < COV_MAP_SIZE {
            let b = COV_MAP_PTR.add(idx);
            *b = (*b).wrapping_add(1);
        }
    }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

#[derive(Parser, Debug)]
#[command(
    name = "prism-ddg-state",
    about = "DDG-guided ST fuzzer with state-hash secondary coverage"
)]
struct Args {
    #[arg(long)]
    ddg: PathBuf,

    #[arg(long)]
    layout: PathBuf,

    #[arg(long)]
    weights_json: Option<PathBuf>,

    #[arg(long)]
    state_hash: Option<PathBuf>,

    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    #[arg(short, long, default_value_t = 8)]
    seeds: usize,

    #[arg(long)]
    config: Option<PathBuf>,
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    let args = Args::parse();
    let loaded =
        load_config(args.config.as_deref()).unwrap_or_else(|e| panic!("[prism-ddg-state] {e}"));

    let ddg: Ddg = serde_json::from_reader(
        File::open(&args.ddg).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", args.ddg)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse DDG JSON: {e}"));

    let layouts: Vec<ProgramLayout> = serde_json::from_reader(
        File::open(&args.layout)
            .unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", args.layout)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {e}"));
    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    let state_fields: Vec<StateHashField> = args
        .state_hash
        .as_ref()
        .map(|p| {
            let raw: StateHashConfigRaw = serde_json::from_reader(
                File::open(p).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", p)),
            )
            .unwrap_or_else(|e| panic!("Cannot parse state hash JSON: {e}"));
            let fields = parse_state_hash_config(raw);
            let total_slots: usize = fields.iter().map(|f| f.bucket_count).sum();
            println!(
                "[prism-ddg-state] State hash    : {} fields, {} shmem slots",
                fields.len(),
                total_slots
            );
            for f in &fields {
                println!(
                    "[prism-ddg-state]   {:20} scheme={:15} buckets={:3} off={:3} hwm={}",
                    f.name,
                    format!("{:?}", f.bucket_scheme),
                    f.bucket_count,
                    f.absolute_byte_offset,
                    f.high_watermark
                );
            }
            fields
        })
        .unwrap_or_default();

    let dims = harness_dimensions();
    let frame_size = dims.input_size;
    let required_len = required_input_len(&loaded.config, frame_size);

    let dist = build_ddg_distances(&ddg);
    let name_scores = build_name_scores(&ddg, &dist);
    let i16_targets = infer_i16_targets_from_ddg(&ddg, &dist);
    let ddg_input_fields =
        build_runtime_input_fields(&layout, frame_size, &name_scores, &i16_targets);

    let (base_frame_weights, runtime_input_fields, weights_src) =
        if let Some(wp) = &args.weights_json {
            let wj: WeightsJson = serde_json::from_reader(
                File::open(wp).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", wp)),
            )
            .unwrap_or_else(|e| panic!("Cannot parse weights JSON: {e}"));
            let (bw, fields) = input_fields_from_weights_json(wj, frame_size);
            (bw, fields, "weights JSON")
        } else {
            let bw = ddg_byte_weights(&ddg_input_fields, frame_size);
            (bw, ddg_input_fields.clone(), "DDG analysis")
        };

    let weights = expand_weights_for_sequence(&base_frame_weights, required_len);

    println!("[prism-ddg-state] Program      : {}", layout.struct_name);
    println!("[prism-ddg-state] Layout bytes : {}", layout.total_bytes);
    println!("[prism-ddg-state] Input frame  : {} bytes", frame_size);
    println!("[prism-ddg-state] Input total  : {} bytes", required_len);
    println!("[prism-ddg-state] Mode         : {:?}", loaded.config.execution.mode);
    println!("[prism-ddg-state] Weights src  : {}", weights_src);
    println!("[prism-ddg-state] Config       : {}", loaded.source_label());
    println!("[prism-ddg-state] Crashes      : {}", args.crashes.display());
    println!("[prism-ddg-state] Input fields : {}", runtime_input_fields.len());
    for f in &runtime_input_fields {
        let role_tag = match f.role {
            FieldRole::Inhibitor => " [inhibitor]",
            FieldRole::Activator => " [activator]",
            FieldRole::Driver    => " [driver]",
            FieldRole::Other     => "",
        };
        println!(
            "[prism-ddg-state]   {:20} off={:>2} size={:>2} score={:.3}{}",
            f.name, f.offset, f.size, f.ddg_score, role_tag
        );
    }

    // -----------------------------------------------------------------------
    // LibAFL setup.
    // -----------------------------------------------------------------------

    let mut shmem_provider = UnixShMemProvider::new().unwrap();

    let mut cov_shmem = shmem_provider.new_shmem(COV_MAP_SIZE).unwrap();
    let cov_ptr = cov_shmem.as_slice_mut().as_mut_ptr();
    unsafe { COV_MAP_PTR = cov_ptr };
    let cov_observer = HitcountsMapObserver::new(unsafe {
        StdMapObserver::from_mut_ptr("edges", cov_ptr, COV_MAP_SIZE)
    });

    let mut state_shmem = shmem_provider.new_shmem(STATE_MAP_SIZE).unwrap();
    let state_ptr = state_shmem.as_slice_mut().as_mut_ptr();
    unsafe { STATE_MAP_PTR = state_ptr };
    let state_observer =
        unsafe { StdMapObserver::from_mut_ptr("state_hash", state_ptr, STATE_MAP_SIZE) };

    let mut feedback = feedback_or!(
        MaxMapFeedback::new(&cov_observer),
        MaxMapFeedback::new(&state_observer)
    );
    let mut objective = CrashFeedback::new();
    let mut state = StdState::new(
        StdRand::with_seed(0x1337),
        InMemoryCorpus::<BytesInput>::new(),
        OnDiskCorpus::new(args.crashes).unwrap(),
        &mut feedback,
        &mut objective,
    )
    .unwrap();

    let monitor = SimpleMonitor::new(|s| println!("{s}"));
    let mut mgr = SimpleEventManager::new(monitor);
    let scheduler = QueueScheduler::new();
    let mut fuzzer = StdFuzzer::new(scheduler, feedback, objective);

    // -----------------------------------------------------------------------
    // Harness.
    // -----------------------------------------------------------------------

    let config = loaded.config.clone();
    let sf = state_fields;

    let mut harness = move |input: &BytesInput| {
        let bytes = input.target_bytes();
        let data: &[u8] = bytes.as_ref();
        if data.len() < required_len {
            return ExitKind::Ok;
        }

        let mut hwm = vec![i32::MIN; sf.len()];

        let executed = execute_testcase_with_state_snapshots(
            &config,
            data,
            frame_size,
            &mut |snap: &[u8]| {
                for (i, field) in sf.iter().enumerate() {
                    let val =
                        read_i32_from_state(snap, field.absolute_byte_offset, field.byte_size);
                    if field.high_watermark {
                        hwm[i] = hwm[i].max(val);
                    } else {
                        hwm[i] = val;
                    }
                }
            },
        );

        if executed && !sf.is_empty() {
            for (i, field) in sf.iter().enumerate() {
                if hwm[i] == i32::MIN {
                    continue;
                }
                let bucket = compute_bucket(field, hwm[i]);
                let slot = field.shmem_base + bucket;
                if slot < STATE_MAP_SIZE {
                    unsafe { *STATE_MAP_PTR.add(slot) = 1 };
                }
            }
        }

        ExitKind::Ok
    };

    let mut executor = InProcessForkExecutor::new(
        &mut harness,
        tuple_list!(cov_observer, state_observer),
        &mut fuzzer,
        &mut state,
        &mut mgr,
        std::time::Duration::from_millis(loaded.config.execution.timeout_ms),
        shmem_provider,
    )
    .unwrap();

    // -----------------------------------------------------------------------
    // Seed corpus and fuzz loop.
    // -----------------------------------------------------------------------

    let mut generator =
        RandBytesGenerator::new(std::num::NonZeroUsize::new(required_len.max(1)).unwrap());
    state
        .generate_initial_inputs_forced(
            &mut fuzzer,
            &mut executor,
            &mut generator,
            &mut mgr,
            args.seeds,
        )
        .unwrap();

    let field_mutator = FieldValueMutator::new(frame_size, runtime_input_fields.clone());
    let frame_mutator = FramePatternMutator::new(frame_size, &runtime_input_fields);
    let range_mutator =
        InputRangeMutator::new(frame_size, &runtime_input_fields, &base_frame_weights);
    let window_mutator = AccumulationWindowMutator::new(frame_size, &runtime_input_fields);
    let ddg_mutator = DdgByteMutator::new(weights);

    let mutator = HavocScheduledMutator::new(
        tuple_list!(field_mutator, frame_mutator, range_mutator, window_mutator, ddg_mutator)
            .merge(havoc_mutations()),
    );
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    let _ = STATE_HEARTBEAT_INTERVAL_SECS; // used in prism-cov/not-dumb, kept for consistency

    println!("[prism-ddg-state] Fuzzing — Ctrl+C to stop");
    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
