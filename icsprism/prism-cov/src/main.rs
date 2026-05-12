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
    mutators::{havoc_mutations, HavocScheduledMutator},
    observers::{HitcountsMapObserver, StdMapObserver},
    schedulers::QueueScheduler,
    stages::StdMutationalStage,
    state::StdState,
};
use libafl_bolts::{
    rands::StdRand,
    shmem::{ShMemProvider, UnixShMemProvider},
    tuples::tuple_list,
    AsSliceMut,
};
use prism_runtime::{
    execute_testcase_with_heartbeat, harness_dimensions, load_config, print_startup_diagnostics,
    required_input_len,
};

const MAP_SIZE: usize = 65536;
const STATE_HEARTBEAT_INTERVAL_SECS: u64 = 5;
static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();

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

#[derive(Parser, Debug)]
#[command(name = "prism-cov", about = "Coverage-guided ST fuzzer (baseline)")]
struct Args {
    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    #[arg(short, long, default_value_t = 8)]
    seeds: usize,

    #[arg(long)]
    config: Option<PathBuf>,
}

fn main() {
    let args = Args::parse();
    let loaded = load_config(args.config.as_deref()).unwrap_or_else(|e| panic!("[prism-cov] {e}"));

    let dims = harness_dimensions();
    let in_size = dims.input_size;
    let required_len = required_input_len(&loaded.config, in_size);

    print_startup_diagnostics("prism-cov", &loaded, dims, required_len, &args.crashes, &[]);

    let mut shmem_provider = UnixShMemProvider::new().unwrap();
    let mut edges_shmem = shmem_provider.new_shmem(MAP_SIZE).unwrap();
    let edges_ptr = edges_shmem.as_slice_mut().as_mut_ptr();
    unsafe {
        COV_MAP_PTR = edges_ptr;
    }

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
            in_size,
            "prism-cov",
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

    let mutator = HavocScheduledMutator::new(havoc_mutations());
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    println!("[prism-cov] Fuzzing — Ctrl+C to stop");
    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
