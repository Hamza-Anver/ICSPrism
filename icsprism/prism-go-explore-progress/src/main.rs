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
    rands::{Rand, StdRand},
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
    StateHashField, SubAccumulatorField, WeightsJson, build_ddg_distances, build_name_scores,
    build_runtime_input_fields, checkpoint_score, compute_bucket, ddg_byte_weights,
    expand_weights_for_sequence, infer_i16_targets_from_ddg, input_fields_from_weights_json,
    parse_state_hash_config, read_i32_from_state, snapshot_quality,
    COV_MAP_SIZE, STATE_MAP_SIZE,
};
use serde::Deserialize;

// ---------------------------------------------------------------------------
// Checkpoint shmem header (6 bytes):
//   byte 0:   flag      (0 = empty, 1 = valid checkpoint written)
//   byte 1:   stage_id  (STAGE_PRIMARY=0xFF for FillHead; 0..N for progress stages)
//   bytes 2-3: bucket as u16 LE  (discriminant value at peak, no 255 cap)
//   bytes 4-5: chk_gen as u16 LE (freshness counter written by parent, echoed by child)
//   bytes 6+:  PLC struct snapshot
// ---------------------------------------------------------------------------
const CHECKPOINT_HDR: usize = 6;
const STAGE_PRIMARY: u8 = 0xFF;

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
    name = "prism-go-explore-progress",
    about = "Go-Explore fuzzer with Hierarchical Discriminant Sequence: \
             checkpoints at intermediate progress variables (Phase, PrimeScore, …) \
             reduce the cold-start gap for multi-phase programs"
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

    /// Zone constraints JSON — may include a `progress_stages` array for HDS.
    #[arg(long)]
    zone_constraints: Option<PathBuf>,

    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    #[arg(short, long, default_value_t = 8)]
    seeds: usize,

    #[arg(long)]
    config: Option<PathBuf>,

    #[arg(long, default_value_t = 128)]
    rollout_frames: usize,

    #[arg(long, default_value_t = 500)]
    burst_size: usize,

    #[arg(long, default_value_t = 50)]
    burst_repeats: usize,

    #[arg(long, value_enum, default_value_t = CheckpointStrategy::Best)]
    checkpoint_strategy: CheckpointStrategy,
}

#[derive(clap::ValueEnum, Clone, Copy, Debug, PartialEq, Eq)]
enum CheckpointStrategy {
    Best,
    RoundRobin,
}

// ---------------------------------------------------------------------------
// Zone constraint types (primary discriminant + optional progress stages)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Deserialize)]
struct FieldRange {
    lo: i16,
    hi: i16,
}

#[derive(Debug, Clone, Deserialize)]
struct ZoneConstraint {
    #[allow(dead_code)]
    id: usize,
    #[serde(alias = "fillhead_lo")]
    lo: i32,
    #[serde(alias = "fillhead_hi")]
    hi: i32,
    #[serde(default)]
    field_constraints: HashMap<String, FieldRange>,
}

/// One entry in `progress_stages`: an intermediate accumulating variable (e.g. PrimeScore)
/// that must advance before the primary discriminant (e.g. FillHead) can start moving.
///
/// Gate condition: `read_i32(snap, gate_offset, gate_size) == gate_eq_value`
/// When the gate is satisfied, `read_i32(snap, disc_offset, disc_size)` is the progress value.
#[derive(Debug, Clone, Deserialize)]
struct ProgressStage {
    /// 0-based ordering (lower = earlier in the phase sequence).
    stage: usize,
    /// Human-readable name used in log messages.
    name: String,
    #[allow(dead_code)]
    discriminant_field: String,
    discriminant_offset: usize,
    discriminant_size: usize,
    /// Highest value the discriminant can reach in this stage.
    max_value: usize,
    #[allow(dead_code)]
    gate_field: String,
    gate_offset: usize,
    gate_size: usize,
    /// The gate field must equal this value for this stage to be active.
    gate_eq_value: i32,
    /// Flat per-field [lo, hi] ranges used when generating burst frames for this stage.
    /// No per-bucket zones — the stage doesn't know which primary zone it will end up in.
    #[serde(default)]
    burst_field_constraints: HashMap<String, FieldRange>,
}

#[derive(Debug, Clone, Deserialize)]
struct ZoneConstraintsConfig {
    #[allow(dead_code)]
    discriminant_field: String,
    #[serde(alias = "fillhead_byte_offset")]
    discriminant_byte_offset: usize,
    #[serde(alias = "fillhead_byte_size")]
    discriminant_byte_size: usize,
    #[serde(alias = "max_fillhead", default = "default_max_discriminant")]
    max_discriminant: u32,
    #[serde(default)]
    sub_accumulator_fields: Vec<SubAccumulatorField>,
    /// Ordered from earliest (lowest stage number) to latest.
    #[serde(default)]
    progress_stages: Vec<ProgressStage>,
    zones: Vec<ZoneConstraint>,
}

fn default_max_discriminant() -> u32 {
    255
}

// ---------------------------------------------------------------------------
// Runtime state for one progress stage
// ---------------------------------------------------------------------------

struct StageRuntime {
    cfg: ProgressStage,
    /// Checkpoint table indexed by discriminant value (0..=max_value).
    table: Vec<Option<(Vec<u8>, u32)>>,
}

impl StageRuntime {
    fn new(cfg: ProgressStage) -> Self {
        let len = cfg.max_value + 1;
        Self { cfg, table: vec![None; len] }
    }

    fn best_entry(&self) -> Option<(usize, &Vec<u8>, u32)> {
        self.table
            .iter()
            .enumerate()
            .rev()
            .find_map(|(i, e)| e.as_ref().map(|(s, q)| (i, s, *q)))
    }

    fn update(&mut self, bucket: usize, snap: Vec<u8>) {
        if bucket >= self.table.len() {
            return;
        }
        let quality = bucket as u32; // quality = discriminant value for stage checkpoints
        let is_new = self.table[bucket].is_none();
        let update = is_new || self.table[bucket].as_ref().map_or(false, |(_, q)| quality > *q);
        if update {
            let dist = self.cfg.max_value.saturating_sub(bucket);
            if is_new {
                eprintln!(
                    "[gxp] NEW stage checkpoint: stage={} ({}) bucket={} dist={}",
                    self.cfg.stage, self.cfg.name, bucket, dist
                );
            }
            self.table[bucket] = Some((snap, quality));
        }
    }
}

// ---------------------------------------------------------------------------
// Zone helpers
// ---------------------------------------------------------------------------

const RAMP_WINDOW: i32 = 2;

fn find_zone_idx(zones: &[ZoneConstraint], bucket: usize) -> Option<usize> {
    zones.iter().position(|z| bucket as i32 >= z.lo && (bucket as i32) < z.hi)
}

// ---------------------------------------------------------------------------
// Frame generation (shared for primary zones and flat stage constraints)
// ---------------------------------------------------------------------------

fn rand_i16_in(rng: &mut impl Rand, lo: i16, hi: i16) -> i16 {
    if lo >= hi { return lo; }
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

/// Generate `n_frames` packed input frames, sampling each field from `field_constraints`
/// when present, falling back to the field's own model (targets, bool, raw).
/// This function is used both for primary zone bursts and flat stage bursts.
fn generate_frames(
    field_constraints: &HashMap<String, FieldRange>,
    input_fields: &[InputField],
    frame_size: usize,
    n_frames: usize,
    rng: &mut impl Rand,
) -> Vec<u8> {
    let mut out = vec![0u8; frame_size * n_frames];
    for fi in 0..n_frames {
        let frame = &mut out[fi * frame_size..(fi + 1) * frame_size];
        for field in input_fields {
            if field.offset >= frame_size || field.size == 0 { continue; }
            let end = (field.offset + field.size).min(frame_size);
            if field.role == FieldRole::Inhibitor {
                for b in &mut frame[field.offset..end] { *b = 0; }
            } else if let Some(range) = field_constraints.get(&field.name) {
                if field.size == 2 {
                    write_i16_le(frame, field.offset, rand_i16_in(rng, range.lo, range.hi));
                } else if field.size == 1 {
                    frame[field.offset] = rand_i16_in(rng, range.lo.max(0), range.hi.max(0)) as u8;
                }
            } else {
                match &field.model {
                    prism_runtime::fuzzing::FieldValueModel::I16 { targets } if !targets.is_empty() => {
                        let value: i16 = if (rng.next() % 100) < 80 {
                            targets[(rng.next() as usize) % targets.len()]
                        } else {
                            rng.next() as i16
                        };
                        if field.size == 2 { write_i16_le(frame, field.offset, value); }
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
// Checkpoint shmem helpers
// ---------------------------------------------------------------------------

unsafe fn chk_read_stage(ptr: *const u8) -> u8      { unsafe { *ptr.add(1) } }
unsafe fn chk_read_bucket(ptr: *const u8) -> usize  {
    unsafe { (*ptr.add(2) as usize) | ((*ptr.add(3) as usize) << 8) }
}
unsafe fn chk_read_gen(ptr: *const u8) -> u16 {
    unsafe { (*ptr.add(4) as u16) | ((*ptr.add(5) as u16) << 8) }
}
unsafe fn chk_write_header(ptr: *mut u8, flag: u8, stage_id: u8, bucket: usize, chk_gen: u16) {
    unsafe {
        *ptr          = flag;
        *ptr.add(1)   = stage_id;
        *ptr.add(2)   = (bucket & 0xFF) as u8;
        *ptr.add(3)   = ((bucket >> 8) & 0xFF) as u8;
        *ptr.add(4)   = (chk_gen & 0xFF) as u8;
        *ptr.add(5)   = ((chk_gen >> 8) & 0xFF) as u8;
    }
}

// ---------------------------------------------------------------------------
// Unified burst: fork child, restore snapshot, run frames, track discriminant.
// Returns true if the child crashed (caller should exit).
// The child writes stage_id + best bucket + snapshot to CHECKPOINT_MAP_PTR.
// ---------------------------------------------------------------------------

fn run_burst(
    stage_id: u8,
    start_bucket: usize,
    snapshot: &[u8],
    frames: &[u8],
    frame_size: usize,
    disc_offset: usize,
    disc_size: usize,
    chk_gen: u16,
    struct_size: usize,
    crashes_dir: &Path,
    label: &str,
) -> bool {
    if frame_size == 0 || frames.is_empty() || snapshot.len() < struct_size {
        return false;
    }

    unsafe { if !CHECKPOINT_MAP_PTR.is_null() { *CHECKPOINT_MAP_PTR = 0; } }

    let child = unsafe { libc::fork() };
    if child < 0 {
        eprintln!("[gxp] fork() failed for {label} burst");
        return false;
    }

    if child == 0 {
        unsafe { COV_MAP_PTR = std::ptr::null_mut(); STATE_MAP_PTR = std::ptr::null_mut(); }

        let mut best_val = -1i32;
        let mut best_snap = vec![0u8; struct_size];

        execute_testcase_from_checkpoint(snapshot, frames, frame_size, &mut |snap| {
            let v = read_i32_from_state(snap, disc_offset, disc_size);
            if v > best_val {
                best_val = v;
                let n = snap.len().min(struct_size);
                best_snap[..n].copy_from_slice(&snap[..n]);
            }
        });

        if best_val > 0 {
            unsafe {
                if !CHECKPOINT_MAP_PTR.is_null() {
                    std::ptr::write_bytes(CHECKPOINT_MAP_PTR, 0, CHECKPOINT_HDR);
                    chk_write_header(CHECKPOINT_MAP_PTR, 1, stage_id, best_val as usize, chk_gen);
                    std::ptr::copy_nonoverlapping(
                        best_snap.as_ptr(),
                        CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                        struct_size,
                    );
                }
            }
        }

        unsafe { libc::_exit(0) };
    }

    let mut status = 0i32;
    unsafe { libc::waitpid(child, &mut status, 0) };

    if libc::WIFSIGNALED(status) {
        let sig = libc::WTERMSIG(status);
        eprintln!("[gxp] CRASH from {label} burst at bucket={start_bucket} signal={sig}");
        let path = crashes_dir.join(format!("crash_{label}_bucket{start_bucket}"));
        let mut data = snapshot.to_vec();
        data.extend_from_slice(frames);
        let _ = std::fs::write(&path, &data);
        return true;
    }
    false
}

// ---------------------------------------------------------------------------
// Frame builders for primary (zone-aware) and stage (flat) bursts
// ---------------------------------------------------------------------------

fn primary_frames(
    bucket: usize,
    zone_config: &ZoneConstraintsConfig,
    input_fields: &[InputField],
    frame_size: usize,
    rollout_frames: usize,
    rng: &mut impl Rand,
) -> Vec<u8> {
    let empty: HashMap<String, FieldRange> = HashMap::new();
    if let Some(cur_idx) = find_zone_idx(&zone_config.zones, bucket) {
        let cur_zone = &zone_config.zones[cur_idx];
        let gap = cur_zone.hi - 1 - bucket as i32;
        let next_zone = if gap <= RAMP_WINDOW { zone_config.zones.get(cur_idx + 1) } else { None };
        if let Some(nz) = next_zone {
            let phase1 = rollout_frames * 7 / 10;
            let phase2 = rollout_frames - phase1;
            let mut f = generate_frames(&cur_zone.field_constraints, input_fields, frame_size, phase1, rng);
            f.extend(generate_frames(&nz.field_constraints, input_fields, frame_size, phase2, rng));
            f
        } else {
            generate_frames(&cur_zone.field_constraints, input_fields, frame_size, rollout_frames, rng)
        }
    } else {
        let last = zone_config.zones.last().map(|z| &z.field_constraints).unwrap_or(&empty);
        generate_frames(last, input_fields, frame_size, rollout_frames, rng)
    }
}

fn stage_frames(
    stage: &ProgressStage,
    input_fields: &[InputField],
    frame_size: usize,
    rollout_frames: usize,
    rng: &mut impl Rand,
) -> Vec<u8> {
    generate_frames(&stage.burst_field_constraints, input_fields, frame_size, rollout_frames, rng)
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    let args = Args::parse();
    let loaded = load_config(args.config.as_deref())
        .unwrap_or_else(|e| panic!("[gxp] {e}"));

    let ddg: Ddg = serde_json::from_reader(
        File::open(&args.ddg).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", args.ddg)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse DDG JSON: {e}"));

    let layouts: Vec<ProgramLayout> = serde_json::from_reader(
        File::open(&args.layout).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", args.layout)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {e}"));
    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    let state_fields: Vec<StateHashField> = args.state_hash.as_ref().map(|p| {
        let raw: StateHashConfigRaw = serde_json::from_reader(
            File::open(p).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", p)),
        )
        .unwrap_or_else(|e| panic!("Cannot parse state hash JSON: {e}"));
        let fields = parse_state_hash_config(raw);
        let total = fields.iter().map(|f| f.bucket_count).sum::<usize>();
        println!("[gxp] State hash: {} fields, {} shmem slots", fields.len(), total);
        fields
    }).unwrap_or_default();

    let zone_config: Option<ZoneConstraintsConfig> = args.zone_constraints.as_ref().map(|p| {
        let raw = std::fs::read_to_string(p)
            .unwrap_or_else(|e| panic!("Cannot read zone constraints {:?}: {e}", p));
        serde_json::from_str(&raw)
            .unwrap_or_else(|e| panic!("Cannot parse zone constraints JSON: {e}"))
    });

    let discriminant_info: Option<(usize, usize)> = zone_config
        .as_ref()
        .map(|zc| (zc.discriminant_byte_offset, zc.discriminant_byte_size));

    // Build progress stage runtimes (ordered stage 0 = earliest prerequisite).
    let mut stage_runtimes: Vec<StageRuntime> = zone_config
        .as_ref()
        .map(|zc| {
            let mut stages: Vec<_> = zc.progress_stages.iter().cloned().collect();
            stages.sort_by_key(|s| s.stage);
            stages.into_iter().map(StageRuntime::new).collect()
        })
        .unwrap_or_default();

    let dims = harness_dimensions();
    let frame_size = dims.input_size;
    let struct_size = dims.struct_size;
    let required_len = required_input_len(&loaded.config, frame_size);

    let dist = build_ddg_distances(&ddg);
    let name_scores = build_name_scores(&ddg, &dist);
    let i16_targets = infer_i16_targets_from_ddg(&ddg, &dist);
    let ddg_fields = build_runtime_input_fields(&layout, frame_size, &name_scores, &i16_targets);

    let (base_weights, input_fields, weights_src) = if let Some(wp) = &args.weights_json {
        let wj: WeightsJson = serde_json::from_reader(
            File::open(wp).unwrap_or_else(|e| panic!("Cannot open {:?}: {e}", wp)),
        )
        .unwrap_or_else(|e| panic!("Cannot parse weights JSON: {e}"));
        let (bw, fields) = input_fields_from_weights_json(wj, frame_size);
        (bw, fields, "weights JSON")
    } else {
        let bw = ddg_byte_weights(&ddg_fields, frame_size);
        (bw, ddg_fields.clone(), "DDG analysis")
    };

    let weights = expand_weights_for_sequence(&base_weights, required_len);
    let max_discriminant = zone_config.as_ref().map(|zc| zc.max_discriminant as usize).unwrap_or(255);

    println!("[gxp] Program      : {}", layout.struct_name);
    println!("[gxp] Struct size  : {} bytes", struct_size);
    println!("[gxp] Input frame  : {} bytes", frame_size);
    println!("[gxp] Input total  : {} bytes", required_len);
    println!("[gxp] Mode         : {:?}", loaded.config.execution.mode);
    println!("[gxp] Weights src  : {}", weights_src);
    println!("[gxp] Config       : {}", loaded.source_label());
    println!("[gxp] Crashes      : {}", args.crashes.display());
    if let Some(ref zc) = zone_config {
        println!("[gxp] Zone config  : {} zones, disc_max={}", zc.zones.len(), max_discriminant);
    }
    if stage_runtimes.is_empty() {
        println!("[gxp] Stages       : none (running as standard go-explore)");
    } else {
        for sr in &stage_runtimes {
            println!("[gxp] Stage {}      : {} (disc_max={}, gate=={})",
                sr.cfg.stage, sr.cfg.name, sr.cfg.max_value, sr.cfg.gate_eq_value);
        }
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
    // Harness: track primary discriminant + all progress stages simultaneously.
    //
    // After each testcase, report the single most-interesting advance to shmem:
    //   1. Primary advance (FillHead) — highest priority.
    //   2. Highest-numbered stage advance (closest predecessor to primary).
    //
    // For phase-gated programs (pipeline_controller), primary and stages are
    // mutually exclusive per testcase, so no advance is ever lost.
    // -----------------------------------------------------------------------

    let config_clone = loaded.config.clone();
    let sf = state_fields.clone();

    // Extract stage tracking info for the closure without capturing the full runtimes.
    // The closure only writes shmem; the main loop updates the tables.
    let stage_track: Vec<(usize, usize, usize, usize, i32)> = stage_runtimes
        .iter()
        .map(|sr| (
            sr.cfg.discriminant_offset,
            sr.cfg.discriminant_size,
            sr.cfg.gate_offset,
            sr.cfg.gate_size,
            sr.cfg.gate_eq_value,
        ))
        .collect();

    let mut harness = move |input: &BytesInput| {
        // Zero flag so stale data is not re-read.
        unsafe { if !CHECKPOINT_MAP_PTR.is_null() { *CHECKPOINT_MAP_PTR = 0; } }

        let bytes = input.target_bytes();
        let data: &[u8] = bytes.as_ref();
        if data.len() < required_len { return ExitKind::Ok; }

        let mut hwm = vec![i32::MIN; sf.len()];
        let mut disc_max = -1i32;
        let mut disc_best_snap = vec![0u8; struct_size];
        let mut stage_maxes = vec![-1i32; stage_track.len()];
        let mut stage_best_snaps: Vec<Vec<u8>> = (0..stage_track.len())
            .map(|_| vec![0u8; struct_size])
            .collect();

        let executed = execute_testcase_with_state_snapshots(
            &config_clone, data, frame_size,
            &mut |snap: &[u8]| {
                // State hash HWM tracking.
                for (i, field) in sf.iter().enumerate() {
                    let v = read_i32_from_state(snap, field.absolute_byte_offset, field.byte_size);
                    hwm[i] = if field.high_watermark { hwm[i].max(v) } else { v };
                }
                // Primary discriminant tracking.
                if let Some((off, sz)) = discriminant_info {
                    let v = read_i32_from_state(snap, off, sz);
                    if v > disc_max {
                        disc_max = v;
                        let n = snap.len().min(struct_size);
                        disc_best_snap[..n].copy_from_slice(&snap[..n]);
                    }
                }
                // Progress stage tracking: gate-guarded, stage-specific.
                for (i, (doff, dsz, goff, gsz, geq)) in stage_track.iter().enumerate() {
                    let gate = read_i32_from_state(snap, *goff, *gsz);
                    if gate == *geq {
                        let v = read_i32_from_state(snap, *doff, *dsz);
                        if v > stage_maxes[i] {
                            stage_maxes[i] = v;
                            let n = snap.len().min(struct_size);
                            stage_best_snaps[i][..n].copy_from_slice(&snap[..n]);
                        }
                    }
                }
            },
        );

        if executed {
            // State hash shmem.
            for (i, field) in sf.iter().enumerate() {
                if hwm[i] == i32::MIN { continue; }
                let bucket = compute_bucket(field, hwm[i]);
                let slot = field.shmem_base + bucket;
                if slot < STATE_MAP_SIZE {
                    unsafe { *STATE_MAP_PTR.add(slot) = 1 };
                }
            }

            // Report the best advance.  Primary takes priority; otherwise report the
            // highest-stage advance (index = highest = closest to primary).
            if disc_max > 0 {
                unsafe {
                    if !CHECKPOINT_MAP_PTR.is_null() {
                        let read_chk_gen = chk_read_gen(CHECKPOINT_MAP_PTR);
                        std::ptr::write_bytes(CHECKPOINT_MAP_PTR, 0, CHECKPOINT_HDR);
                        chk_write_header(
                            CHECKPOINT_MAP_PTR, 1, STAGE_PRIMARY, disc_max as usize, read_chk_gen,
                        );
                        let n = disc_best_snap.len().min(struct_size);
                        std::ptr::copy_nonoverlapping(
                            disc_best_snap.as_ptr(),
                            CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                            n,
                        );
                    }
                }
            } else {
                // Find highest-numbered stage with an advance.
                for (i, &val) in stage_maxes.iter().enumerate().rev() {
                    if val > 0 {
                        unsafe {
                            if !CHECKPOINT_MAP_PTR.is_null() {
                                let read_chk_gen = chk_read_gen(CHECKPOINT_MAP_PTR);
                                std::ptr::write_bytes(CHECKPOINT_MAP_PTR, 0, CHECKPOINT_HDR);
                                chk_write_header(
                                    CHECKPOINT_MAP_PTR, 1, i as u8, val as usize, read_chk_gen,
                                );
                                let n = stage_best_snaps[i].len().min(struct_size);
                                std::ptr::copy_nonoverlapping(
                                    stage_best_snaps[i].as_ptr(),
                                    CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                                    n,
                                );
                            }
                        }
                        break;
                    }
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
    // Seed corpus
    // -----------------------------------------------------------------------

    let mut generator =
        RandBytesGenerator::new(std::num::NonZeroUsize::new(required_len.max(1)).unwrap());
    state
        .generate_initial_inputs_forced(
            &mut fuzzer, &mut executor, &mut generator, &mut mgr, args.seeds,
        )
        .unwrap();

    let field_mutator = FieldValueMutator::new(frame_size, input_fields.clone());
    let frame_mutator = FramePatternMutator::new(frame_size, &input_fields);
    let range_mutator = InputRangeMutator::new(frame_size, &input_fields, &base_weights);
    let window_mutator = AccumulationWindowMutator::new(frame_size, &input_fields);
    let ddg_mutator = DdgByteMutator::new(weights);
    let mutator = HavocScheduledMutator::new(
        tuple_list!(field_mutator, frame_mutator, range_mutator, window_mutator, ddg_mutator)
            .merge(havoc_mutations()),
    );
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    // -----------------------------------------------------------------------
    // Primary checkpoint table
    // -----------------------------------------------------------------------

    let mut primary_table: Vec<Option<(Vec<u8>, u32)>> = vec![None; max_discriminant + 1];

    let burst_size = args.burst_size;
    let rollout_frames = args.rollout_frames;
    let burst_repeats = args.burst_repeats;
    let checkpoint_strategy = args.checkpoint_strategy;
    let crashes_dir = args.crashes.clone();
    let burst_fields = input_fields.clone();
    let zone_cfg = zone_config.clone();
    let burst_state_fields = state_fields.clone();

    println!("[gxp] Fuzzing — Ctrl+C to stop");

    let start_time = std::time::Instant::now();
    let mut total_fuzz_iters: u64 = 0;
    let mut total_bursts: u64 = 0;
    let mut last_heartbeat = std::time::Instant::now();
    let heartbeat_interval = std::time::Duration::from_secs(30);
    let mut chk_gen: u16 = 0;

    loop {
        // -----------------------------------------------------------------------
        // Phase 1: standard mutation fuzzing + checkpoint ingestion.
        // -----------------------------------------------------------------------
        for _ in 0..burst_size {
            // Write generation counter so the child can echo it back.
            unsafe {
                if !chk_ptr.is_null() {
                    *chk_ptr.add(4) = (chk_gen & 0xFF) as u8;
                    *chk_ptr.add(5) = ((chk_gen >> 8) & 0xFF) as u8;
                }
            }
            chk_gen = chk_gen.wrapping_add(1);

            fuzzer.fuzz_one(&mut stages, &mut executor, &mut state, &mut mgr).unwrap();
            total_fuzz_iters += 1;

            // Read checkpoint from shmem (child has exited via waitpid inside fuzz_one).
            let flag = unsafe { if !chk_ptr.is_null() { *chk_ptr } else { 0 } };
            if flag != 1 { continue; }

            let returned_stage = unsafe { chk_read_stage(chk_ptr) };
            let bucket = unsafe { chk_read_bucket(chk_ptr) };
            let returned_gen = unsafe { chk_read_gen(chk_ptr) };
            if returned_gen != chk_gen.wrapping_sub(1) { continue; }

            let mut snap = vec![0u8; struct_size];
            unsafe {
                std::ptr::copy_nonoverlapping(
                    chk_ptr.add(CHECKPOINT_HDR), snap.as_mut_ptr(), struct_size,
                );
            }

            if returned_stage == STAGE_PRIMARY {
                // Route to primary table.
                if bucket >= primary_table.len() { continue; }
                let disc_offset = discriminant_info.map(|(o, _)| o).unwrap_or(usize::MAX);
                let sub_accum = zone_cfg.as_ref()
                    .map(|zc| zc.sub_accumulator_fields.as_slice()).unwrap_or(&[]);
                let quality = snapshot_quality(&snap, sub_accum, &burst_state_fields, disc_offset);
                let is_new = primary_table[bucket].is_none();
                let update = is_new || primary_table[bucket].as_ref().map_or(false, |(_, q)| quality > *q);
                if update {
                    primary_table[bucket] = Some((snap, quality));
                    if is_new {
                        let n_chk = primary_table.iter().filter(|e| e.is_some()).count();
                        let dist = max_discriminant.saturating_sub(bucket);
                        eprintln!("[gxp] NEW primary checkpoint: bucket={bucket} dist={dist} quality={quality} | total={n_chk}");
                    }
                }
            } else {
                // Route to the appropriate stage table.
                let sidx = returned_stage as usize;
                if sidx < stage_runtimes.len() && bucket <= stage_runtimes[sidx].cfg.max_value {
                    stage_runtimes[sidx].update(bucket, snap);
                }
            }
        }

        // Heartbeat.
        if last_heartbeat.elapsed() >= heartbeat_interval {
            last_heartbeat = std::time::Instant::now();
            let elapsed = start_time.elapsed().as_secs_f64();
            let max_q = primary_table.iter().filter_map(|e| e.as_ref().map(|(_, q)| *q)).max().unwrap_or(1);
            let primary_desc: Vec<String> = primary_table.iter().enumerate()
                .filter_map(|(i, e)| e.as_ref().map(|(_, q)| {
                    let dist = max_discriminant.saturating_sub(i);
                    let s = checkpoint_score(i, *q, max_discriminant, max_q);
                    format!("{i}(d={dist},s={s:.2})")
                }))
                .collect();
            let stage_desc: Vec<String> = stage_runtimes.iter()
                .flat_map(|sr| sr.best_entry().map(|(b, _, _)| {
                    format!("{}:{}@{}", sr.cfg.stage, sr.cfg.name, b)
                }))
                .collect();
            eprintln!(
                "[gxp] t={:.0}s | iters={total_fuzz_iters} ({:.0}/s) | bursts={total_bursts} | primary=[{}] | stages=[{}]",
                elapsed, total_fuzz_iters as f64 / elapsed.max(0.001),
                primary_desc.join(","), stage_desc.join(","),
            );
        }

        // -----------------------------------------------------------------------
        // Phase 2: burst from checkpoints.
        //
        // Priority: primary (FillHead) > highest-numbered stage with checkpoints.
        // This ensures we always focus on the most advanced state available.
        // -----------------------------------------------------------------------

        let max_q_now = primary_table.iter()
            .filter_map(|e| e.as_ref().map(|(_, q)| *q))
            .max().unwrap_or(1);

        // Collect available burst targets: (priority, bucket, stage_id, snap, frames_fn)
        // We enumerate all eligible bursts then pick according to strategy.
        let have_primary = primary_table.iter().any(|e| e.is_some());
        let highest_stage = stage_runtimes.iter().enumerate().rev()
            .find(|(_, sr)| sr.best_entry().is_some())
            .map(|(i, _)| i);

        // Determine what to burst from.
        let burst_from_primary = have_primary;
        let burst_from_stage = !have_primary && highest_stage.is_some();

        static BURST_SEED: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

        if burst_from_primary {
            match checkpoint_strategy {
                CheckpointStrategy::Best => {
                    let best = primary_table.iter().enumerate()
                        .filter_map(|(i, e)| e.as_ref().map(|(s, q)| {
                            (i, s.clone(), checkpoint_score(i, *q, max_discriminant, max_q_now))
                        }))
                        .max_by(|a, b| a.2.partial_cmp(&b.2).unwrap_or(std::cmp::Ordering::Equal));

                    if let Some((bucket, snap, _)) = best {
                        let zc_ref = zone_cfg.as_ref().unwrap(); // primary bursts always have zone_config
                        for _ in 0..burst_repeats {
                            total_bursts += 1;
                            let bid = BURST_SEED.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                            let seed = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)
                                .map(|d| d.as_nanos() as u64).unwrap_or(0x1337) ^ bid.wrapping_mul(0x9e3779b9);
                            let mut rng = StdRand::with_seed(seed);
                            let frames = primary_frames(bucket, zc_ref, &burst_fields, frame_size, rollout_frames, &mut rng);
                            let (disc_off, disc_sz) = discriminant_info.unwrap_or((0, 0));
                            if run_burst(STAGE_PRIMARY, bucket, &snap, &frames, frame_size, disc_off, disc_sz, chk_gen, struct_size, &crashes_dir, "primary") {
                                std::process::exit(1);
                            }
                            chk_gen = chk_gen.wrapping_add(1);
                            // Read burst result.
                            let flag = unsafe { if !CHECKPOINT_MAP_PTR.is_null() { *CHECKPOINT_MAP_PTR } else { 0 } };
                            if flag == 1 {
                                let returned_stage = unsafe { chk_read_stage(CHECKPOINT_MAP_PTR) };
                                let b2 = unsafe { chk_read_bucket(CHECKPOINT_MAP_PTR) };
                                if returned_stage == STAGE_PRIMARY && b2 < primary_table.len() && b2 > bucket {
                                    let mut snap2 = vec![0u8; struct_size];
                                    unsafe { std::ptr::copy_nonoverlapping(CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR), snap2.as_mut_ptr(), struct_size); }
                                    let disc_offset = discriminant_info.map(|(o, _)| o).unwrap_or(usize::MAX);
                                    let sub_accum = zone_cfg.as_ref().map(|zc| zc.sub_accumulator_fields.as_slice()).unwrap_or(&[]);
                                    let q2 = snapshot_quality(&snap2, sub_accum, &burst_state_fields, disc_offset);
                                    let upd = primary_table[b2].as_ref().map_or(true, |(_, pq)| q2 > *pq);
                                    if upd {
                                        let is_new = primary_table[b2].is_none();
                                        primary_table[b2] = Some((snap2, q2));
                                        if is_new {
                                            eprintln!("[gxp] burst advance: {bucket} → {b2} (quality={q2})");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                CheckpointStrategy::RoundRobin => {
                    let filled: Vec<(usize, Vec<u8>, f64)> = primary_table.iter().enumerate()
                        .filter_map(|(i, e)| e.as_ref().map(|(s, q)| {
                            (i, s.clone(), checkpoint_score(i, *q, max_discriminant, max_q_now))
                        }))
                        .collect();
                    if !filled.is_empty() {
                        let total_score: f64 = filled.iter().map(|(_, _, s)| s).sum::<f64>().max(1e-9);
                        let (disc_off, disc_sz) = discriminant_info.unwrap_or((0, 0));
                        let zc_ref = zone_cfg.as_ref().unwrap();
                        for (bucket, snap, score) in &filled {
                            let n = ((burst_repeats as f64 * score / total_score).round() as usize).max(1);
                            for _ in 0..n {
                                total_bursts += 1;
                                let bid = BURST_SEED.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                let seed = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)
                                    .map(|d| d.as_nanos() as u64).unwrap_or(0x1337) ^ bid.wrapping_mul(0x9e3779b9);
                                let mut rng = StdRand::with_seed(seed);
                                let frames = primary_frames(*bucket, zc_ref, &burst_fields, frame_size, rollout_frames, &mut rng);
                                if run_burst(STAGE_PRIMARY, *bucket, snap, &frames, frame_size, disc_off, disc_sz, chk_gen, struct_size, &crashes_dir, "primary") {
                                    std::process::exit(1);
                                }
                                chk_gen = chk_gen.wrapping_add(1);
                            }
                        }
                    }
                }
            }
        } else if burst_from_stage {
            let sidx = highest_stage.unwrap();
            let sr = &mut stage_runtimes[sidx];
            if let Some((bucket, snap, _)) = sr.best_entry() {
                let snap = snap.clone();
                let stage_cfg = sr.cfg.clone();
                for _ in 0..burst_repeats {
                    total_bursts += 1;
                    let bid = BURST_SEED.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                    let seed = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)
                        .map(|d| d.as_nanos() as u64).unwrap_or(0x1337) ^ bid.wrapping_mul(0x9e3779b9);
                    let mut rng = StdRand::with_seed(seed);
                    let frames = stage_frames(&stage_cfg, &burst_fields, frame_size, rollout_frames, &mut rng);
                    let stage_id = sidx as u8;
                    if run_burst(stage_id, bucket, &snap, &frames, frame_size,
                        stage_cfg.discriminant_offset, stage_cfg.discriminant_size,
                        chk_gen, struct_size, &crashes_dir, &stage_cfg.name) {
                        std::process::exit(1);
                    }
                    chk_gen = chk_gen.wrapping_add(1);
                    // Read burst result — route to stage table.
                    let flag = unsafe { if !CHECKPOINT_MAP_PTR.is_null() { *CHECKPOINT_MAP_PTR } else { 0 } };
                    if flag == 1 {
                        let returned_stage = unsafe { chk_read_stage(CHECKPOINT_MAP_PTR) };
                        let b2 = unsafe { chk_read_bucket(CHECKPOINT_MAP_PTR) };
                        if returned_stage == stage_id && b2 <= stage_cfg.max_value && b2 > bucket {
                            let mut snap2 = vec![0u8; struct_size];
                            unsafe { std::ptr::copy_nonoverlapping(CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR), snap2.as_mut_ptr(), struct_size); }
                            stage_runtimes[sidx].update(b2, snap2);
                        }
                    }
                }
            }
        }
    }
}
