use std::{
    collections::HashMap,
    fs::File,
    path::{Path, PathBuf},
};

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
    execute_testcase_from_checkpoint, execute_testcase_with_state_snapshots,
    harness_dimensions, load_config, required_input_len,
};
use prism_runtime::fuzzing::{
    AccumulationWindowMutator, DdgByteMutator, Ddg, FieldRole, FieldValueMutator,
    FramePatternMutator, InputField, InputRangeMutator, ProgramLayout, StateHashConfigRaw,
    StateHashField, SubAccumulatorField, WeightsJson, build_ddg_distances,
    build_name_scores, build_runtime_input_fields, compute_bucket, ddg_byte_weights,
    expand_weights_for_sequence, infer_i16_targets_from_ddg, input_fields_from_weights_json,
    parse_state_hash_config, read_i32_from_state, snapshot_quality,
    COV_MAP_SIZE, STATE_MAP_SIZE,
};
use serde::Deserialize;

// ---------------------------------------------------------------------------
// Checkpoint shmem header layout (step 3):
//   byte 0:   flag     (0 = no new checkpoint, 1 = valid checkpoint written)
//   bytes 1-2: discriminant bucket as u16 LE  (removes the old u8 / 255 cap)
//   bytes 3-4: generation counter as u16 LE   (detects stale reads)
//   bytes 5+:  PLC struct snapshot
// ---------------------------------------------------------------------------
const CHECKPOINT_HDR: usize = 5;

static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();
static mut STATE_MAP_PTR: *mut u8 = std::ptr::null_mut();
static mut CHECKPOINT_MAP_PTR: *mut u8 = std::ptr::null_mut();

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
    name = "prism-go-explore",
    about = "Go-Explore ST fuzzer: checkpoint at discriminant high-watermarks, burst with zone-aware frames"
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

    /// Zone constraints JSON (discriminant byte offset, zone ranges, pvsum decomposition).
    #[arg(long)]
    zone_constraints: Option<PathBuf>,

    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    #[arg(short, long, default_value_t = 8)]
    seeds: usize,

    #[arg(long)]
    config: Option<PathBuf>,

    /// Number of zone-aware frames generated per checkpoint burst.
    #[arg(long, default_value_t = 128)]
    rollout_frames: usize,

    /// Normal fuzz_one iterations between checkpoint bursts.
    #[arg(long, default_value_t = 500)]
    burst_size: usize,

    /// How many burst attempts to run per cycle.
    #[arg(long, default_value_t = 50)]
    burst_repeats: usize,

    /// How to select which checkpoint(s) to burst from each cycle.
    /// `best`: all burst_repeats from the highest bucket (default).
    /// `round-robin`: distribute burst_repeats evenly across all filled checkpoints.
    #[arg(long, value_enum, default_value_t = CheckpointStrategy::Best)]
    checkpoint_strategy: CheckpointStrategy,
}

#[derive(clap::ValueEnum, Clone, Copy, Debug, PartialEq, Eq)]
enum CheckpointStrategy {
    Best,
    RoundRobin,
}

// ---------------------------------------------------------------------------
// Zone constraint types
// ---------------------------------------------------------------------------

/// Per-field [lo, hi] range used in burst frame generation.
#[derive(Debug, Clone, Deserialize)]
struct FieldRange {
    lo: i16,
    hi: i16,
}

#[derive(Debug, Clone, Deserialize)]
struct ZoneConstraint {
    #[allow(dead_code)]
    id: usize,
    /// Lower bound (inclusive) of the discriminant range for this zone.
    #[serde(alias = "fillhead_lo")]
    lo: i32,
    /// Upper bound (exclusive) of the discriminant range for this zone.
    #[serde(alias = "fillhead_hi")]
    hi: i32,
    /// Generic per-field constraints: maps field name → [lo, hi] sampling range.
    #[serde(default)]
    field_constraints: std::collections::HashMap<String, FieldRange>,
}

#[derive(Debug, Clone, Deserialize)]
struct ZoneConstraintsConfig {
    #[allow(dead_code)]
    discriminant_field: String,
    /// Absolute byte offset of the discriminant field within the struct snapshot.
    #[serde(alias = "fillhead_byte_offset")]
    discriminant_byte_offset: usize,
    #[serde(alias = "fillhead_byte_size")]
    discriminant_byte_size: usize,
    /// Inclusive upper bound for the discriminant — sets checkpoint table size.
    #[serde(alias = "max_fillhead", default = "default_max_discriminant")]
    max_discriminant: u32,
    /// State variables that directly gate discriminant accumulation.
    #[serde(default)]
    sub_accumulator_fields: Vec<SubAccumulatorField>,
    zones: Vec<ZoneConstraint>,
}

fn default_max_discriminant() -> u32 {
    255
}

// ---------------------------------------------------------------------------
// Zone helpers
// ---------------------------------------------------------------------------

/// How many buckets from the zone boundary to start generating ramp (transition) frames.
const RAMP_WINDOW: i32 = 2;

/// Return the index into `zones` whose [lo, hi) contains `bucket`.
fn find_zone_idx(zones: &[ZoneConstraint], bucket: usize) -> Option<usize> {
    zones
        .iter()
        .position(|z| bucket as i32 >= z.lo && (bucket as i32) < z.hi)
}

// ---------------------------------------------------------------------------
// Zone-aware frame generation
// ---------------------------------------------------------------------------

fn rand_i16_in(rng: &mut impl libafl_bolts::rands::Rand, lo: i16, hi: i16) -> i16 {
    if lo >= hi {
        return lo;
    }
    let range = hi.saturating_sub(lo) as u64;
    lo.saturating_add((rng.next() % (range + 1)) as i16)
}

fn write_i16_le(buf: &mut [u8], offset: usize, value: i16) {
    if offset + 2 <= buf.len() {
        let [lo, hi] = value.to_le_bytes();
        buf[offset] = lo;
        buf[offset + 1] = hi;
    }
}

/// Generate `n_frames` packed input frames for a checkpoint burst.
fn generate_zone_frames(
    field_constraints: &HashMap<String, FieldRange>,
    input_fields: &[InputField],
    frame_size: usize,
    n_frames: usize,
    rng: &mut impl libafl_bolts::rands::Rand,
) -> Vec<u8> {
    let mut out = vec![0u8; frame_size * n_frames];
    for fi in 0..n_frames {
        let frame = &mut out[fi * frame_size..(fi + 1) * frame_size];
        for field in input_fields {
            if field.offset >= frame_size || field.size == 0 {
                continue;
            }
            let end = (field.offset + field.size).min(frame_size);
            if field.role == FieldRole::Inhibitor {
                for b in &mut frame[field.offset..end] {
                    *b = 0;
                }
            } else if let Some(range) = field_constraints.get(&field.name) {
                if field.size == 2 {
                    write_i16_le(frame, field.offset, rand_i16_in(rng, range.lo, range.hi));
                } else if field.size == 1 {
                    let v = rand_i16_in(rng, range.lo.max(0), range.hi.max(0)) as u8;
                    frame[field.offset] = v;
                }
            } else {
                match &field.model {
                    prism_runtime::fuzzing::FieldValueModel::I16 { targets }
                        if !targets.is_empty() =>
                    {
                        let use_target = (rng.next() % 100) < 80;
                        let value: i16 = if use_target {
                            targets[(rng.next() as usize) % targets.len()]
                        } else {
                            rng.next() as i16
                        };
                        if field.size == 2 {
                            write_i16_le(frame, field.offset, value);
                        }
                    }
                    prism_runtime::fuzzing::FieldValueModel::Bool => {
                        frame[field.offset] = (rng.next() & 1) as u8;
                    }
                    _ => {}
                }
            }
        }
    }
    out
}

// ---------------------------------------------------------------------------
// Checkpoint shmem helpers (step 3)
// ---------------------------------------------------------------------------

unsafe fn chk_read_bucket(ptr: *const u8) -> usize {
    let lo = unsafe { *ptr.add(1) } as usize;
    let hi = unsafe { *ptr.add(2) } as usize;
    lo | (hi << 8)
}

unsafe fn chk_read_gen(ptr: *const u8) -> u16 {
    let lo = unsafe { *ptr.add(3) } as u16;
    let hi = unsafe { *ptr.add(4) } as u16;
    lo | (hi << 8)
}

unsafe fn chk_write_header(ptr: *mut u8, flag: u8, bucket: usize, chk_gen: u16) {
    unsafe {
        *ptr = flag;
        *ptr.add(1) = (bucket & 0xFF) as u8;
        *ptr.add(2) = ((bucket >> 8) & 0xFF) as u8;
        *ptr.add(3) = (chk_gen & 0xFF) as u8;
        *ptr.add(4) = ((chk_gen >> 8) & 0xFF) as u8;
    }
}

// ---------------------------------------------------------------------------
// Checkpoint burst
// ---------------------------------------------------------------------------

fn checkpoint_burst(
    bucket: usize,
    snapshot: &[u8],
    zone_config: Option<&ZoneConstraintsConfig>,
    state_fields: &[StateHashField],
    input_fields: &[InputField],
    frame_size: usize,
    rollout_frames: usize,
    crashes_dir: &Path,
    struct_size: usize,
    discriminant_info: Option<(usize, usize)>,
    checkpoint_table: &mut Vec<Option<(Vec<u8>, u32)>>,
    chk_gen: u16,
) {
    if frame_size == 0 || rollout_frames == 0 || snapshot.len() < struct_size {
        return;
    }

    static BURST_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let burst_id = BURST_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0x1337)
        ^ (bucket as u64).wrapping_mul(0x9e3779b9)
        ^ burst_id.wrapping_mul(0x517c_c1b7_2722_0a95);
    let mut rng = StdRand::with_seed(seed);

    let empty: HashMap<String, FieldRange> = HashMap::new();
    let frames = if let Some(zc) = zone_config {
        if let Some(cur_idx) = find_zone_idx(&zc.zones, bucket) {
            let cur_zone = &zc.zones[cur_idx];
            let gap = cur_zone.hi - 1 - bucket as i32;
            let next_zone = if gap <= RAMP_WINDOW { zc.zones.get(cur_idx + 1) } else { None };
            if let Some(nz) = next_zone {
                let phase1 = rollout_frames * 7 / 10;
                let phase2 = rollout_frames - phase1;
                let mut f = generate_zone_frames(
                    &cur_zone.field_constraints, input_fields, frame_size, phase1, &mut rng,
                );
                f.extend(generate_zone_frames(
                    &nz.field_constraints, input_fields, frame_size, phase2, &mut rng,
                ));
                f
            } else {
                generate_zone_frames(
                    &cur_zone.field_constraints, input_fields, frame_size, rollout_frames, &mut rng,
                )
            }
        } else {
            let last = zc.zones.last().map(|z| &z.field_constraints).unwrap_or(&empty);
            generate_zone_frames(last, input_fields, frame_size, rollout_frames, &mut rng)
        }
    } else {
        generate_zone_frames(&empty, input_fields, frame_size, rollout_frames, &mut rng)
    };

    // Zero the flag before forking so the child starts clean.
    unsafe {
        if !CHECKPOINT_MAP_PTR.is_null() {
            *CHECKPOINT_MAP_PTR = 0;
        }
    }

    let child = unsafe { libc::fork() };
    if child < 0 {
        eprintln!("[goexplore] fork() failed for burst at bucket={bucket}");
        return;
    }

    if child == 0 {
        // In child: disable parent shmem regions and run the burst.
        unsafe {
            COV_MAP_PTR = std::ptr::null_mut();
            STATE_MAP_PTR = std::ptr::null_mut();
        }

        let mut burst_discriminant_max = -1i32;
        let mut burst_best_snap = vec![0u8; struct_size];

        execute_testcase_from_checkpoint(snapshot, &frames, frame_size, &mut |snap| {
            if let Some((off, sz)) = discriminant_info {
                let v = read_i32_from_state(snap, off, sz);
                if v > burst_discriminant_max {
                    burst_discriminant_max = v;
                    let n = snap.len().min(burst_best_snap.len());
                    burst_best_snap[..n].copy_from_slice(&snap[..n]);
                }
            }
        });

        if burst_discriminant_max > 0 {
            unsafe {
                if !CHECKPOINT_MAP_PTR.is_null() {
                    // Zero the full header first, then write atomically.
                    std::ptr::write_bytes(CHECKPOINT_MAP_PTR, 0, CHECKPOINT_HDR);
                    chk_write_header(
                        CHECKPOINT_MAP_PTR,
                        1,
                        burst_discriminant_max as usize,
                        chk_gen,
                    );
                    std::ptr::copy_nonoverlapping(
                        burst_best_snap.as_ptr(),
                        CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                        burst_best_snap.len().min(struct_size),
                    );
                }
            }
        }

        unsafe { libc::_exit(0) };
    }

    let mut status: libc::c_int = 0;
    unsafe { libc::waitpid(child, &mut status, 0) };

    // Read only after waitpid — child has fully exited, no race.
    let flag = unsafe { if !CHECKPOINT_MAP_PTR.is_null() { *CHECKPOINT_MAP_PTR } else { 0 } };
    if flag == 1 {
        let burst_bucket = unsafe { chk_read_bucket(CHECKPOINT_MAP_PTR) };
        let returned_gen = unsafe { chk_read_gen(CHECKPOINT_MAP_PTR) };
        if returned_gen == chk_gen && burst_bucket < checkpoint_table.len() && burst_bucket > bucket {
            let mut snap = vec![0u8; struct_size];
            unsafe {
                std::ptr::copy_nonoverlapping(
                    CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                    snap.as_mut_ptr(),
                    struct_size,
                );
            }
            let disc_offset = discriminant_info.map(|(o, _)| o).unwrap_or(usize::MAX);
            let sub_accum =
                zone_config.map(|zc| zc.sub_accumulator_fields.as_slice()).unwrap_or(&[]);
            let quality = snapshot_quality(&snap, sub_accum, state_fields, disc_offset);
            let update = match &checkpoint_table[burst_bucket] {
                None => true,
                Some((_, prev_q)) => quality > *prev_q,
            };
            if update {
                let is_new = checkpoint_table[burst_bucket].is_none();
                checkpoint_table[burst_bucket] = Some((snap, quality));
                if is_new {
                    eprintln!(
                        "[goexplore] burst advance: bucket {bucket} → {burst_bucket} (quality={quality})"
                    );
                } else {
                    eprintln!(
                        "[goexplore] burst quality upgrade: bucket {burst_bucket} quality={quality}"
                    );
                }
            }
        }
    }

    if libc::WIFSIGNALED(status) {
        let sig = libc::WTERMSIG(status);
        eprintln!("[goexplore] CRASH from burst at discriminant bucket={bucket} signal={sig}");
        let crash_path = crashes_dir.join(format!("checkpoint_crash_bucket{bucket}"));
        let mut crash_data = snapshot.to_vec();
        crash_data.extend_from_slice(&frames);
        if let Err(e) = std::fs::write(&crash_path, &crash_data) {
            eprintln!("[goexplore] failed to write crash: {e}");
        } else {
            eprintln!("[goexplore] crash saved: {}", crash_path.display());
        }
        std::process::exit(1);
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    let args = Args::parse();
    let loaded =
        load_config(args.config.as_deref()).unwrap_or_else(|e| panic!("[prism-go-explore] {e}"));

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

    // State hash config (optional).
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
                "[prism-go-explore] State hash    : {} fields, {} shmem slots",
                fields.len(),
                total_slots
            );
            for f in &fields {
                println!(
                    "[prism-go-explore]   {:20} scheme={:15} buckets={:3} off={:3} hwm={}",
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

    // Zone constraints config (optional).
    let zone_config: Option<ZoneConstraintsConfig> = args.zone_constraints.as_ref().map(|p| {
        let raw = std::fs::read_to_string(p)
            .unwrap_or_else(|e| panic!("Cannot read zone constraints {:?}: {e}", p));
        serde_json::from_str(&raw)
            .unwrap_or_else(|e| panic!("Cannot parse zone constraints JSON: {e}"))
    });

    // Discriminant field tracking: (absolute_byte_offset, byte_size) within the struct snapshot.
    let discriminant_info: Option<(usize, usize)> = zone_config
        .as_ref()
        .map(|zc| (zc.discriminant_byte_offset, zc.discriminant_byte_size));

    let dims = harness_dimensions();
    let frame_size = dims.input_size;
    let struct_size = dims.struct_size;
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

    println!("[prism-go-explore] Program      : {}", layout.struct_name);
    println!("[prism-go-explore] Layout bytes : {}", layout.total_bytes);
    println!("[prism-go-explore] Struct size  : {} bytes", struct_size);
    println!("[prism-go-explore] Input frame  : {} bytes", frame_size);
    println!("[prism-go-explore] Input total  : {} bytes", required_len);
    println!("[prism-go-explore] Mode         : {:?}", loaded.config.execution.mode);
    println!("[prism-go-explore] Weights src  : {}", weights_src);
    println!("[prism-go-explore] Config       : {}", loaded.source_label());
    println!("[prism-go-explore] Crashes      : {}", args.crashes.display());
    println!("[prism-go-explore] Burst size   : {}", args.burst_size);
    println!("[prism-go-explore] Burst repeats: {}", args.burst_repeats);
    println!("[prism-go-explore] Rollout frames: {}", args.rollout_frames);
    if let Some(ref zc) = zone_config {
        println!(
            "[prism-go-explore] Zone config  : {} zones, discriminant@off={}",
            zc.zones.len(),
            zc.discriminant_byte_offset
        );
    } else {
        println!("[prism-go-explore] Zone config  : none (checkpoint bursts disabled)");
    }
    println!("[prism-go-explore] Input fields : {}", runtime_input_fields.len());
    for f in &runtime_input_fields {
        let role_tag = match f.role {
            FieldRole::Inhibitor => " [inhibitor]",
            FieldRole::Activator => " [activator]",
            FieldRole::Driver    => " [driver]",
            FieldRole::Other     => "",
        };
        println!(
            "[prism-go-explore]   {:20} off={:>2} size={:>2} score={:.3}{}",
            f.name, f.offset, f.size, f.ddg_score, role_tag
        );
    }

    // -----------------------------------------------------------------------
    // LibAFL setup
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

    // Checkpoint shmem: CHECKPOINT_HDR bytes of header + struct_size bytes of snapshot.
    let mut chk_shmem = shmem_provider.new_shmem(CHECKPOINT_HDR + struct_size).unwrap();
    let chk_ptr = chk_shmem.as_slice_mut().as_mut_ptr();
    unsafe { CHECKPOINT_MAP_PTR = chk_ptr };

    let mut feedback = feedback_or!(
        MaxMapFeedback::new(&cov_observer),
        MaxMapFeedback::new(&state_observer)
    );
    let mut objective = CrashFeedback::new();
    let mut state = StdState::new(
        StdRand::with_seed(0x1337),
        InMemoryCorpus::<BytesInput>::new(),
        OnDiskCorpus::new(args.crashes.clone()).unwrap(),
        &mut feedback,
        &mut objective,
    )
    .unwrap();

    let monitor = SimpleMonitor::new(|s| println!("{s}"));
    let mut mgr = SimpleEventManager::new(monitor);
    let scheduler = QueueScheduler::new();
    let mut fuzzer = StdFuzzer::new(scheduler, feedback, objective);

    // -----------------------------------------------------------------------
    // Harness: state hash + discriminant checkpoint tracking.
    // -----------------------------------------------------------------------

    let config = loaded.config.clone();
    let sf = state_fields;
    let burst_state_fields = sf.clone();

    let mut harness = move |input: &BytesInput| {
        // Zero the flag so stale data from the previous run is not re-read.
        unsafe {
            if !CHECKPOINT_MAP_PTR.is_null() {
                *CHECKPOINT_MAP_PTR = 0;
            }
        }

        let bytes = input.target_bytes();
        let data: &[u8] = bytes.as_ref();
        if data.len() < required_len {
            return ExitKind::Ok;
        }

        let mut hwm = vec![i32::MIN; sf.len()];
        let mut discriminant_max = -1i32;
        let mut best_snap = vec![0u8; struct_size];

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
                if let Some((off, sz)) = discriminant_info {
                    let v = read_i32_from_state(snap, off, sz);
                    if v > discriminant_max {
                        discriminant_max = v;
                        let n = snap.len().min(best_snap.len());
                        best_snap[..n].copy_from_slice(&snap[..n]);
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

        // Write checkpoint only when discriminant actually advanced above zero.
        if executed && discriminant_max > 0 {
            unsafe {
                if !CHECKPOINT_MAP_PTR.is_null() {
                    // Generation field is written by the parent before fuzz_one;
                    // echo it back so the parent can verify freshness.
                    let read_gen = chk_read_gen(CHECKPOINT_MAP_PTR);
                    chk_write_header(CHECKPOINT_MAP_PTR, 1, discriminant_max as usize, read_gen);
                    let n = best_snap.len().min(struct_size);
                    std::ptr::copy_nonoverlapping(
                        best_snap.as_ptr(),
                        CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                        n,
                    );
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
    // Seed corpus.
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

    // -----------------------------------------------------------------------
    // Checkpoint table.
    // -----------------------------------------------------------------------

    let max_discriminant: usize = zone_config
        .as_ref()
        .map(|zc| zc.max_discriminant as usize)
        .unwrap_or(255);
    let chk_table_len = max_discriminant + 1;
    let mut checkpoint_table: Vec<Option<(Vec<u8>, u32)>> = vec![None; chk_table_len];

    let burst_size = args.burst_size;
    let rollout_frames = args.rollout_frames;
    let burst_repeats = args.burst_repeats;
    let checkpoint_strategy = args.checkpoint_strategy;
    let crashes_dir = args.crashes.clone();
    let zone_cfg = zone_config;
    let burst_fields = runtime_input_fields.clone();

    println!("[prism-go-explore] Fuzzing — Ctrl+C to stop");

    let start_time = std::time::Instant::now();
    let mut total_fuzz_iters: u64 = 0;
    let mut total_bursts: u64 = 0;
    let mut last_heartbeat = std::time::Instant::now();
    let heartbeat_interval = std::time::Duration::from_secs(30);
    // Generation counter for checkpoint shmem freshness checks (step 3).
    let mut chk_gen: u16 = 0;

    loop {
        // Phase 1: standard mutation-guided fuzzing.
        for _ in 0..burst_size {
            // Write current generation to shmem bytes 3-4 so the child can echo it.
            unsafe {
                if !chk_ptr.is_null() {
                    *chk_ptr.add(3) = (chk_gen & 0xFF) as u8;
                    *chk_ptr.add(4) = ((chk_gen >> 8) & 0xFF) as u8;
                }
            }
            chk_gen = chk_gen.wrapping_add(1);

            fuzzer
                .fuzz_one(&mut stages, &mut executor, &mut state, &mut mgr)
                .unwrap();
            total_fuzz_iters += 1;

            // Read checkpoint written by the child (after waitpid inside fuzz_one).
            let flag = unsafe { if !chk_ptr.is_null() { *chk_ptr } else { 0 } };
            if flag == 1 {
                let bucket = unsafe { chk_read_bucket(chk_ptr) };
                let returned_gen = unsafe { chk_read_gen(chk_ptr) };
                let expected_gen = chk_gen.wrapping_sub(1);
                if returned_gen == expected_gen && bucket < chk_table_len {
                    let mut snap = vec![0u8; struct_size];
                    unsafe {
                        std::ptr::copy_nonoverlapping(
                            chk_ptr.add(CHECKPOINT_HDR),
                            snap.as_mut_ptr(),
                            struct_size,
                        );
                    }
                    let disc_offset = discriminant_info.map(|(o, _)| o).unwrap_or(usize::MAX);
                    let sub_accum = zone_cfg
                        .as_ref()
                        .map(|zc| zc.sub_accumulator_fields.as_slice())
                        .unwrap_or(&[]);
                    let quality =
                        snapshot_quality(&snap, sub_accum, &burst_state_fields, disc_offset);
                    let is_new = checkpoint_table[bucket].is_none();
                    let update = is_new
                        || checkpoint_table[bucket]
                            .as_ref()
                            .map_or(false, |(_, q)| quality > *q);
                    if update {
                        checkpoint_table[bucket] = Some((snap, quality));
                        if is_new {
                            let n_chk =
                                checkpoint_table.iter().filter(|s| s.is_some()).count();
                            let best = checkpoint_table
                                .iter()
                                .enumerate()
                                .rfind(|(_, s)| s.is_some())
                                .map(|(i, _)| i)
                                .unwrap_or(0);
                            eprintln!(
                                "[goexplore] NEW checkpoint: bucket={bucket} quality={quality} | total_checkpoints={n_chk} | best_bucket={best}"
                            );
                        }
                    }
                }
            }
        }

        // Heartbeat.
        if last_heartbeat.elapsed() >= heartbeat_interval {
            last_heartbeat = std::time::Instant::now();
            let elapsed = start_time.elapsed().as_secs_f64();
            let filled: Vec<String> = checkpoint_table
                .iter()
                .enumerate()
                .filter(|(_, s)| s.is_some())
                .map(|(i, _)| i.to_string())
                .collect();
            let best = checkpoint_table
                .iter()
                .enumerate()
                .rfind(|(_, s)| s.is_some())
                .map(|(i, _)| i.to_string())
                .unwrap_or_else(|| "none".to_string());
            eprintln!(
                "[goexplore] t={:.0}s | fuzz_iters={total_fuzz_iters} ({:.0}/s) | bursts={total_bursts} | checkpoints=[{}] | best_bucket={best}",
                elapsed,
                total_fuzz_iters as f64 / elapsed.max(0.001),
                filled.join(","),
            );
        }

        // Phase 2: burst from checkpoints.
        match checkpoint_strategy {
            CheckpointStrategy::Best => {
                let best_bucket = checkpoint_table
                    .iter()
                    .enumerate()
                    .rfind(|(_, s)| s.is_some())
                    .map(|(i, _)| i);
                if let Some(bucket) = best_bucket {
                    if let Some((snap, _quality)) = checkpoint_table[bucket].clone() {
                        for _ in 0..burst_repeats {
                            total_bursts += 1;
                            checkpoint_burst(
                                bucket, &snap, zone_cfg.as_ref(), &burst_state_fields,
                                &burst_fields, frame_size, rollout_frames, &crashes_dir,
                                struct_size, discriminant_info, &mut checkpoint_table,
                                chk_gen,
                            );
                            chk_gen = chk_gen.wrapping_add(1);
                        }
                    }
                }
            }
            CheckpointStrategy::RoundRobin => {
                let filled: Vec<(usize, Vec<u8>)> = checkpoint_table
                    .iter()
                    .enumerate()
                    .filter_map(|(i, s)| s.clone().map(|(snap, _q)| (i, snap)))
                    .rev()
                    .collect();
                if !filled.is_empty() {
                    let per_bucket = (burst_repeats / filled.len()).max(1);
                    for (bucket, snap) in &filled {
                        for _ in 0..per_bucket {
                            total_bursts += 1;
                            checkpoint_burst(
                                *bucket, snap, zone_cfg.as_ref(), &burst_state_fields,
                                &burst_fields, frame_size, rollout_frames, &crashes_dir,
                                struct_size, discriminant_info, &mut checkpoint_table,
                                chk_gen,
                            );
                            chk_gen = chk_gen.wrapping_add(1);
                        }
                    }
                }
            }
        }
    }
}
