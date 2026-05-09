use libafl::prelude::{
    havoc_mutations, BytesInput, CrashFeedback, ExitKind, Fuzzer, HasTargetBytes,
    HavocScheduledMutator, InMemoryCorpus, InProcessExecutor, MaxMapFeedback, OnDiskCorpus,
    QueueScheduler, RandBytesGenerator, SimpleEventManager, SimpleMonitor, StdFuzzer,
    StdMapObserver, StdMutationalStage, StdState,
};

use libafl_bolts::prelude::{nonzero, tuple_list, AsSlice, StdRand};
use std::path::PathBuf;
use std::ptr::addr_of_mut;

// ---------------------------------------------------------------------------
// Offsets from harness_test_layout.json — HarnessTest struct (72 bytes)
// ---------------------------------------------------------------------------
const STRUCT_BYTES: usize = 72;
const OFFSET_A: usize = 0;
const OFFSET_B: usize = 2;
const OFFSET_FLAG: usize = 4;
const OFFSET_INDEX: usize = 6;

// ---------------------------------------------------------------------------
// SanitizerCoverage edge map — LibAFL reads this after each execution
// ---------------------------------------------------------------------------
const MAP_SIZE: usize = 65536;
static mut EDGES_MAP: [u8; MAP_SIZE] = [0u8; MAP_SIZE];

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
        let idx = *guard as usize;
        EDGES_MAP[idx] = EDGES_MAP[idx].wrapping_add(1);
    }
}

// ---------------------------------------------------------------------------
// Link against the compiled ST program
// ---------------------------------------------------------------------------
unsafe extern "C" {
    fn HarnessTest(instance: *mut u8);
}

// ---------------------------------------------------------------------------
// Field write helpers
// ---------------------------------------------------------------------------
fn write_i16(mem: &mut [u8], offset: usize, value: i16) {
    mem[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
}

fn write_i8(mem: &mut [u8], offset: usize, value: i8) {
    mem[offset] = value as u8;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
fn main() {
    // Coverage observer — wraps the static edge map filled by the sanitizer hooks
    let observer = unsafe {
        StdMapObserver::from_mut_ptr("edges", addr_of_mut!(EDGES_MAP) as *mut u8, MAP_SIZE)
    };

    // Maximize edge coverage, save crashes as objectives
    let mut feedback = MaxMapFeedback::new(&observer);
    let mut objective = CrashFeedback::new();

    let mut state = StdState::new(
        StdRand::with_seed(0x1337),
        InMemoryCorpus::<BytesInput>::new(),
        OnDiskCorpus::new(PathBuf::from("./crashes")).unwrap(),
        &mut feedback,
        &mut objective,
    )
    .unwrap();

    let monitor = SimpleMonitor::new(|s| println!("{s}"));
    let mut mgr = SimpleEventManager::new(monitor);

    let scheduler = QueueScheduler::new();
    let mut fuzzer = StdFuzzer::new(scheduler, feedback, objective);

    // Harness closure — maps raw fuzzer bytes onto the ST struct and calls the program
    let mut harness = |input: &BytesInput| {
        let raw = input.target_bytes();
        let bytes = raw.as_slice();

        // Need at least 7 bytes: A(2) + B(2) + Flag(1) + Index(2)
        if bytes.len() < 7 {
            return ExitKind::Ok;
        }

        let mut instance = [0u8; STRUCT_BYTES];

        write_i16(
            &mut instance,
            OFFSET_A,
            i16::from_le_bytes([bytes[0], bytes[1]]),
        );
        write_i16(
            &mut instance,
            OFFSET_B,
            i16::from_le_bytes([bytes[2], bytes[3]]),
        );
        write_i8(&mut instance, OFFSET_FLAG, bytes[4] as i8);
        write_i16(
            &mut instance,
            OFFSET_INDEX,
            i16::from_le_bytes([bytes[5], bytes[6]]),
        );

        unsafe {
            HarnessTest(instance.as_mut_ptr());
        }

        ExitKind::Ok
    };

    let mut executor = InProcessExecutor::new(
        &mut harness,
        tuple_list!(observer),
        &mut fuzzer,
        &mut state,
        &mut mgr,
    )
    .unwrap();

    // Generate initial seeds — 8 random inputs of 7 bytes each
    let mut generator = RandBytesGenerator::new(nonzero!(7_usize));
    state
        .generate_initial_inputs(&mut fuzzer, &mut executor, &mut generator, &mut mgr, 8)
        .unwrap();

    // Mutator and stage
    let mutator = HavocScheduledMutator::new(havoc_mutations());
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
