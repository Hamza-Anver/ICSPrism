use std::{
    collections::{BTreeSet, HashMap, VecDeque},
    ffi::CStr,
    fs::File,
    os::raw::c_char,
    path::{Path, PathBuf},
};

use clap::Parser;
use libafl::{
    Error,
    corpus::{CorpusId, InMemoryCorpus, OnDiskCorpus},
    events::SimpleEventManager,
    executors::{ExitKind, InProcessForkExecutor},
    feedback_or,
    feedbacks::{CrashFeedback, MaxMapFeedback},
    fuzzer::{Fuzzer, StdFuzzer},
    generators::RandBytesGenerator,
    inputs::{BytesInput, HasTargetBytes},
    monitors::SimpleMonitor,
    mutators::{HavocScheduledMutator, MutationResult, Mutator, havoc_mutations},
    observers::{HitcountsMapObserver, StdMapObserver},
    schedulers::QueueScheduler,
    stages::StdMutationalStage,
    state::{HasRand, StdState},
};
use libafl_bolts::{
    AsSliceMut, Named,
    rands::{Rand, StdRand},
    shmem::{ShMemProvider, UnixShMemProvider},
    tuples::{Merge, tuple_list},
};
use prism_runtime::{
    execute_testcase_from_checkpoint, execute_testcase_with_state_snapshots,
    harness_dimensions, load_config, required_input_len,
};
use serde::Deserialize;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const COV_MAP_SIZE: usize = 65536;
const STATE_MAP_SIZE: usize = 1024;
/// Checkpoint shmem header: [flag: u8][fillhead_bucket: u8]
const CHECKPOINT_HDR: usize = 2;

static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();
static mut STATE_MAP_PTR: *mut u8 = std::ptr::null_mut();
/// Shared memory for child→parent checkpoint IPC. Points to a shmem region
/// of size CHECKPOINT_HDR + struct_size. Child writes flag=1 + bucket + snapshot;
/// parent reads after each fuzz_one call.
static mut CHECKPOINT_MAP_PTR: *mut u8 = std::ptr::null_mut();

// ---------------------------------------------------------------------------
// SanitizerCoverage callbacks
// ---------------------------------------------------------------------------

unsafe extern "C" {
    fn prism_field_count() -> u32;
    fn prism_field_name(idx: u32) -> *const c_char;
    fn prism_field_size(idx: u32) -> usize;
    fn prism_field_is_input(idx: u32) -> i32;
}

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
    about = "Go-Explore ST fuzzer: checkpoint at FillHead high-watermarks, burst with zone-aware frames"
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

    /// Zone constraints JSON (fillhead byte offset, zone ranges, pvsum decomposition).
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
    #[allow(dead_code)]
    fillhead_lo: i32,
    #[allow(dead_code)]
    fillhead_hi: i32,
    /// Generic per-field constraints: maps field name → [lo, hi] sampling range.
    /// Only non-inhibitor fields need entries; missing fields fall back to
    /// sampling from their target_values.
    #[serde(default)]
    field_constraints: std::collections::HashMap<String, FieldRange>,
}

#[derive(Debug, Clone, Deserialize)]
struct ZoneConstraintsConfig {
    #[allow(dead_code)]
    discriminant_field: String,
    /// Absolute byte offset of the discriminant field within the struct snapshot.
    fillhead_byte_offset: usize,
    fillhead_byte_size: usize,
    /// Inclusive upper bound for the discriminant — sets checkpoint table size.
    #[serde(default = "default_max_fillhead")]
    max_fillhead: u32,
    zones: Vec<ZoneConstraint>,
}

fn default_max_fillhead() -> u32 {
    255
}

// ---------------------------------------------------------------------------
// DDG deserialization
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct DdgNode {
    id: u64,
    defines: Option<String>,
    ir: String,
    has_dynamic_index: bool,
}

#[derive(Debug, Deserialize)]
struct DdgEdge {
    from: u64,
    to: u64,
}

#[derive(Debug, Deserialize)]
struct Ddg {
    nodes: Vec<DdgNode>,
    edges: Vec<DdgEdge>,
}

#[derive(Debug, Deserialize)]
struct FieldLayout {
    name: Option<String>,
    llvm_type: String,
}

#[derive(Debug, Deserialize)]
struct ProgramLayout {
    struct_name: String,
    total_bytes: u64,
    fields: Vec<FieldLayout>,
}

// ---------------------------------------------------------------------------
// Weights JSON (from probe_ddg_adv.py)
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct InputFieldGuide {
    name: String,
    #[allow(dead_code)]
    llvm_type: String,
    byte_size: usize,
    byte_offset: usize,
    model: String,
    roles: Vec<String>,
    #[serde(default)]
    target_values: Vec<i64>,
}

#[derive(Debug, Deserialize)]
struct WeightsJson {
    #[allow(dead_code)]
    main_function: String,
    #[allow(dead_code)]
    frame_size: usize,
    input_fields: Vec<InputFieldGuide>,
    byte_weights: Vec<f32>,
}

// ---------------------------------------------------------------------------
// State hash config (from ddg_state_hash_heuristics.py)
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct StateHashFieldRaw {
    name: String,
    absolute_byte_offset: usize,
    byte_size: usize,
    bucket_scheme: String,
    thresholds: Vec<i32>,
    bucket_count: usize,
    high_watermark: bool,
}

#[derive(Debug, Deserialize)]
struct StateHashConfigRaw {
    #[allow(dead_code)]
    program: String,
    #[allow(dead_code)]
    total_macro_states: u64,
    fields: Vec<StateHashFieldRaw>,
}

#[derive(Debug, Clone)]
enum BucketScheme {
    Identity,
    ThresholdFine,
    ThresholdLog2,
    RawCapped,
    Binary,
}

#[derive(Debug, Clone)]
struct StateHashField {
    name: String,
    absolute_byte_offset: usize,
    byte_size: usize,
    bucket_scheme: BucketScheme,
    thresholds: Vec<i32>,
    bucket_count: usize,
    high_watermark: bool,
    shmem_base: usize,
}

fn parse_state_hash_config(raw: StateHashConfigRaw) -> Vec<StateHashField> {
    let mut fields = Vec::new();
    let mut shmem_base = 0usize;
    for f in raw.fields {
        if shmem_base >= STATE_MAP_SIZE {
            eprintln!("[prism-go-explore] WARNING: state shmem full, skipping {}", f.name);
            break;
        }
        let bucket_count = f.bucket_count.max(1).min(STATE_MAP_SIZE - shmem_base);
        let scheme = match f.bucket_scheme.as_str() {
            "identity" => BucketScheme::Identity,
            "threshold_fine" => BucketScheme::ThresholdFine,
            "threshold_log2" => BucketScheme::ThresholdLog2,
            "raw_capped" => BucketScheme::RawCapped,
            _ => BucketScheme::Binary,
        };
        fields.push(StateHashField {
            name: f.name,
            absolute_byte_offset: f.absolute_byte_offset,
            byte_size: f.byte_size,
            bucket_scheme: scheme,
            thresholds: f.thresholds,
            bucket_count,
            high_watermark: f.high_watermark,
            shmem_base,
        });
        shmem_base += bucket_count;
    }
    fields
}

fn read_i32_from_state(buf: &[u8], offset: usize, size: usize) -> i32 {
    let end = offset + size;
    if end > buf.len() || size == 0 {
        return 0;
    }
    match size {
        1 => i8::from_le_bytes([buf[offset]]) as i32,
        2 => i16::from_le_bytes([buf[offset], buf[offset + 1]]) as i32,
        4 => i32::from_le_bytes([buf[offset], buf[offset + 1], buf[offset + 2], buf[offset + 3]]),
        _ => 0,
    }
}

fn compute_bucket(field: &StateHashField, value: i32) -> usize {
    let capped = value.max(0) as usize;
    match field.bucket_scheme {
        BucketScheme::Identity => field
            .thresholds
            .iter()
            .position(|&t| t == value)
            .unwrap_or(field.bucket_count - 1),
        BucketScheme::ThresholdFine | BucketScheme::RawCapped | BucketScheme::Binary => {
            capped.min(field.bucket_count - 1)
        }
        BucketScheme::ThresholdLog2 => {
            let n = field.thresholds.iter().filter(|&&t| value >= t).count();
            n.min(field.bucket_count - 1)
        }
    }
}

// ---------------------------------------------------------------------------
// Input field model and role
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
enum FieldRole {
    Inhibitor,
    Activator,
    Driver,
    Other,
}

#[derive(Debug, Clone)]
enum FieldValueModel {
    Bool,
    I16 { targets: Vec<i16> },
    Raw,
}

#[derive(Debug, Clone)]
struct InputField {
    name: String,
    offset: usize,
    size: usize,
    model: FieldValueModel,
    ddg_score: f32,
    role: FieldRole,
}

// ---------------------------------------------------------------------------
// DDG analysis helpers
// ---------------------------------------------------------------------------

fn build_ddg_distances(ddg: &Ddg) -> HashMap<u64, u32> {
    let sinks: Vec<u64> = ddg
        .nodes
        .iter()
        .filter(|n| n.has_dynamic_index)
        .map(|n| n.id)
        .collect();
    let mut rev_adj: HashMap<u64, Vec<u64>> = HashMap::new();
    for edge in &ddg.edges {
        rev_adj.entry(edge.to).or_default().push(edge.from);
    }
    let mut dist: HashMap<u64, u32> = HashMap::new();
    let mut queue: VecDeque<u64> = VecDeque::new();
    for &sink in &sinks {
        dist.insert(sink, 0);
        queue.push_back(sink);
    }
    while let Some(node_id) = queue.pop_front() {
        let d = dist[&node_id];
        if let Some(preds) = rev_adj.get(&node_id) {
            for &pred in preds {
                if !dist.contains_key(&pred) {
                    dist.insert(pred, d + 1);
                    queue.push_back(pred);
                }
            }
        }
    }
    dist
}

fn build_name_scores(ddg: &Ddg, dist: &HashMap<u64, u32>) -> HashMap<String, f32> {
    let mut name_score: HashMap<String, f32> = HashMap::new();
    for node in &ddg.nodes {
        if let Some(def) = &node.defines {
            let name = def.trim_start_matches('%').to_string();
            let score = dist
                .get(&node.id)
                .map(|&d| 1.0 / (1.0 + d as f32))
                .unwrap_or(0.0);
            let prev = name_score.entry(name).or_insert(0.0);
            if score > *prev {
                *prev = score;
            }
        }
    }
    name_score
}

fn parse_int_literals(s: &str) -> Vec<i32> {
    let mut out = Vec::new();
    let mut buf = String::new();
    for c in s.chars() {
        if c == '-' || c.is_ascii_digit() {
            buf.push(c);
        } else if !buf.is_empty() {
            if let Ok(v) = buf.parse::<i32>() {
                out.push(v);
            }
            buf.clear();
        }
    }
    if !buf.is_empty() {
        if let Ok(v) = buf.parse::<i32>() {
            out.push(v);
        }
    }
    out
}

fn infer_i16_targets_from_ddg(ddg: &Ddg, dist: &HashMap<u64, u32>) -> Vec<i16> {
    let mut set = BTreeSet::new();
    for node in &ddg.nodes {
        if !dist.contains_key(&node.id) {
            continue;
        }
        let ir = node.ir.to_ascii_lowercase();
        if !(ir.contains("icmp") || ir.contains("switch")) {
            continue;
        }
        for n in parse_int_literals(&node.ir) {
            if (i16::MIN as i32..=i16::MAX as i32).contains(&n) {
                let v = n as i16;
                set.insert(v);
                set.insert(v.saturating_add(1));
                set.insert(v.saturating_sub(1));
            }
        }
    }
    if set.is_empty() {
        for v in [0i16, 1, 2, 3, 4, 7, 15, 31, 50, 59, 60, 70, 71, 90, 100] {
            set.insert(v);
        }
    }
    set.into_iter().collect()
}

fn looks_boolish(name: &str, llvm_type: &str, size: usize) -> bool {
    if llvm_type.trim() != "i8" || size != 1 {
        return false;
    }
    let n = name.to_ascii_lowercase();
    n.starts_with("cmd")
        || n.contains("enable")
        || n.contains("start")
        || n.contains("reset")
        || n.contains("arm")
        || n.contains("trigger")
}

fn build_runtime_input_fields(
    layout: &ProgramLayout,
    frame_size: usize,
    name_scores: &HashMap<String, f32>,
    i16_targets: &[i16],
) -> Vec<InputField> {
    let mut type_by_name: HashMap<String, String> = HashMap::new();
    for field in &layout.fields {
        if let Some(name) = &field.name {
            type_by_name.insert(name.clone(), field.llvm_type.clone());
        }
    }
    let mut fields = Vec::new();
    let mut packed_offset = 0usize;
    let field_count = unsafe { prism_field_count() };
    for idx in 0..field_count {
        if unsafe { prism_field_is_input(idx) } != 1 {
            continue;
        }
        let name_ptr = unsafe { prism_field_name(idx) };
        if name_ptr.is_null() {
            continue;
        }
        let name = unsafe { CStr::from_ptr(name_ptr) }
            .to_string_lossy()
            .into_owned();
        let size = unsafe { prism_field_size(idx) };
        let offset = packed_offset;
        packed_offset = packed_offset.saturating_add(size);
        if offset + size > frame_size || size == 0 {
            continue;
        }
        let llvm_type = type_by_name
            .get(&name)
            .cloned()
            .unwrap_or_else(|| "i8".to_string());
        let model = if looks_boolish(&name, &llvm_type, size) {
            FieldValueModel::Bool
        } else if llvm_type.trim() == "i16" && size == 2 {
            FieldValueModel::I16 {
                targets: i16_targets.to_vec(),
            }
        } else {
            FieldValueModel::Raw
        };
        let ddg_score = name_scores.get(&name).copied().unwrap_or(0.0);
        fields.push(InputField {
            name,
            offset,
            size,
            model,
            ddg_score,
            role: FieldRole::Other,
        });
    }
    fields
}

// ---------------------------------------------------------------------------
// Weighted random helpers
// ---------------------------------------------------------------------------

struct WeightedIndex {
    cumulative: Vec<f32>,
}

impl WeightedIndex {
    fn new(weights: impl IntoIterator<Item = f32>) -> Self {
        let source: Vec<f32> = weights.into_iter().collect();
        let all_zero = source.iter().all(|v| *v <= 0.0);
        let mut cumulative = Vec::with_capacity(source.len());
        let mut sum = 0.0f32;
        for w in source {
            let effective = if all_zero { 1.0 } else { w.max(0.0001) };
            sum += effective;
            cumulative.push(sum);
        }
        Self { cumulative }
    }

    fn sample<R: Rand>(&self, rand: &mut R) -> Option<usize> {
        let total = self.cumulative.last().copied()?;
        let r = rand.next_float() as f32 * total;
        let idx = self.cumulative.partition_point(|&c| c < r);
        Some(idx.min(self.cumulative.len().saturating_sub(1)))
    }
}

fn pick_usize<R: Rand>(rand: &mut R, upper: usize) -> Option<usize> {
    if upper == 0 {
        return None;
    }
    Some((rand.next() as usize) % upper)
}

fn expand_weights_for_sequence(base_weights: &[f32], required_len: usize) -> Vec<f32> {
    if base_weights.is_empty() {
        return vec![1.0; required_len.max(1)];
    }
    if required_len <= base_weights.len() {
        return base_weights[..required_len].to_vec();
    }
    let mut out = Vec::with_capacity(required_len);
    while out.len() < required_len {
        let rem = required_len - out.len();
        let take = rem.min(base_weights.len());
        out.extend_from_slice(&base_weights[..take]);
    }
    out
}

// ---------------------------------------------------------------------------
// Mutators (unchanged from prism-ddg-state)
// ---------------------------------------------------------------------------

struct AccumulationWindowMutator {
    frame_size: usize,
    driver_fields: Vec<(usize, Vec<Vec<u8>>)>,
    #[allow(dead_code)]
    inhibitor_offsets: Vec<usize>,
    min_window: usize,
}

impl AccumulationWindowMutator {
    fn new(frame_size: usize, fields: &[InputField]) -> Self {
        let driver_fields = fields
            .iter()
            .filter(|f| f.role != FieldRole::Inhibitor)
            .filter_map(|f| match &f.model {
                FieldValueModel::I16 { targets } if !targets.is_empty() => {
                    let candidates: Vec<Vec<u8>> =
                        targets.iter().map(|&v| v.to_le_bytes().to_vec()).collect();
                    Some((f.offset, candidates))
                }
                FieldValueModel::Bool if f.role == FieldRole::Activator => {
                    Some((f.offset, vec![vec![1u8]]))
                }
                _ => None,
            })
            .collect();
        let inhibitor_offsets = fields
            .iter()
            .filter_map(|f| (f.role == FieldRole::Inhibitor).then_some(f.offset))
            .collect();
        Self { frame_size, driver_fields, inhibitor_offsets, min_window: 9 }
    }
}

impl Named for AccumulationWindowMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> = std::sync::OnceLock::new();
        N.get_or_init(|| std::borrow::Cow::Borrowed("AccumulationWindowMutator"))
    }
}

impl<S> Mutator<BytesInput, S> for AccumulationWindowMutator
where
    S: HasRand,
{
    fn mutate(&mut self, state: &mut S, input: &mut BytesInput) -> Result<MutationResult, Error> {
        if self.frame_size == 0 || self.driver_fields.is_empty() {
            return Ok(MutationResult::Skipped);
        }
        let bytes: &mut Vec<u8> = input.as_mut();
        let frame_count = bytes.len() / self.frame_size;
        if frame_count < self.min_window {
            return Ok(MutationResult::Skipped);
        }
        let mut good_frame = vec![0u8; self.frame_size];
        for (off, candidates) in &self.driver_fields {
            let Some(vi) = pick_usize(state.rand_mut(), candidates.len()) else { continue };
            let val = &candidates[vi];
            let write_len = val.len().min(self.frame_size.saturating_sub(*off));
            good_frame[*off..*off + write_len].copy_from_slice(&val[..write_len]);
        }
        let max_window = frame_count;
        let window_len = self.min_window
            + (state.rand_mut().next() as usize) % (max_window - self.min_window + 1);
        let Some(window_start) =
            pick_usize(state.rand_mut(), frame_count.saturating_sub(window_len) + 1)
        else {
            return Ok(MutationResult::Skipped);
        };
        let window_end = (window_start + window_len).min(frame_count);
        for f in window_start..window_end {
            let d_start = f * self.frame_size;
            bytes[d_start..d_start + self.frame_size].copy_from_slice(&good_frame);
        }
        Ok(MutationResult::Mutated)
    }

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

struct FieldValueMutator {
    frame_size: usize,
    fields: Vec<InputField>,
    picker: WeightedIndex,
}

impl FieldValueMutator {
    fn new(frame_size: usize, fields: Vec<InputField>) -> Self {
        let picker = WeightedIndex::new(fields.iter().map(|f| f.ddg_score));
        Self { frame_size, fields, picker }
    }
}

impl Named for FieldValueMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> = std::sync::OnceLock::new();
        N.get_or_init(|| std::borrow::Cow::Borrowed("FieldValueMutator"))
    }
}

impl<S> Mutator<BytesInput, S> for FieldValueMutator
where
    S: HasRand,
{
    fn mutate(&mut self, state: &mut S, input: &mut BytesInput) -> Result<MutationResult, Error> {
        if self.frame_size == 0 || self.fields.is_empty() {
            return Ok(MutationResult::Skipped);
        }
        let bytes: &mut Vec<u8> = input.as_mut();
        let frames = bytes.len() / self.frame_size;
        let Some(frame_idx) = pick_usize(state.rand_mut(), frames) else {
            return Ok(MutationResult::Skipped);
        };
        let Some(field_idx) = self.picker.sample(state.rand_mut()) else {
            return Ok(MutationResult::Skipped);
        };
        let field = &self.fields[field_idx];
        let start = frame_idx * self.frame_size + field.offset;
        let end = start + field.size;
        if end > bytes.len() {
            return Ok(MutationResult::Skipped);
        }
        match &field.model {
            FieldValueModel::Bool => {
                bytes[start] = (state.rand_mut().next() & 1) as u8;
            }
            FieldValueModel::I16 { targets } => {
                if field.size != 2 {
                    return Ok(MutationResult::Skipped);
                }
                let choose_target = (state.rand_mut().next() % 100) < 80 && !targets.is_empty();
                let value: i16 = if choose_target {
                    let Some(i) = pick_usize(state.rand_mut(), targets.len()) else {
                        return Ok(MutationResult::Skipped);
                    };
                    targets[i]
                } else {
                    state.rand_mut().next() as i16
                };
                let [lo, hi] = value.to_le_bytes();
                bytes[start] = lo;
                bytes[start + 1] = hi;
            }
            FieldValueModel::Raw => {
                for b in &mut bytes[start..end] {
                    *b = state.rand_mut().next() as u8;
                }
            }
        }
        Ok(MutationResult::Mutated)
    }

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

struct FramePatternMutator {
    frame_size: usize,
    activator_offsets: Vec<usize>,
    inhibitor_offsets: Vec<usize>,
}

impl FramePatternMutator {
    fn new(frame_size: usize, fields: &[InputField]) -> Self {
        let activator_offsets = fields
            .iter()
            .filter_map(|f| {
                if matches!(f.model, FieldValueModel::Bool) && f.role != FieldRole::Inhibitor {
                    Some(f.offset)
                } else {
                    None
                }
            })
            .collect();
        let inhibitor_offsets = fields
            .iter()
            .filter_map(|f| {
                if matches!(f.model, FieldValueModel::Bool) && f.role == FieldRole::Inhibitor {
                    Some(f.offset)
                } else {
                    None
                }
            })
            .collect();
        Self { frame_size, activator_offsets, inhibitor_offsets }
    }
}

impl Named for FramePatternMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> = std::sync::OnceLock::new();
        N.get_or_init(|| std::borrow::Cow::Borrowed("FramePatternMutator"))
    }
}

impl<S> Mutator<BytesInput, S> for FramePatternMutator
where
    S: HasRand,
{
    fn mutate(&mut self, state: &mut S, input: &mut BytesInput) -> Result<MutationResult, Error> {
        if self.frame_size == 0 {
            return Ok(MutationResult::Skipped);
        }
        let bytes: &mut Vec<u8> = input.as_mut();
        let frame_count = bytes.len() / self.frame_size;
        if frame_count < 2 {
            return Ok(MutationResult::Skipped);
        }
        let has_activators = !self.activator_offsets.is_empty();
        let has_inhibitors = !self.inhibitor_offsets.is_empty();
        let op_count = 1 + usize::from(has_activators) + usize::from(has_inhibitors);
        let op = (state.rand_mut().next() as usize) % op_count;
        match op {
            0 => {
                let Some(src) = pick_usize(state.rand_mut(), frame_count) else {
                    return Ok(MutationResult::Skipped);
                };
                let Some(dst) = pick_usize(state.rand_mut(), frame_count) else {
                    return Ok(MutationResult::Skipped);
                };
                let max_run = (frame_count - dst).min(8).max(1);
                let Some(run_len) = pick_usize(state.rand_mut(), max_run) else {
                    return Ok(MutationResult::Skipped);
                };
                let src_frame =
                    bytes[src * self.frame_size..src * self.frame_size + self.frame_size].to_vec();
                for i in 0..=run_len {
                    let d = dst + i;
                    if d >= frame_count {
                        break;
                    }
                    let d_start = d * self.frame_size;
                    bytes[d_start..d_start + self.frame_size].copy_from_slice(&src_frame);
                }
            }
            1 if has_activators => {
                let Some(oi) = pick_usize(state.rand_mut(), self.activator_offsets.len()) else {
                    return Ok(MutationResult::Skipped);
                };
                let off = self.activator_offsets[oi];
                let Some(pulse_frame) = pick_usize(state.rand_mut(), frame_count) else {
                    return Ok(MutationResult::Skipped);
                };
                let window_start = pulse_frame.saturating_sub(1);
                let window_end = (pulse_frame + 1).min(frame_count - 1);
                for f in window_start..=window_end {
                    bytes[f * self.frame_size + off] = 0;
                }
                bytes[pulse_frame * self.frame_size + off] = 1;
            }
            _ if has_inhibitors => {
                let Some(oi) = pick_usize(state.rand_mut(), self.inhibitor_offsets.len()) else {
                    return Ok(MutationResult::Skipped);
                };
                let off = self.inhibitor_offsets[oi];
                let min_window = 9usize.min(frame_count);
                let max_window = frame_count;
                let window_len = min_window
                    + (state.rand_mut().next() as usize) % (max_window - min_window + 1);
                let Some(window_start) =
                    pick_usize(state.rand_mut(), frame_count.saturating_sub(window_len) + 1)
                else {
                    return Ok(MutationResult::Skipped);
                };
                let window_end = (window_start + window_len).min(frame_count);
                for f in window_start..window_end {
                    bytes[f * self.frame_size + off] = 0;
                }
            }
            _ => return Ok(MutationResult::Skipped),
        }
        Ok(MutationResult::Mutated)
    }

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

struct InputRangeMutator {
    frame_size: usize,
    fields: Vec<(usize, usize, Vec<Vec<u8>>)>,
    picker: WeightedIndex,
}

impl InputRangeMutator {
    fn new(frame_size: usize, input_fields: &[InputField], byte_weights: &[f32]) -> Self {
        let mut fields = Vec::new();
        for field in input_fields {
            let candidates: Vec<Vec<u8>> = match &field.model {
                FieldValueModel::Bool => vec![vec![0u8], vec![1u8]],
                FieldValueModel::I16 { targets } => {
                    targets.iter().map(|&v| v.to_le_bytes().to_vec()).collect()
                }
                FieldValueModel::Raw => continue,
            };
            if !candidates.is_empty() {
                fields.push((field.offset, field.size, candidates));
            }
        }
        let weights: Vec<f32> = if byte_weights.len() == frame_size {
            byte_weights.to_vec()
        } else {
            vec![1.0; frame_size]
        };
        let field_weights: Vec<f32> = fields
            .iter()
            .map(|(off, sz, _)| {
                let start = *off;
                let end = (start + sz).min(weights.len());
                if start >= end { return 0.0; }
                let sum: f32 = weights[start..end].iter().copied().sum();
                (sum / (end - start) as f32).max(0.0)
            })
            .collect();
        let picker = WeightedIndex::new(field_weights);
        Self { frame_size, fields, picker }
    }
}

impl Named for InputRangeMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> = std::sync::OnceLock::new();
        N.get_or_init(|| std::borrow::Cow::Borrowed("InputRangeMutator"))
    }
}

impl<S> Mutator<BytesInput, S> for InputRangeMutator
where
    S: HasRand,
{
    fn mutate(&mut self, state: &mut S, input: &mut BytesInput) -> Result<MutationResult, Error> {
        let bytes: &mut Vec<u8> = input.as_mut();
        if bytes.is_empty() || self.fields.is_empty() {
            return Ok(MutationResult::Skipped);
        }
        let Some(fi) = self.picker.sample(state.rand_mut()) else {
            return Ok(MutationResult::Skipped);
        };
        let (offset, size, candidates) = &self.fields[fi];
        let frame_count = bytes.len() / self.frame_size;
        if frame_count == 0 {
            return Ok(MutationResult::Skipped);
        }
        let frame_idx = (state.rand_mut().next() as usize) % frame_count;
        let base = frame_idx * self.frame_size + offset;
        let Some(vi) = pick_usize(state.rand_mut(), candidates.len()) else {
            return Ok(MutationResult::Skipped);
        };
        let val = &candidates[vi];
        let write_len = val.len().min(*size).min(bytes.len().saturating_sub(base));
        bytes[base..base + write_len].copy_from_slice(&val[..write_len]);
        Ok(MutationResult::Mutated)
    }

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

struct DdgByteMutator {
    picker: WeightedIndex,
}

impl DdgByteMutator {
    fn new(weights: Vec<f32>) -> Self {
        Self { picker: WeightedIndex::new(weights) }
    }
}

impl Named for DdgByteMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> = std::sync::OnceLock::new();
        N.get_or_init(|| std::borrow::Cow::Borrowed("DdgByteMutator"))
    }
}

impl<S> Mutator<BytesInput, S> for DdgByteMutator
where
    S: HasRand,
{
    fn mutate(&mut self, state: &mut S, input: &mut BytesInput) -> Result<MutationResult, Error> {
        let bytes: &mut Vec<u8> = input.as_mut();
        if bytes.is_empty() {
            return Ok(MutationResult::Skipped);
        }
        let Some(idx) = self.picker.sample(state.rand_mut()) else {
            return Ok(MutationResult::Skipped);
        };
        if idx >= bytes.len() {
            return Ok(MutationResult::Skipped);
        }
        let new_val = state.rand_mut().next() as u8;
        bytes[idx] = if bytes[idx] == new_val { new_val.wrapping_add(1) } else { new_val };
        Ok(MutationResult::Mutated)
    }

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Zone-aware frame generation
// ---------------------------------------------------------------------------

fn rand_i16_in(rng: &mut impl Rand, lo: i16, hi: i16) -> i16 {
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
///
/// For each input field per frame:
///   - Inhibitors: zeroed (all `size` bytes, not just one).
///   - In `field_constraints`: sampled uniformly from [lo, hi].
///   - I16 with target values: sampled from target list (80%) or uniform (20%).
///   - Bool: random 0/1.
///   - Otherwise: left as 0.
///
/// `field_constraints` is the zone's generic map (field name → [lo, hi]).
/// Passing an empty map is valid — it triggers pure target-value-guided generation,
/// which is the correct fallback when no zone config is available.
fn generate_zone_frames(
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
            if field.offset >= frame_size || field.size == 0 {
                continue;
            }
            let end = (field.offset + field.size).min(frame_size);

            if field.role == FieldRole::Inhibitor {
                // Zero all bytes of the inhibitor (not just byte 0).
                for b in &mut frame[field.offset..end] {
                    *b = 0;
                }
            } else if let Some(range) = field_constraints.get(&field.name) {
                // Zone-specific constraint: sample from [lo, hi].
                if field.size == 2 {
                    write_i16_le(frame, field.offset, rand_i16_in(rng, range.lo, range.hi));
                } else if field.size == 1 {
                    let v = rand_i16_in(rng, range.lo.max(0), range.hi.max(0)) as u8;
                    frame[field.offset] = v;
                }
            } else {
                // No zone constraint: fall back to sampling from target_values.
                match &field.model {
                    FieldValueModel::I16 { targets } if !targets.is_empty() => {
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
                    FieldValueModel::Bool => {
                        frame[field.offset] = (rng.next() & 1) as u8;
                    }
                    _ => {} // Raw / unknown: leave 0
                }
            }
        }
    }

    out
}

// ---------------------------------------------------------------------------
// Checkpoint burst: fork, run zone frames from checkpoint, detect crash.
// ---------------------------------------------------------------------------

/// Restore PLC state from `snapshot` then run `rollout_frames` zone-appropriate
/// input frames in a forked child. The child tracks its FillHead peak and writes
/// it back via CHECKPOINT_MAP_PTR so the parent can record new checkpoint advances.
/// If the child dies by signal, save the frames as a crash artifact and exit.
fn checkpoint_burst(
    bucket: usize,
    snapshot: &[u8],
    zone_config: Option<&ZoneConstraintsConfig>,
    input_fields: &[InputField],
    frame_size: usize,
    rollout_frames: usize,
    crashes_dir: &Path,
    struct_size: usize,
    fillhead_info: Option<(usize, usize)>,
    checkpoint_table: &mut Vec<Option<Vec<u8>>>,
) {
    if frame_size == 0 || rollout_frames == 0 || snapshot.len() < struct_size {
        return;
    }

    // Unique seed per burst so consecutive bursts explore different inputs.
    static BURST_COUNTER: std::sync::atomic::AtomicU64 =
        std::sync::atomic::AtomicU64::new(0);
    let burst_id = BURST_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0x1337)
        ^ (bucket as u64).wrapping_mul(0x9e3779b9)
        ^ burst_id.wrapping_mul(0x517c_c1b7_2722_0a95);
    let mut rng = StdRand::with_seed(seed);

    // Resolve zone-specific field constraints: look up which zone the current
    // bucket falls in, then use its field_constraints map.  If no zone config
    // is present we pass an empty map, which causes generate_zone_frames to fall
    // back to target_value sampling (DDG-guided, not pure random).
    let empty_constraints: HashMap<String, FieldRange> = HashMap::new();
    let field_constraints: &HashMap<String, FieldRange> = if let Some(zc) = zone_config {
        // Find the zone whose [fillhead_lo, fillhead_hi) contains this bucket.
        let zone = zc
            .zones
            .iter()
            .find(|z| bucket as i32 >= z.fillhead_lo && (bucket as i32) < z.fillhead_hi)
            .or_else(|| zc.zones.last())
            .unwrap();
        &zone.field_constraints
    } else {
        &empty_constraints
    };

    let frames = generate_zone_frames(
        field_constraints,
        input_fields,
        frame_size,
        rollout_frames,
        &mut rng,
    );

    // Reset the checkpoint flag before forking so a stale value from the last
    // fuzz_one can't be mistaken for the burst child's result.
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
        // Child: null coverage maps to avoid corrupting LibAFL's shmem, but keep
        // CHECKPOINT_MAP_PTR live so we can report the burst's FillHead peak back.
        unsafe {
            COV_MAP_PTR = std::ptr::null_mut();
            STATE_MAP_PTR = std::ptr::null_mut();
        }

        let mut burst_fillhead_max = -1i32;
        let mut burst_best_snap = vec![0u8; struct_size];

        execute_testcase_from_checkpoint(snapshot, &frames, frame_size, &mut |snap| {
            if let Some((off, sz)) = fillhead_info {
                let v = read_i32_from_state(snap, off, sz);
                if v > burst_fillhead_max {
                    burst_fillhead_max = v;
                    let n = snap.len().min(burst_best_snap.len());
                    burst_best_snap[..n].copy_from_slice(&snap[..n]);
                }
            }
        });

        // Write the burst's FillHead peak via checkpoint shmem so the parent can
        // record any advance. Only write if we observed positive FillHead.
        if burst_fillhead_max > 0 {
            unsafe {
                if !CHECKPOINT_MAP_PTR.is_null() {
                    *CHECKPOINT_MAP_PTR = 1;
                    // Clamp to u8::MAX; parent validates against checkpoint_table.len().
                    *CHECKPOINT_MAP_PTR.add(1) = burst_fillhead_max.min(u8::MAX as i32) as u8;
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

    // Parent: wait for child, then read any burst checkpoint advance before
    // checking crash so we don't miss advances from a crashing burst.
    let mut status: libc::c_int = 0;
    unsafe { libc::waitpid(child, &mut status, 0) };

    if unsafe { !CHECKPOINT_MAP_PTR.is_null() && *CHECKPOINT_MAP_PTR == 1 } {
        let burst_bucket = unsafe { *CHECKPOINT_MAP_PTR.add(1) } as usize;
        // Only record a genuine advance beyond the starting checkpoint.
        if burst_bucket < checkpoint_table.len() && burst_bucket > bucket && checkpoint_table[burst_bucket].is_none() {
            let mut snap = vec![0u8; struct_size];
            unsafe {
                std::ptr::copy_nonoverlapping(
                    CHECKPOINT_MAP_PTR.add(CHECKPOINT_HDR),
                    snap.as_mut_ptr(),
                    struct_size,
                );
            }
            checkpoint_table[burst_bucket] = Some(snap);
            eprintln!("[goexplore] burst advance: bucket {bucket} → {burst_bucket}");
        }
    }

    if libc::WIFSIGNALED(status) {
        let sig = libc::WTERMSIG(status);
        eprintln!("[goexplore] CRASH from burst at FillHead bucket={bucket} signal={sig}");
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

    // Zone constraints config (optional — enables checkpoint tracking + zone bursts).
    let zone_config: Option<ZoneConstraintsConfig> = args.zone_constraints.as_ref().map(|p| {
        let raw = std::fs::read_to_string(p)
            .unwrap_or_else(|e| panic!("Cannot read zone constraints {:?}: {e}", p));
        serde_json::from_str(&raw)
            .unwrap_or_else(|e| panic!("Cannot parse zone constraints JSON: {e}"))
    });

    // FillHead tracking: (absolute_byte_offset, byte_size) within the struct snapshot.
    let fillhead_info: Option<(usize, usize)> = zone_config
        .as_ref()
        .map(|zc| (zc.fillhead_byte_offset, zc.fillhead_byte_size));

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

            let mut bw = wj.byte_weights.clone();
            bw.resize(frame_size, 0.0);
            bw.truncate(frame_size);

            let json_fields: Vec<InputField> = wj
                .input_fields
                .into_iter()
                .map(|g| {
                    let model = match g.model.as_str() {
                        "bool" => FieldValueModel::Bool,
                        "range_i16" => FieldValueModel::I16 {
                            targets: g.target_values.iter().map(|&v| v as i16).collect(),
                        },
                        _ => FieldValueModel::Raw,
                    };
                    let role = if g.roles.iter().any(|r| r == "inhibitor") {
                        FieldRole::Inhibitor
                    } else if g.roles.iter().any(|r| r == "activator") {
                        FieldRole::Activator
                    } else if g.roles.iter().any(|r| r == "driver") {
                        FieldRole::Driver
                    } else {
                        FieldRole::Other
                    };
                    InputField {
                        name: g.name,
                        offset: g.byte_offset,
                        size: g.byte_size,
                        model,
                        ddg_score: 0.5,
                        role,
                    }
                })
                .collect();

            (bw, json_fields, "weights JSON")
        } else {
            let mut bw = vec![0.0f32; frame_size];
            for f in &ddg_input_fields {
                let score = if f.ddg_score > 0.0 { f.ddg_score } else { 0.05 };
                let end = (f.offset + f.size).min(frame_size);
                for w in &mut bw[f.offset..end] {
                    *w = score;
                }
            }
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
            "[prism-go-explore] Zone config  : {} zones, FillHead@off={}",
            zc.zones.len(),
            zc.fillhead_byte_offset
        );
    } else {
        println!("[prism-go-explore] Zone config  : none (checkpoint bursts disabled)");
    }
    println!("[prism-go-explore] Input fields : {}", runtime_input_fields.len());
    for f in &runtime_input_fields {
        let role_tag = match f.role {
            FieldRole::Inhibitor => " [inhibitor]",
            FieldRole::Activator => " [activator]",
            FieldRole::Driver => " [driver]",
            FieldRole::Other => "",
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

    // Coverage shmem.
    let mut cov_shmem = shmem_provider.new_shmem(COV_MAP_SIZE).unwrap();
    let cov_ptr = cov_shmem.as_slice_mut().as_mut_ptr();
    unsafe { COV_MAP_PTR = cov_ptr };
    let cov_observer = HitcountsMapObserver::new(unsafe {
        StdMapObserver::from_mut_ptr("edges", cov_ptr, COV_MAP_SIZE)
    });

    // State-hash shmem.
    let mut state_shmem = shmem_provider.new_shmem(STATE_MAP_SIZE).unwrap();
    let state_ptr = state_shmem.as_slice_mut().as_mut_ptr();
    unsafe { STATE_MAP_PTR = state_ptr };
    let state_observer =
        unsafe { StdMapObserver::from_mut_ptr("state_hash", state_ptr, STATE_MAP_SIZE) };

    // Checkpoint shmem: [flag: u8][fillhead_bucket: u8][snapshot: struct_size bytes].
    // Created before shmem_provider is moved into InProcessForkExecutor.
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
    // Harness: state hash + FillHead checkpoint tracking.
    // -----------------------------------------------------------------------

    let config = loaded.config.clone();
    let sf = state_fields;

    let mut harness = move |input: &BytesInput| {
        // Reset checkpoint flag so stale data from the previous run is ignored.
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
        // Track FillHead high-watermark and save the snapshot at the peak cycle.
        let mut fillhead_max = -1i32;
        let mut best_snap = vec![0u8; struct_size];

        let executed = execute_testcase_with_state_snapshots(
            &config,
            data,
            frame_size,
            &mut |snap: &[u8]| {
                // State hash feedback.
                for (i, field) in sf.iter().enumerate() {
                    let val =
                        read_i32_from_state(snap, field.absolute_byte_offset, field.byte_size);
                    if field.high_watermark {
                        hwm[i] = hwm[i].max(val);
                    } else {
                        hwm[i] = val;
                    }
                }
                // FillHead checkpoint tracking.
                if let Some((off, sz)) = fillhead_info {
                    let v = read_i32_from_state(snap, off, sz);
                    if v > fillhead_max {
                        fillhead_max = v;
                        let n = snap.len().min(best_snap.len());
                        best_snap[..n].copy_from_slice(&snap[..n]);
                    }
                }
            },
        );

        // Write state hash shmem.
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

        // Write checkpoint shmem only when FillHead actually advanced above zero.
        // fillhead_max == 0 means the program ran but FillHead never accumulated
        // (idle/INIT phase) — that snapshot is useless as a checkpoint starting point.
        if executed && fillhead_max > 0 {
            unsafe {
                if !CHECKPOINT_MAP_PTR.is_null() {
                    *CHECKPOINT_MAP_PTR = 1; // flag: new checkpoint available
                    *CHECKPOINT_MAP_PTR.add(1) = fillhead_max.max(0).min(u8::MAX as i32) as u8;
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
    // Custom fuzz loop: fuzz_one in bursts, then run checkpoint exploration.
    // -----------------------------------------------------------------------

    // Checkpoint table: one slot per FillHead value from 0 to max_fillhead.
    // Size is derived from zone config's max_fillhead so it works for any program.
    let max_fillhead: usize = zone_config
        .as_ref()
        .map(|zc| zc.max_fillhead as usize)
        .unwrap_or(255);
    let chk_table_len = max_fillhead + 1;
    let mut checkpoint_table: Vec<Option<Vec<u8>>> = vec![None; chk_table_len];

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

    loop {
        // Phase 1: standard mutation-guided fuzzing for burst_size iterations.
        for _ in 0..burst_size {
            fuzzer
                .fuzz_one(&mut stages, &mut executor, &mut state, &mut mgr)
                .unwrap();
            total_fuzz_iters += 1;

            // Check if the child wrote a new checkpoint into shmem.
            if !chk_ptr.is_null() && unsafe { *chk_ptr } == 1 {
                let bucket = unsafe { *chk_ptr.add(1) } as usize;
                if bucket < chk_table_len && checkpoint_table[bucket].is_none() {
                    let mut snap = vec![0u8; struct_size];
                    unsafe {
                        std::ptr::copy_nonoverlapping(
                            chk_ptr.add(CHECKPOINT_HDR),
                            snap.as_mut_ptr(),
                            struct_size,
                        );
                    }
                    checkpoint_table[bucket] = Some(snap);
                    let n_chk = checkpoint_table.iter().filter(|s| s.is_some()).count();
                    let best = checkpoint_table
                        .iter()
                        .enumerate()
                        .rfind(|(_, s)| s.is_some())
                        .map(|(i, _)| i)
                        .unwrap_or(0);
                    eprintln!(
                        "[goexplore] NEW checkpoint: bucket={bucket} | total_checkpoints={n_chk} | best_bucket={best}"
                    );
                }
            }
        }

        // Heartbeat: print fuzzing progress every 30 seconds.
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

        // Phase 2: burst from checkpoints according to the chosen strategy.
        match checkpoint_strategy {
            CheckpointStrategy::Best => {
                // Burst burst_repeats times from the single highest filled checkpoint.
                let best_bucket = checkpoint_table
                    .iter()
                    .enumerate()
                    .rfind(|(_, s)| s.is_some())
                    .map(|(i, _)| i);
                if let Some(bucket) = best_bucket {
                    if let Some(snap) = checkpoint_table[bucket].clone() {
                        for _ in 0..burst_repeats {
                            total_bursts += 1;
                            checkpoint_burst(
                                bucket, &snap, zone_cfg.as_ref(), &burst_fields,
                                frame_size, rollout_frames, &crashes_dir,
                                struct_size, fillhead_info, &mut checkpoint_table,
                            );
                        }
                    }
                }
            }
            CheckpointStrategy::RoundRobin => {
                // Distribute burst_repeats evenly across all filled checkpoints,
                // highest to lowest, so intermediate states are also explored.
                let filled: Vec<(usize, Vec<u8>)> = checkpoint_table
                    .iter()
                    .enumerate()
                    .filter_map(|(i, s)| s.clone().map(|snap| (i, snap)))
                    .rev()
                    .collect();
                if !filled.is_empty() {
                    let per_bucket = (burst_repeats / filled.len()).max(1);
                    for (bucket, snap) in &filled {
                        for _ in 0..per_bucket {
                            total_bursts += 1;
                            checkpoint_burst(
                                *bucket, snap, zone_cfg.as_ref(), &burst_fields,
                                frame_size, rollout_frames, &crashes_dir,
                                struct_size, fillhead_info, &mut checkpoint_table,
                            );
                        }
                    }
                }
            }
        }
    }
}
