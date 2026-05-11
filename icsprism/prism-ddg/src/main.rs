use std::{
    collections::{HashMap, VecDeque},
    fs::File,
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
use prism_runtime::{execute_testcase, harness_dimensions, load_config, required_input_len};
use serde::Deserialize;

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
#[command(name = "prism-ddg", about = "DDG-guided ST fuzzer")]
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

// ---------------------------------------------------------------------------
// DDG JSON schema
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct DdgNode {
    id: u64,
    defines: Option<String>,
    has_dynamic_index: bool,
}

#[derive(Debug, Deserialize)]
struct DdgEdge {
    from: u64,
    to: u64,
    #[allow(dead_code)]
    kind: String,
}

#[derive(Debug, Deserialize)]
struct Ddg {
    nodes: Vec<DdgNode>,
    edges: Vec<DdgEdge>,
}

// ---------------------------------------------------------------------------
// Layout JSON schema
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
// DDG proximity scoring
// ---------------------------------------------------------------------------

fn is_fuzzable(field: &FieldLayout) -> bool {
    let name = field.name.as_deref().unwrap_or("");
    name != "__vtable" && !field.llvm_type.starts_with('%')
}

fn build_byte_weights(ddg: &Ddg, layout: &ProgramLayout) -> Vec<f32> {
    let input_size = layout.total_bytes as usize;

    let sinks: Vec<u64> = ddg
        .nodes
        .iter()
        .filter(|n| n.has_dynamic_index)
        .map(|n| n.id)
        .collect();

    if sinks.is_empty() {
        println!("[prism-ddg] WARNING: no dynamic-index sinks found — using uniform weights");
        return vec![1.0f32; input_size];
    }
    println!("[prism-ddg] DDG sinks: {} dynamic GEP node(s)", sinks.len());

    let mut rev_adj: HashMap<u64, Vec<u64>> = HashMap::new();
    for edge in &ddg.edges {
        rev_adj.entry(edge.to).or_default().push(edge.from);
    }

    let mut dist: HashMap<u64, u32> = HashMap::new();
    let mut queue: VecDeque<u64> = VecDeque::new();
    for &s in &sinks {
        dist.insert(s, 0);
        queue.push_back(s);
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

    let mut name_score: HashMap<String, f32> = HashMap::new();
    for node in &ddg.nodes {
        if let Some(def) = &node.defines {
            let field_name = def.trim_start_matches('%').to_string();
            let score = dist
                .get(&node.id)
                .map(|&d| 1.0 / (1.0 + d as f32))
                .unwrap_or(0.0);
            let entry = name_score.entry(field_name).or_insert(0.0);
            if score > *entry {
                *entry = score;
            }
        }
    }

    let mut weights = vec![0.0f32; input_size];
    for field in &layout.fields {
        if !is_fuzzable(field) {
            continue;
        }
        let name = field.name.as_deref().unwrap_or("");
        let score = name_score.get(name).copied().unwrap_or(0.0);
        let start = field.byte_offset as usize;
        let end = (start + field.byte_size as usize).min(input_size);
        for b in start..end {
            weights[b] = score;
        }
    }

    weights
}

fn expand_weights(weights: &[f32], required_len: usize) -> Vec<f32> {
    if weights.is_empty() {
        return vec![1.0; required_len.max(1)];
    }
    if required_len <= weights.len() {
        return weights[..required_len].to_vec();
    }

    let mut out = Vec::with_capacity(required_len);
    while out.len() < required_len {
        let remaining = required_len - out.len();
        let take = remaining.min(weights.len());
        out.extend_from_slice(&weights[..take]);
    }
    out
}

// ---------------------------------------------------------------------------
// DDG-biased byte mutator
// ---------------------------------------------------------------------------

pub struct DdgByteMutator {
    cumulative: Vec<f32>,
}

impl DdgByteMutator {
    pub fn new(weights: Vec<f32>) -> Self {
        let all_zero = weights.iter().all(|&w| w == 0.0);
        let mut cumulative = Vec::with_capacity(weights.len());
        let mut sum = 0.0f32;
        for &w in &weights {
            sum += if all_zero { 1.0 } else { w };
            cumulative.push(sum);
        }
        Self { cumulative }
    }

    fn sample_index<R: Rand>(&self, rand: &mut R) -> usize {
        let total = self.cumulative.last().copied().unwrap_or(1.0);
        let r = rand.next_float() as f32 * total;
        let idx = self.cumulative.partition_point(|&c| c < r);
        idx.min(self.cumulative.len().saturating_sub(1))
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

        if bytes.is_empty() || self.cumulative.is_empty() {
            return Ok(MutationResult::Skipped);
        }
        let idx = self.sample_index(state.rand_mut());
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

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() {
    let args = Args::parse();
    let loaded = load_config(args.config.as_deref()).unwrap_or_else(|e| panic!("[prism-ddg] {e}"));

    let ddg: Ddg = serde_json::from_reader(
        File::open(&args.ddg).unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.ddg, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse DDG JSON: {}", e));

    let layouts: Vec<ProgramLayout> = serde_json::from_reader(
        File::open(&args.layout).unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.layout, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {}", e));

    // Layout JSON contains one entry per struct in the program.
    // The last entry is always the top-level program struct (e.g. HarnessTest).
    // Earlier entries are nested helper structs (e.g. Counter) — skip them.
    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    println!("[prism-ddg] Program  : {}", layout.struct_name);
    println!(
        "[prism-ddg] Layout   : {} bytes, {} fields",
        layout.total_bytes,
        layout.fields.len()
    );

    let base_weights = build_byte_weights(&ddg, &layout);

    println!("[prism-ddg] Field weights:");
    for field in &layout.fields {
        if !is_fuzzable(field) {
            continue;
        }
        let name = field.name.as_deref().unwrap_or("<unnamed>");
        let b = field.byte_offset as usize;
        let score = base_weights.get(b).copied().unwrap_or(0.0);
        println!(
            "[prism-ddg]   {:20} offset={:>3} size={:>2}  score={:.4}",
            name, b, field.byte_size, score
        );
    }

    let dims = harness_dimensions();
    let in_size = dims.input_size;
    let required_len = required_input_len(&loaded.config, in_size);
    let weights = expand_weights(&base_weights, required_len);

    println!("[prism-ddg] Harness frame : {} bytes", in_size);
    println!("[prism-ddg] Harness input : {} bytes", required_len);
    println!("[prism-ddg] Harness state : {} bytes", dims.state_size);
    println!("[prism-ddg] Harness struct: {} bytes", dims.struct_size);
    println!(
        "[prism-ddg] Mode          : {:?}",
        loaded.config.execution.mode
    );
    println!("[prism-ddg] Config        : {}", loaded.source_label());
    println!("[prism-ddg] Crashes       : {}", args.crashes.display());

    if in_size != layout.total_bytes as usize {
        println!(
            "[prism-ddg] WARNING: layout total_bytes={} vs harness input_size={} — weights may misalign",
            layout.total_bytes, in_size
        );
    }

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
        let _ = execute_testcase(&config, data, in_size);
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

    let ddg_mutator = DdgByteMutator::new(weights);
    let mutator = HavocScheduledMutator::new(tuple_list!(ddg_mutator).merge(havoc_mutations()));
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    println!("[prism-ddg] Fuzzing — Ctrl+C to stop");

    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
