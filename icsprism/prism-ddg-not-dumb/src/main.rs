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
    execute_testcase_with_heartbeat, harness_dimensions, load_config, required_input_len,
};
use serde::Deserialize;

const MAP_SIZE: usize = 65536;
const STATE_HEARTBEAT_INTERVAL_SECS: u64 = 5;
static mut COV_MAP_PTR: *mut u8 = std::ptr::null_mut();

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
#[command(
    name = "prism-ddg-not-dumb",
    about = "Smarter DDG-guided ST fuzzer with frame-aware mutations"
)]
struct Args {
    #[arg(long)]
    ddg: PathBuf,

    #[arg(long)]
    layout: PathBuf,

    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    #[arg(short, long, default_value_t = 8)]
    seeds: usize,

    #[arg(long)]
    config: Option<PathBuf>,
}

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
}

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
        });
    }
    fields
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

struct FieldValueMutator {
    frame_size: usize,
    fields: Vec<InputField>,
    picker: WeightedIndex,
}

impl FieldValueMutator {
    fn new(frame_size: usize, fields: Vec<InputField>) -> Self {
        let picker = WeightedIndex::new(fields.iter().map(|f| f.ddg_score));
        Self {
            frame_size,
            fields,
            picker,
        }
    }
}

impl Named for FieldValueMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static NAME: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
        NAME.get_or_init(|| std::borrow::Cow::Borrowed("FieldValueMutator"))
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
                bytes[start] = if (state.rand_mut().next() & 1) == 0 {
                    0
                } else {
                    1
                };
            }
            FieldValueModel::I16 { targets } => {
                if field.size != 2 {
                    return Ok(MutationResult::Skipped);
                }
                let choose_target = (state.rand_mut().next() % 100) < 80 && !targets.is_empty();
                let value = if choose_target {
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
    bool_offsets: Vec<usize>,
}

impl FramePatternMutator {
    fn new(frame_size: usize, fields: &[InputField]) -> Self {
        let bool_offsets = fields
            .iter()
            .filter_map(|f| matches!(f.model, FieldValueModel::Bool).then_some(f.offset))
            .collect();
        Self {
            frame_size,
            bool_offsets,
        }
    }
}

impl Named for FramePatternMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static NAME: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
        NAME.get_or_init(|| std::borrow::Cow::Borrowed("FramePatternMutator"))
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
        let op = state.rand_mut().next() % 2;
        if op == 0 {
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
            let src_start = src * self.frame_size;
            let src_end = src_start + self.frame_size;
            let src_frame = bytes[src_start..src_end].to_vec();
            for i in 0..=run_len {
                let d = dst + i;
                if d >= frame_count {
                    break;
                }
                let d_start = d * self.frame_size;
                let d_end = d_start + self.frame_size;
                bytes[d_start..d_end].copy_from_slice(&src_frame);
            }
            return Ok(MutationResult::Mutated);
        }

        if self.bool_offsets.is_empty() {
            return Ok(MutationResult::Skipped);
        }
        let Some(offset_idx) = pick_usize(state.rand_mut(), self.bool_offsets.len()) else {
            return Ok(MutationResult::Skipped);
        };
        let offset = self.bool_offsets[offset_idx];
        let Some(pulse_frame) = pick_usize(state.rand_mut(), frame_count) else {
            return Ok(MutationResult::Skipped);
        };
        let start_frame = pulse_frame.saturating_sub(1);
        let end_frame = (pulse_frame + 1).min(frame_count - 1);
        for f in start_frame..=end_frame {
            let pos = f * self.frame_size + offset;
            bytes[pos] = 0;
        }
        let pulse_pos = pulse_frame * self.frame_size + offset;
        bytes[pulse_pos] = 1;
        Ok(MutationResult::Mutated)
    }

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

pub struct DdgByteMutator {
    picker: WeightedIndex,
}

impl DdgByteMutator {
    pub fn new(weights: Vec<f32>) -> Self {
        Self {
            picker: WeightedIndex::new(weights),
        }
    }
}

impl Named for DdgByteMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static NAME: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
        NAME.get_or_init(|| std::borrow::Cow::Borrowed("DdgByteMutator"))
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

    fn post_exec(&mut self, _state: &mut S, _new_corpus_id: Option<CorpusId>) -> Result<(), Error> {
        Ok(())
    }
}

fn main() {
    let args = Args::parse();
    let loaded =
        load_config(args.config.as_deref()).unwrap_or_else(|e| panic!("[prism-ddg-not-dumb] {e}"));
    let ddg: Ddg = serde_json::from_reader(
        File::open(&args.ddg).unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.ddg, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse DDG JSON: {}", e));
    let layouts: Vec<ProgramLayout> = serde_json::from_reader(
        File::open(&args.layout).unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.layout, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {}", e));
    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    let dims = harness_dimensions();
    let frame_size = dims.input_size;
    let required_len = required_input_len(&loaded.config, frame_size);

    let dist = build_ddg_distances(&ddg);
    let name_scores = build_name_scores(&ddg, &dist);
    let i16_targets = infer_i16_targets_from_ddg(&ddg, &dist);
    let input_fields = build_runtime_input_fields(&layout, frame_size, &name_scores, &i16_targets);

    let mut base_frame_weights = vec![0.0f32; frame_size];
    for field in &input_fields {
        let score = if field.ddg_score > 0.0 {
            field.ddg_score
        } else {
            0.05
        };
        let end = (field.offset + field.size).min(frame_size);
        for w in &mut base_frame_weights[field.offset..end] {
            *w = score;
        }
    }
    let weights = expand_weights_for_sequence(&base_frame_weights, required_len);

    println!(
        "[prism-ddg-not-dumb] Program       : {}",
        layout.struct_name
    );
    println!(
        "[prism-ddg-not-dumb] Layout bytes  : {}",
        layout.total_bytes
    );
    println!("[prism-ddg-not-dumb] Input frame   : {} bytes", frame_size);
    println!(
        "[prism-ddg-not-dumb] Input total   : {} bytes",
        required_len
    );
    println!(
        "[prism-ddg-not-dumb] State         : {} bytes",
        dims.state_size
    );
    println!(
        "[prism-ddg-not-dumb] Struct        : {} bytes",
        dims.struct_size
    );
    println!(
        "[prism-ddg-not-dumb] Mode          : {:?}",
        loaded.config.execution.mode
    );
    println!(
        "[prism-ddg-not-dumb] DDG constants : {} inferred i16 targets",
        i16_targets.len()
    );
    println!(
        "[prism-ddg-not-dumb] Input fields  : {}",
        input_fields.len()
    );
    for field in &input_fields {
        println!(
            "[prism-ddg-not-dumb]   {:20} off={:>2} size={:>2} score={:.4}",
            field.name, field.offset, field.size, field.ddg_score
        );
    }
    println!(
        "[prism-ddg-not-dumb] Config        : {}",
        loaded.source_label()
    );
    println!(
        "[prism-ddg-not-dumb] Crashes       : {}",
        args.crashes.display()
    );

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

    let field_mutator = FieldValueMutator::new(frame_size, input_fields.clone());
    let frame_mutator = FramePatternMutator::new(frame_size, &input_fields);
    let ddg_mutator = DdgByteMutator::new(weights);
    let mutator = HavocScheduledMutator::new(
        tuple_list!(field_mutator, frame_mutator, ddg_mutator).merge(havoc_mutations()),
    );
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    println!("[prism-ddg-not-dumb] Fuzzing — Ctrl+C to stop");
    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
