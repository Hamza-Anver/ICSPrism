use std::collections::{BTreeSet, HashMap, VecDeque};

use libafl::{
    Error,
    corpus::CorpusId,
    inputs::BytesInput,
    mutators::{MutationResult, Mutator},
    state::HasRand,
};
use libafl_bolts::{Named, rands::Rand};
use serde::Deserialize;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

pub const COV_MAP_SIZE: usize = 65536;
pub const STATE_MAP_SIZE: usize = 1024;

// ---------------------------------------------------------------------------
// DDG deserialization types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct DdgNode {
    pub id: u64,
    pub defines: Option<String>,
    pub ir: String,
    pub has_dynamic_index: bool,
}

#[derive(Debug, Deserialize)]
pub struct DdgEdge {
    pub from: u64,
    pub to: u64,
}

#[derive(Debug, Deserialize)]
pub struct Ddg {
    pub nodes: Vec<DdgNode>,
    pub edges: Vec<DdgEdge>,
}

// ---------------------------------------------------------------------------
// Layout deserialization types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize, Clone)]
pub struct FieldLayout {
    pub name: Option<String>,
    pub llvm_type: String,
    #[serde(default)]
    pub byte_size: u64,
    #[serde(default)]
    pub byte_offset: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ProgramLayout {
    pub struct_name: String,
    pub total_bytes: u64,
    pub fields: Vec<FieldLayout>,
}

// ---------------------------------------------------------------------------
// Weights JSON deserialization types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct InputFieldGuide {
    pub name: String,
    #[allow(dead_code)]
    pub llvm_type: String,
    pub byte_size: usize,
    pub byte_offset: usize,
    pub model: String,
    pub roles: Vec<String>,
    #[serde(default)]
    pub target_values: Vec<i64>,
}

#[derive(Debug, Deserialize)]
pub struct WeightsJson {
    #[allow(dead_code)]
    pub main_function: String,
    #[allow(dead_code)]
    pub frame_size: usize,
    pub input_fields: Vec<InputFieldGuide>,
    pub byte_weights: Vec<f32>,
}

// ---------------------------------------------------------------------------
// State hash deserialization types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct StateHashFieldRaw {
    pub name: String,
    pub absolute_byte_offset: usize,
    pub byte_size: usize,
    pub bucket_scheme: String,
    pub thresholds: Vec<i32>,
    pub bucket_count: usize,
    pub high_watermark: bool,
}

#[derive(Debug, Deserialize)]
pub struct StateHashConfigRaw {
    #[allow(dead_code)]
    pub program: String,
    #[allow(dead_code)]
    pub total_macro_states: u64,
    pub fields: Vec<StateHashFieldRaw>,
}

#[derive(Debug, Clone)]
pub enum BucketScheme {
    Identity,
    ThresholdFine,
    ThresholdLog2,
    RawCapped,
    Binary,
}

#[derive(Debug, Clone)]
pub struct StateHashField {
    pub name: String,
    pub absolute_byte_offset: usize,
    pub byte_size: usize,
    pub bucket_scheme: BucketScheme,
    pub thresholds: Vec<i32>,
    pub bucket_count: usize,
    pub high_watermark: bool,
    pub shmem_base: usize,
}

pub fn parse_state_hash_config(raw: StateHashConfigRaw) -> Vec<StateHashField> {
    let mut fields = Vec::new();
    let mut shmem_base = 0usize;
    for f in raw.fields {
        if shmem_base >= STATE_MAP_SIZE {
            eprintln!("[prism] WARNING: state shmem full ({STATE_MAP_SIZE} bytes), skipping {}", f.name);
            break;
        }
        let bucket_count = f.bucket_count.max(1).min(STATE_MAP_SIZE - shmem_base);
        let scheme = match f.bucket_scheme.as_str() {
            "identity"        => BucketScheme::Identity,
            "threshold_fine"  => BucketScheme::ThresholdFine,
            "threshold_log2"  => BucketScheme::ThresholdLog2,
            "raw_capped"      => BucketScheme::RawCapped,
            _                 => BucketScheme::Binary,
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

pub fn read_i32_from_state(buf: &[u8], offset: usize, size: usize) -> i32 {
    let end = offset + size;
    if end > buf.len() || size == 0 {
        return 0;
    }
    match size {
        1 => i8::from_le_bytes([buf[offset]]) as i32,
        2 => i16::from_le_bytes([buf[offset], buf[offset + 1]]) as i32,
        4 => i32::from_le_bytes([
            buf[offset], buf[offset + 1], buf[offset + 2], buf[offset + 3],
        ]),
        _ => 0,
    }
}

pub fn compute_bucket(field: &StateHashField, value: i32) -> usize {
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

// Sub-accumulator field: a state variable that gates the discriminant's increment.
// Shared here because snapshot_quality uses it and go-explore deserializes it from
// zone_constraints.json.
#[derive(Debug, Clone, Deserialize)]
pub struct SubAccumulatorField {
    #[allow(dead_code)]
    pub name: String,
    pub byte_offset: usize,
    pub byte_size: usize,
}

/// Score a struct snapshot — higher means the state is better positioned to
/// advance the discriminant.  When sub-accumulator fields are known, sums their
/// values; otherwise falls back to summing high-watermark state-hash fields
/// (excluding the discriminant field at `discriminant_offset`).
pub fn snapshot_quality(
    snap: &[u8],
    sub_accum: &[SubAccumulatorField],
    state_fields: &[StateHashField],
    discriminant_offset: usize,
) -> u32 {
    if !sub_accum.is_empty() {
        return sub_accum
            .iter()
            .map(|f| read_i32_from_state(snap, f.byte_offset, f.byte_size).max(0) as u32)
            .sum();
    }
    state_fields
        .iter()
        .filter(|f| f.high_watermark && f.absolute_byte_offset != discriminant_offset)
        .map(|f| read_i32_from_state(snap, f.absolute_byte_offset, f.byte_size).max(0) as u32)
        .sum()
}

// ---------------------------------------------------------------------------
// Input field model and role
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FieldRole {
    Inhibitor,
    Activator,
    Driver,
    Other,
}

#[derive(Debug, Clone)]
pub enum FieldValueModel {
    Bool,
    I16 { targets: Vec<i16> },
    Raw,
}

#[derive(Debug, Clone)]
pub struct InputField {
    pub name: String,
    pub offset: usize,
    pub size: usize,
    pub model: FieldValueModel,
    pub ddg_score: f32,
    pub role: FieldRole,
}

// ---------------------------------------------------------------------------
// DDG analysis helpers (used for the fallback path when --weights-json is absent)
// ---------------------------------------------------------------------------

pub fn build_ddg_distances(ddg: &Ddg) -> HashMap<u64, u32> {
    let sinks: Vec<u64> = ddg.nodes.iter().filter(|n| n.has_dynamic_index).map(|n| n.id).collect();
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

pub fn build_name_scores(ddg: &Ddg, dist: &HashMap<u64, u32>) -> HashMap<String, f32> {
    let mut name_score: HashMap<String, f32> = HashMap::new();
    for node in &ddg.nodes {
        if let Some(def) = &node.defines {
            let name = def.trim_start_matches('%').to_string();
            let score = dist.get(&node.id).map(|&d| 1.0 / (1.0 + d as f32)).unwrap_or(0.0);
            let prev = name_score.entry(name).or_insert(0.0);
            if score > *prev {
                *prev = score;
            }
        }
    }
    name_score
}

pub fn parse_int_literals(s: &str) -> Vec<i32> {
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

pub fn infer_i16_targets_from_ddg(ddg: &Ddg, dist: &HashMap<u64, u32>) -> Vec<i16> {
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

/// Build input fields from the harness ABI when no weights JSON is present.
/// Uses `prism-runtime`'s field wrappers instead of re-declaring extern "C".
pub fn build_runtime_input_fields(
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
    let field_count = crate::field_count();
    for idx in 0..field_count {
        if !crate::field_is_input(idx) {
            continue;
        }
        let Some(name) = crate::field_name(idx) else { continue };
        let size = crate::field_size(idx);
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

/// Build byte weights and InputFields from a weights JSON (probe-adv output).
pub fn input_fields_from_weights_json(
    wj: WeightsJson,
    frame_size: usize,
) -> (Vec<f32>, Vec<InputField>) {
    let mut bw = wj.byte_weights;
    bw.resize(frame_size, 0.0);
    bw.truncate(frame_size);
    let fields = wj
        .input_fields
        .into_iter()
        .map(|g| {
            let model = match g.model.as_str() {
                "bool"      => FieldValueModel::Bool,
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
    (bw, fields)
}

/// Derive per-byte weights from DDG-analysed input fields.
pub fn ddg_byte_weights(fields: &[InputField], frame_size: usize) -> Vec<f32> {
    let mut bw = vec![0.0f32; frame_size];
    for f in fields {
        let score = if f.ddg_score > 0.0 { f.ddg_score } else { 0.05 };
        let end = (f.offset + f.size).min(frame_size);
        for w in &mut bw[f.offset..end] {
            *w = score;
        }
    }
    bw
}

// ---------------------------------------------------------------------------
// Weighted random helpers
// ---------------------------------------------------------------------------

pub struct WeightedIndex {
    cumulative: Vec<f32>,
}

impl WeightedIndex {
    pub fn new(weights: impl IntoIterator<Item = f32>) -> Self {
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

    pub fn sample<R: Rand>(&self, rand: &mut R) -> Option<usize> {
        let total = self.cumulative.last().copied()?;
        let r = rand.next_float() as f32 * total;
        let idx = self.cumulative.partition_point(|&c| c < r);
        Some(idx.min(self.cumulative.len().saturating_sub(1)))
    }
}

pub fn pick_usize<R: Rand>(rand: &mut R, upper: usize) -> Option<usize> {
    if upper == 0 {
        return None;
    }
    Some((rand.next() as usize) % upper)
}

pub fn expand_weights_for_sequence(base_weights: &[f32], required_len: usize) -> Vec<f32> {
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

/// Stamps a "joint-good frame" — all driver fields at target values, inhibitors
/// at 0 — across a contiguous window of ≥9 frames.  This is the primary fix for
/// joint-constraint bugs where independent field mutations rarely co-occur.
pub struct AccumulationWindowMutator {
    frame_size: usize,
    driver_fields: Vec<(usize, Vec<Vec<u8>>)>,
    #[allow(dead_code)]
    inhibitor_offsets: Vec<usize>,
    min_window: usize,
}

impl AccumulationWindowMutator {
    pub fn new(frame_size: usize, fields: &[InputField]) -> Self {
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

/// Picks one field by DDG score and writes a semantically appropriate value.
pub struct FieldValueMutator {
    frame_size: usize,
    fields: Vec<InputField>,
    picker: WeightedIndex,
}

impl FieldValueMutator {
    pub fn new(frame_size: usize, fields: Vec<InputField>) -> Self {
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

/// Frame-level pattern operations using role-aware bool field handling.
/// Activators (non-inhibitor booleans) get the pulse treatment.
/// Inhibitors get a zero-window that holds them low for ≥9 frames.
pub struct FramePatternMutator {
    frame_size: usize,
    activator_offsets: Vec<usize>,
    inhibitor_offsets: Vec<usize>,
}

impl FramePatternMutator {
    pub fn new(frame_size: usize, fields: &[InputField]) -> Self {
        let activator_offsets = fields
            .iter()
            .filter_map(|f| {
                (matches!(f.model, FieldValueModel::Bool) && f.role != FieldRole::Inhibitor)
                    .then_some(f.offset)
            })
            .collect();
        let inhibitor_offsets = fields
            .iter()
            .filter_map(|f| {
                (matches!(f.model, FieldValueModel::Bool) && f.role == FieldRole::Inhibitor)
                    .then_some(f.offset)
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

/// Writes a complete field value chosen from the target-value list, weighted by
/// per-byte DDG proximity scores.
pub struct InputRangeMutator {
    frame_size: usize,
    fields: Vec<(usize, usize, Vec<Vec<u8>>)>,
    picker: WeightedIndex,
}

impl InputRangeMutator {
    pub fn new(frame_size: usize, input_fields: &[InputField], byte_weights: &[f32]) -> Self {
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

/// Single-byte random flip weighted by DDG proximity to sinks.
pub struct DdgByteMutator {
    picker: WeightedIndex,
}

impl DdgByteMutator {
    pub fn new(weights: Vec<f32>) -> Self {
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
