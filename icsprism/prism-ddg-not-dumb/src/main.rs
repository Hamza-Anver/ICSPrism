use std::fs::File;
use std::path::PathBuf;

use clap::Parser;
use libafl::{
    corpus::{InMemoryCorpus, OnDiskCorpus},
    events::SimpleEventManager,
    executors::{ExitKind, InProcessForkExecutor},
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
    execute_testcase_with_heartbeat, harness_dimensions, load_config, required_input_len,
};
use prism_runtime::fuzzing::{
    DdgByteMutator, Ddg, FieldValueMutator, FramePatternMutator, InputRangeMutator,
    ProgramLayout, WeightsJson, build_ddg_distances, build_name_scores,
    build_runtime_input_fields, ddg_byte_weights, expand_weights_for_sequence,
    infer_i16_targets_from_ddg, input_fields_from_weights_json,
    COV_MAP_SIZE,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STATE_HEARTBEAT_INTERVAL_SECS: u64 = 5;
const MAP_SIZE: usize = COV_MAP_SIZE;

static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();

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
            *start = idx % MAP_SIZE as u32;
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
        if idx < MAP_SIZE {
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
    name = "prism-ddg-not-dumb",
    about = "Smarter DDG-guided ST fuzzer with frame-aware mutations"
)]
struct Args {
    #[arg(long)]
    ddg: PathBuf,

    #[arg(long)]
    layout: PathBuf,

    #[arg(long)]
    weights_json: Option<PathBuf>,

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
        load_config(args.config.as_deref()).unwrap_or_else(|e| panic!("[prism-ddg-not-dumb] {e}"));

    let ddg: Ddg = serde_json::from_reader(
        File::open(&args.ddg)
            .unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.ddg, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse DDG JSON: {}", e));

    let layouts: Vec<ProgramLayout> = serde_json::from_reader(
        File::open(&args.layout)
            .unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.layout, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {}", e));
    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    let dims = harness_dimensions();
    let frame_size = dims.input_size;
    let required_len = required_input_len(&loaded.config, frame_size);

    let dist = build_ddg_distances(&ddg);
    let name_scores = build_name_scores(&ddg, &dist);
    let i16_targets = infer_i16_targets_from_ddg(&ddg, &dist);
    let ddg_input_fields =
        build_runtime_input_fields(&layout, frame_size, &name_scores, &i16_targets);

    let (base_frame_weights, runtime_input_fields, use_json) =
        if let Some(wp) = &args.weights_json {
            let wj: WeightsJson = serde_json::from_reader(
                File::open(wp)
                    .unwrap_or_else(|e| panic!("Cannot open {:?}: {}", wp, e)),
            )
            .unwrap_or_else(|e| panic!("Cannot parse weights JSON: {}", e));
            let (bw, fields) = input_fields_from_weights_json(wj, frame_size);
            (bw, fields, true)
        } else {
            let bw = ddg_byte_weights(&ddg_input_fields, frame_size);
            (bw, ddg_input_fields.clone(), false)
        };

    let weights = expand_weights_for_sequence(&base_frame_weights, required_len);

    println!("[prism-ddg-not-dumb] Program       : {}", layout.struct_name);
    println!("[prism-ddg-not-dumb] Layout bytes  : {}", layout.total_bytes);
    println!("[prism-ddg-not-dumb] Input frame   : {} bytes", frame_size);
    println!("[prism-ddg-not-dumb] Input total   : {} bytes", required_len);
    println!("[prism-ddg-not-dumb] State         : {} bytes", dims.state_size);
    println!("[prism-ddg-not-dumb] Struct        : {} bytes", dims.struct_size);
    println!("[prism-ddg-not-dumb] Mode          : {:?}", loaded.config.execution.mode);
    println!(
        "[prism-ddg-not-dumb] DDG constants : {} inferred i16 targets",
        i16_targets.len()
    );
    println!("[prism-ddg-not-dumb] Input fields  : {}", runtime_input_fields.len());
    for field in &runtime_input_fields {
        println!(
            "[prism-ddg-not-dumb]   {:20} off={:>2} size={:>2} score={:.4}",
            field.name, field.offset, field.size, field.ddg_score
        );
    }
    println!(
        "[prism-ddg-not-dumb] Weights src   : {}",
        if use_json { "JSON (probe_ddg_adv.py)" } else { "DDG analysis" }
    );
    println!("[prism-ddg-not-dumb] Config        : {}", loaded.source_label());
    println!("[prism-ddg-not-dumb] Crashes       : {}", args.crashes.display());

    // -----------------------------------------------------------------------
    // LibAFL setup.
    // -----------------------------------------------------------------------

    let mut shmem_provider = UnixShMemProvider::new().unwrap();
    let mut edges_shmem = shmem_provider.new_shmem(MAP_SIZE).unwrap();
    let edges_ptr = edges_shmem.as_slice_mut().as_mut_ptr();
    unsafe { COV_MAP_PTR = edges_ptr };
    let observer = HitcountsMapObserver::new(unsafe {
        StdMapObserver::from_mut_ptr("edges", edges_ptr, MAP_SIZE)
    });
    let mut feedback = MaxMapFeedback::new(&observer);
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
    let mut harness = move |input: &BytesInput| {
        let bytes = input.target_bytes();
        let data: &[u8] = bytes.as_ref();
        if data.len() < required_len {
            return ExitKind::Ok;
        }
        let _ = execute_testcase_with_heartbeat(
            &config,
            data,
            frame_size,
            "prism-ddg-not-dumb",
            STATE_HEARTBEAT_INTERVAL_SECS,
        );
        ExitKind::Ok
    };

    let mut executor = InProcessForkExecutor::new(
        &mut harness,
        tuple_list!(observer),
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
    let ddg_mutator = DdgByteMutator::new(weights);

    let mutator = HavocScheduledMutator::new(
        tuple_list!(field_mutator, frame_mutator, range_mutator, ddg_mutator)
            .merge(havoc_mutations()),
    );
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    println!("[prism-ddg-not-dumb] Fuzzing — Ctrl+C to stop");
    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
