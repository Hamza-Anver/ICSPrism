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
use serde::Deserialize;

unsafe extern "C" {
    fn prism_alloc() -> *mut u8;
    fn prism_reset(instance: *mut u8);
    fn prism_free(instance: *mut u8);
    fn prism_run(instance: *mut u8, data: *const u8, len: usize);
    fn prism_step(instance: *mut u8);
    fn prism_get_state(instance: *const u8, out: *mut u8);
    fn prism_set_state(instance: *mut u8, state: *const u8, len: usize);
    fn prism_state_size() -> usize;
    fn prism_input_size() -> usize;
    fn prism_struct_size() -> usize;
    fn prism_field_count() -> u32;
    fn prism_field_name(idx: u32) -> *const i8;
    fn prism_field_offset(idx: u32) -> usize;
    fn prism_field_size(idx: u32) -> usize;
    fn prism_field_is_input(idx: u32) -> i32;
    fn prism_get_field(instance: *const u8, idx: u32, out: *mut u8) -> usize;
    fn prism_set_field(instance: *mut u8, idx: u32, data: *const u8, len: usize) -> i32;
}

// ---------------------------------------------------------------------------
// SanitizerCoverage hooks — write into shmem so InProcessForkExecutor can
// read coverage from the child after each fork.
// ---------------------------------------------------------------------------
const MAP_SIZE: usize = 65536;
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

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
#[derive(Parser, Debug)]
#[command(name = "prism-cov", about = "Coverage-guided ST fuzzer (baseline)")]
struct Args {
    /// Directory to save crash inputs
    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    /// Number of initial seeds
    #[arg(short, long, default_value_t = 8)]
    seeds: usize,
}

// ---------------------------------------------------------------------------
// Layout types — mirrors prism-analyze JSON output
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
struct FieldLayout {
    #[allow(dead_code)]
    index: u32,
    name: Option<String>,
    llvm_type: String,
    byte_size: u64,
    byte_offset: u64,
}

#[derive(Debug, Deserialize)]
struct ProgramLayout {
    struct_name: String,
    #[allow(dead_code)]
    function_name: String,
    total_bytes: u64,
    fields: Vec<FieldLayout>,
}

// ---------------------------------------------------------------------------
// Input mapping
// ---------------------------------------------------------------------------
fn is_fuzzable(field: &FieldLayout) -> bool {
    let name = field.name.as_deref().unwrap_or("");
    name != "__vtable" && !field.llvm_type.starts_with('%')
}

fn input_size(layout: &ProgramLayout) -> usize {
    layout
        .fields
        .iter()
        .filter(|f| is_fuzzable(f))
        .map(|f| f.byte_size as usize)
        .sum()
}

fn map_input(bytes: &[u8], instance: &mut [u8], layout: &ProgramLayout) {
    instance.fill(0);
    let mut src = 0usize;
    for field in layout.fields.iter().filter(|f| is_fuzzable(f)) {
        let size = field.byte_size as usize;
        let offset = field.byte_offset as usize;
        if src + size > bytes.len() || offset + size > instance.len() {
            break;
        }
        instance[offset..offset + size].copy_from_slice(&bytes[src..src + size]);
        src += size;
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
fn main() {
    let args = Args::parse();

    // All struct knowledge comes from the harness at runtime
    let in_size      = unsafe { prism_input_size() };
    let struct_bytes = unsafe { prism_struct_size() };

    println!("[prism-cov] Input    : {} bytes", in_size);
    println!("[prism-cov] Struct   : {} bytes", struct_bytes);
    println!("[prism-cov] Crashes  : {}", args.crashes.display());

    let mut shmem_provider = UnixShMemProvider::new().unwrap();
    let mut edges_shmem = shmem_provider.new_shmem(MAP_SIZE).unwrap();
    let edges_ptr = edges_shmem.as_slice_mut().as_mut_ptr();
    unsafe { COV_MAP_PTR = edges_ptr; }

    let observer = HitcountsMapObserver::new(unsafe {
        StdMapObserver::from_mut_ptr("edges", edges_ptr, MAP_SIZE)
    });

    let mut feedback  = MaxMapFeedback::new(&observer);
    let mut objective = CrashFeedback::new();

    let mut state = StdState::new(
        StdRand::with_seed(0x1337),
        InMemoryCorpus::<BytesInput>::new(),
        OnDiskCorpus::new(args.crashes).unwrap(),
        &mut feedback,
        &mut objective,
    ).unwrap();

    let monitor    = SimpleMonitor::new(|s| println!("{s}"));
    let mut mgr    = SimpleEventManager::new(monitor);
    let scheduler  = QueueScheduler::new();
    let mut fuzzer = StdFuzzer::new(scheduler, feedback, objective);

    let mut harness = |input: &BytesInput| {
        let bytes = input.target_bytes();
        if bytes.len() < in_size {
            return ExitKind::Ok;
        }
        unsafe {
            let instance = prism_alloc();
            prism_run(instance, bytes.as_ptr(), bytes.len());
            prism_free(instance);
        }
        ExitKind::Ok
    };

    let mut executor = InProcessForkExecutor::new(
        &mut harness,
        tuple_list!(observer),
        &mut fuzzer,
        &mut state,
        &mut mgr,
        std::time::Duration::from_secs(5),
        shmem_provider,
    ).unwrap();

    let mut generator = RandBytesGenerator::new(
        std::num::NonZeroUsize::new(in_size.max(1)).unwrap()
    );

    state.generate_initial_inputs_forced(
        &mut fuzzer,
        &mut executor,
        &mut generator,
        &mut mgr,
        args.seeds,
    ).unwrap();

    let mutator    = HavocScheduledMutator::new(havoc_mutations());
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    println!("[prism-cov] Fuzzing — Ctrl+C to stop");

    fuzzer.fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr).unwrap();
}
