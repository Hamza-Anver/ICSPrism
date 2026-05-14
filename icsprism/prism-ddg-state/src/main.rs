use std::{
    collections::{BTreeSet, HashMap, VecDeque},
    ffi::CStr,
    fs::File,
    os::raw::c_char,
    path::PathBuf,
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
    execute_testcase_with_state_snapshots, harness_dimensions, load_config, required_input_len,
};
use serde::Deserialize;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Branch-coverage bitmap size (bytes). Must match __sanitizer_cov callback logic.
const COV_MAP_SIZE: usize = 65536;
/// Dedicated state-hash bitmap size (bytes). 1024 slots handles ≥10k macro-states.
const STATE_MAP_SIZE: usize = 1024;
/// Heartbeat interval for periodic state dumps.
const STATE_HEARTBEAT_INTERVAL_SECS: u64 = 5;

static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();
static mut STATE_MAP_PTR: *mut u8 = std::ptr::null_mut();

// ---------------------------------------------------------------------------
// SanitizerCoverage callbacks (edge coverage signal)
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
    name = "prism-ddg-state",
    about = "DDG-guided ST fuzzer with state-hash secondary coverage"
)]
struct Args {
    #[arg(long)]
    ddg: PathBuf,

    #[arg(long)]
    layout: PathBuf,

    /// Byte weights + input field guide from probe_ddg_adv.py (optional).
    #[arg(long)]
    weights_json: Option<PathBuf>,

    /// State hash config from ddg_state_hash_heuristics.py (optional).
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
// DDG deserialization (used for fallback weight / target analysis)
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
    /// Switch discriminant: map value to its index in sorted thresholds list.
    Identity,
    /// Accumulator with small threshold: bucket = min(value, bucket_count-1).
    ThresholdFine,
    /// Accumulator with large threshold: count how many log2 boundaries value exceeds.
    ThresholdLog2,
    /// Array index used as danger sink: bucket = min(value, bound).
    RawCapped,
    /// Fallback: 0 or 1.
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
    /// Index into the state shmem where this field's buckets begin.
    shmem_base: usize,
}

fn parse_state_hash_config(raw: StateHashConfigRaw) -> Vec<StateHashField> {
    let mut fields = Vec::new();
    let mut shmem_base = 0usize;
    for f in raw.fields {
        if shmem_base >= STATE_MAP_SIZE {
            eprintln!("[prism-ddg-state] WARNING: state shmem full, skipping field {}", f.name);
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

/// Read a signed integer from a state snapshot buffer at the given offset.
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

/// Map a signed field value to its bucket index.
fn compute_bucket(field: &StateHashField, value: i32) -> usize {
    let capped = value.max(0) as usize;
    match field.bucket_scheme {
        BucketScheme::Identity => {
            // Find the position of value in the sorted thresholds list.
            field
                .thresholds
                .iter()
                .position(|&t| t == value)
                .unwrap_or(field.bucket_count - 1)
        }
        BucketScheme::ThresholdFine | BucketScheme::RawCapped | BucketScheme::Binary => {
            capped.min(field.bucket_count - 1)
        }
        BucketScheme::ThresholdLog2 => {
            // Count how many boundaries the value is >= to.
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
    Inhibitor, // must stay 0 for accumulation to proceed (e.g. CmdReset)
    Activator, // pulse to trigger state transitions (e.g. CmdArm, CmdStart)
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
// DDG analysis helpers (fallback path when --weights-json is absent)
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
// Mutators
// ---------------------------------------------------------------------------

/// Picks a field by DDG score and writes a semantically-appropriate value.
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
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
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

    fn post_exec(
        &mut self,
        _state: &mut S,
        _new_corpus_id: Option<CorpusId>,
    ) -> Result<(), Error> {
        Ok(())
    }
}

/// Frame-level pattern operations with role-aware bool field handling.
///
/// Bug fix vs prism-ddg-not-dumb: inhibitor fields (CmdReset) are never pulsed
/// to 1 — they only get a zero-window operation that clears them across ≥9 frames,
/// which is what the accumulation chain needs. Activator fields (CmdArm, CmdStart)
/// get the pulse treatment.
struct FramePatternMutator {
    frame_size: usize,
    /// Bool fields that trigger useful state transitions (safe to pulse high).
    activator_offsets: Vec<usize>,
    /// Bool fields that, when high, undo accumulation (keep low; zero-window only).
    inhibitor_offsets: Vec<usize>,
}

impl FramePatternMutator {
    fn new(frame_size: usize, fields: &[InputField]) -> Self {
        let activator_offsets = fields
            .iter()
            .filter_map(|f| {
                if matches!(f.model, FieldValueModel::Bool)
                    && f.role != FieldRole::Inhibitor
                {
                    Some(f.offset)
                } else {
                    None
                }
            })
            .collect();
        let inhibitor_offsets = fields
            .iter()
            .filter_map(|f| {
                if matches!(f.model, FieldValueModel::Bool)
                    && f.role == FieldRole::Inhibitor
                {
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
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
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
                // Frame copy: stamp a source frame across a short run of destination frames.
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
                let src_frame = bytes[src * self.frame_size..src * self.frame_size + self.frame_size].to_vec();
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
                // Activator pulse: set a non-inhibitor bool field to 1 in one frame,
                // surrounded by zeros so it reads as a clean edge transition.
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
                // Inhibitor zero-window: hold an inhibitor field at 0 across a long
                // contiguous window so accumulation can proceed uninterrupted.
                // Window length ≥ 9 to cover the minimum accumulation chain depth.
                let Some(oi) = pick_usize(state.rand_mut(), self.inhibitor_offsets.len()) else {
                    return Ok(MutationResult::Skipped);
                };
                let off = self.inhibitor_offsets[oi];
                let min_window = 9usize.min(frame_count);
                let max_window = frame_count;
                let window_len = min_window + (state.rand_mut().next() as usize) % (max_window - min_window + 1);
                let Some(window_start) = pick_usize(state.rand_mut(), frame_count.saturating_sub(window_len) + 1) else {
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

    fn post_exec(
        &mut self,
        _state: &mut S,
        _new_corpus_id: Option<CorpusId>,
    ) -> Result<(), Error> {
        Ok(())
    }
}

/// Writes a complete field value (all bytes atomically) chosen from the target-value list.
struct InputRangeMutator {
    frame_size: usize,
    fields: Vec<(usize, usize, Vec<Vec<u8>>)>, // (offset, size, candidates)
    picker: WeightedIndex,
}

impl InputRangeMutator {
    fn new(frame_size: usize, input_fields: &[InputField], byte_weights: &[f32]) -> Self {
        let mut fields = Vec::new();
        for field in input_fields {
            let candidates: Vec<Vec<u8>> = match &field.model {
                FieldValueModel::Bool => vec![vec![0u8], vec![1u8]],
                FieldValueModel::I16 { targets } => targets
                    .iter()
                    .map(|&v| v.to_le_bytes().to_vec())
                    .collect(),
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
                if start >= end {
                    return 0.0;
                }
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
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
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

    fn post_exec(
        &mut self,
        _state: &mut S,
        _new_corpus_id: Option<CorpusId>,
    ) -> Result<(), Error> {
        Ok(())
    }
}

/// Single-byte random flip weighted by DDG proximity to sinks.
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
        static N: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
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
        bytes[idx] = if bytes[idx] == new_val {
            new_val.wrapping_add(1)
        } else {
            new_val
        };
        Ok(MutationResult::Mutated)
    }

    fn post_exec(
        &mut self,
        _state: &mut S,
        _new_corpus_id: Option<CorpusId>,
    ) -> Result<(), Error> {
        Ok(())
    }
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
    // The last layout entry is the top-level PROGRAM (PLC_PRG).
    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    // Load state hash config (optional).
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

    // DDG analysis for fallback weights and target inference.
    let dist = build_ddg_distances(&ddg);
    let name_scores = build_name_scores(&ddg, &dist);
    let i16_targets = infer_i16_targets_from_ddg(&ddg, &dist);
    let ddg_input_fields =
        build_runtime_input_fields(&layout, frame_size, &name_scores, &i16_targets);

    // If weights JSON is provided, use it; otherwise fall back to DDG analysis.
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
            FieldRole::Other => "",
        };
        println!(
            "[prism-ddg-state]   {:20} off={:>2} size={:>2} score={:.3}{}",
            f.name, f.offset, f.size, f.ddg_score, role_tag
        );
    }

    // -----------------------------------------------------------------------
    // LibAFL setup: two shmem regions, two observers, combined feedback.
    // -----------------------------------------------------------------------

    let mut shmem_provider = UnixShMemProvider::new().unwrap();

    // Coverage shmem (edge bitmap).
    let mut cov_shmem = shmem_provider.new_shmem(COV_MAP_SIZE).unwrap();
    let cov_ptr = cov_shmem.as_slice_mut().as_mut_ptr();
    unsafe { COV_MAP_PTR = cov_ptr };
    let cov_observer = HitcountsMapObserver::new(unsafe {
        StdMapObserver::from_mut_ptr("edges", cov_ptr, COV_MAP_SIZE)
    });

    // State-hash shmem (one slot per field bucket).
    let mut state_shmem = shmem_provider.new_shmem(STATE_MAP_SIZE).unwrap();
    let state_ptr = state_shmem.as_slice_mut().as_mut_ptr();
    unsafe { STATE_MAP_PTR = state_ptr };
    let state_observer = unsafe {
        StdMapObserver::from_mut_ptr("state_hash", state_ptr, STATE_MAP_SIZE)
    };

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
    // Harness: run testcase, track state, write state-hash shmem.
    // -----------------------------------------------------------------------

    let config = loaded.config.clone();
    let sf = state_fields; // move into closure

    let mut harness = move |input: &BytesInput| {
        let bytes = input.target_bytes();
        let data: &[u8] = bytes.as_ref();
        if data.len() < required_len {
            return ExitKind::Ok;
        }

        // High-watermark accumulators, one per state field. i32::MIN means "not seen".
        let mut hwm = vec![i32::MIN; sf.len()];

        let executed = execute_testcase_with_state_snapshots(
            &config,
            data,
            frame_size,
            &mut |snap: &[u8]| {
                for (i, field) in sf.iter().enumerate() {
                    let val = read_i32_from_state(snap, field.absolute_byte_offset, field.byte_size);
                    if field.high_watermark {
                        hwm[i] = hwm[i].max(val);
                    } else {
                        // Non-hwm fields (e.g. Mode): track the current (final) value.
                        hwm[i] = val;
                    }
                }
            },
        );

        if executed && !sf.is_empty() {
            for (i, field) in sf.iter().enumerate() {
                if hwm[i] == i32::MIN {
                    continue; // field was never read (execution skipped somehow)
                }
                let bucket = compute_bucket(field, hwm[i]);
                let slot = field.shmem_base + bucket;
                if slot < STATE_MAP_SIZE {
                    // Write 1 (not accumulate): pre_exec resets the map to 0 before each
                    // testcase, so a new 1 here means "first testcase to reach this bucket".
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
    // Seed corpus and start fuzzing.
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

    println!("[prism-ddg-state] Fuzzing — Ctrl+C to stop");
    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
