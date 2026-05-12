use std::{
    fs::File,
    path::{Path, PathBuf},
};

use clap::Parser;
use libafl::{
    Error,
    corpus::{InMemoryCorpus, OnDiskCorpus},
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
    effective_cycles, execute_testcase_with_heartbeat, harness_dimensions, load_config,
    required_input_len,
};
use serde::Deserialize;

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
#[command(name = "prism-ddg-input", about = "Input-restricted DDG-guided ST fuzzer")]
struct Args {
    #[arg(long)]
    ddg: PathBuf,

    #[arg(long)]
    layout: PathBuf,

    #[arg(long, help = "Path to weights JSON produced by probe_ddg_adv.py (required)")]
    weights_json: PathBuf,

    #[arg(short, long, default_value = "./crashes")]
    crashes: PathBuf,

    #[arg(short, long, default_value_t = 8)]
    seeds: usize,

    #[arg(long)]
    config: Option<PathBuf>,
}

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

#[derive(Debug, Deserialize)]
struct InputComparison {
    #[allow(dead_code)]
    pred: String,
    #[allow(dead_code)]
    threshold: i64,
}

#[derive(Debug, Deserialize)]
struct InputFieldGuide {
    name: String,
    llvm_type: String,
    byte_size: u64,
    byte_offset: u64,
    model: String,
    roles: Vec<String>,
    #[allow(dead_code)]
    comparisons: Vec<InputComparison>,
    #[allow(dead_code)]
    target_values: Vec<i64>,
    critical: bool,
}

#[derive(Debug, Deserialize)]
struct AnalysisGuide {
    main_function: String,
    frame_size: usize,
    input_fields: Vec<InputFieldGuide>,
    byte_weights: Vec<f32>,
}

#[derive(Debug, Clone)]
struct PlannedField {
    name: String,
    llvm_type: String,
    model: String,
    roles: Vec<String>,
    byte_size: usize,
    full_offset: usize,
    compact_offset: Option<usize>,
    selected: bool,
    critical: bool,
    weight: f32,
}

#[derive(Debug, Clone)]
struct InputPlan {
    main_function: String,
    full_frame_size: usize,
    compact_frame_size: usize,
    fields: Vec<PlannedField>,
    compact_weights: Vec<f32>,
}

fn is_selected_field(field: &InputFieldGuide) -> bool {
    field.critical || field.roles.iter().any(|role| role != "neutral")
}

fn build_input_plan(guide: AnalysisGuide) -> InputPlan {
    let mut any_selected = false;
    for field in &guide.input_fields {
        if is_selected_field(field) {
            any_selected = true;
            break;
        }
    }

    let mut fields = Vec::with_capacity(guide.input_fields.len());
    let mut compact_weights = Vec::new();
    let mut compact_offset = 0usize;

    for field in guide.input_fields {
        let selected = if any_selected {
            is_selected_field(&field)
        } else {
            true
        };
        let byte_size = field.byte_size as usize;
        let full_offset = field.byte_offset as usize;
        let compact_offset_value = if selected {
            for idx in 0..byte_size {
                compact_weights.push(guide.byte_weights.get(full_offset + idx).copied().unwrap_or(0.0));
            }
            let offset = compact_offset;
            compact_offset += byte_size;
            Some(offset)
        } else {
            None
        };

        fields.push(PlannedField {
            name: field.name,
            llvm_type: field.llvm_type,
            model: field.model,
            roles: field.roles,
            byte_size,
            full_offset,
            compact_offset: compact_offset_value,
            selected,
            critical: field.critical,
            weight: guide.byte_weights.get(full_offset).copied().unwrap_or(0.0),
        });
    }

    InputPlan {
        main_function: guide.main_function,
        full_frame_size: guide.frame_size,
        compact_frame_size: compact_offset,
        fields,
        compact_weights,
    }
}

fn expand_compact_input(config: &prism_runtime::PrismFuzzConfig, data: &[u8], plan: &InputPlan, full_frame_len: usize) -> Option<Vec<u8>> {
    let cycles = effective_cycles(config);
    let compact_frame_len = plan.compact_frame_size;
    let compact_required = required_input_len(config, compact_frame_len);
    if data.len() < compact_required {
        return None;
    }

    let mut expanded = vec![0u8; required_input_len(config, full_frame_len)];
    for cycle in 0..cycles {
        let compact_start = cycle * compact_frame_len;
        let compact_end = compact_start + compact_frame_len;
        let full_start = cycle * full_frame_len;
        let full_end = full_start + full_frame_len;
        let compact_cycle = &data[compact_start..compact_end];
        let full_cycle = &mut expanded[full_start..full_end];
        let mut cursor = 0usize;

        for field in &plan.fields {
            if !field.selected {
                continue;
            }
            let size = field.byte_size;
            let src = &compact_cycle[cursor..cursor + size];
            let dst_start = field.full_offset;
            let dst_end = dst_start + size;
            full_cycle[dst_start..dst_end].copy_from_slice(src);
            cursor += size;
        }

        if cursor != compact_frame_len {
            return None;
        }
    }

    Some(expanded)
}

fn format_roles(roles: &[String]) -> String {
    if roles.is_empty() {
        return "<none>".to_string();
    }
    roles.join(",")
}

fn print_input_plan(
    tag: &str,
    loaded: &prism_runtime::LoadedConfig,
    plan: &InputPlan,
    dims: prism_runtime::HarnessDimensions,
    crashes: &Path,
    source: &Path,
    layout: &ProgramLayout,
) {
    println!("[{tag}] DDG guide    : {}", source.display());
    println!("[{tag}] Program      : {}", plan.main_function);
    println!("[{tag}] Layout       : {} bytes, {} fields", layout.total_bytes, layout.fields.len());
    println!("[{tag}] Harness input : {} bytes", dims.input_size);
    println!("[{tag}] Full frame    : {} bytes", plan.full_frame_size);
    println!("[{tag}] Compact frame : {} bytes", plan.compact_frame_size);
    println!("[{tag}] Compact total : {} bytes", plan.compact_weights.len());
    println!("[{tag}] Mode          : {:?}", loaded.config.execution.mode);
    println!("[{tag}] Config        : {}", loaded.source_label());
    println!("[{tag}] Crashes       : {}", crashes.display());
    println!("[{tag}] Field guide:");
    for field in &plan.fields {
        let full_range = format!("[{}..{}]", field.full_offset, field.full_offset + field.byte_size.saturating_sub(1));
        let compact_range = match field.compact_offset {
            Some(offset) => format!("[{}..{}]", offset, offset + field.byte_size.saturating_sub(1)),
            None => "SKIP".to_string(),
        };
        let role_text = format_roles(&field.roles);
        let selected = if field.selected { "USE" } else { "SKIP" };
        println!(
            "[{tag}]   {:16} {:4} full={} compact={} size={:>2} model={:10} critical={} weight={:.4} roles={}",
            field.name,
            selected,
            full_range,
            compact_range,
            field.byte_size,
            field.model,
            field.critical,
            field.weight,
            role_text,
        );
    }
    println!("[{tag}] Compact weights:");
    for (byte_idx, weight) in plan.compact_weights.iter().enumerate() {
        let field_name = plan
            .fields
            .iter()
            .find(|field| {
                field.selected
                    && field
                        .compact_offset
                        .map(|offset| byte_idx >= offset && byte_idx < offset + field.byte_size)
                        .unwrap_or(false)
            })
            .map(|field| field.name.as_str())
            .unwrap_or("?");
        println!("[{tag}]   byte {:>3} {:16} {:>8.4}", byte_idx, field_name, weight);
    }
    if dims.input_size != plan.full_frame_size {
        println!(
            "[{tag}] WARNING: harness input_size={} differs from analysis frame_size={}",
            dims.input_size, plan.full_frame_size
        );
    }
}

pub struct CompactByteMutator {
    cumulative: Vec<f32>,
}

impl CompactByteMutator {
    fn new(weights: Vec<f32>) -> Self {
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

impl Named for CompactByteMutator {
    fn name(&self) -> &std::borrow::Cow<'static, str> {
        static NAME: std::sync::OnceLock<std::borrow::Cow<'static, str>> =
            std::sync::OnceLock::new();
        NAME.get_or_init(|| std::borrow::Cow::Borrowed("CompactByteMutator"))
    }
}

impl<S> Mutator<BytesInput, S> for CompactByteMutator
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

    fn post_exec(
        &mut self,
        _state: &mut S,
        _new_corpus_id: Option<libafl::corpus::CorpusId>,
    ) -> Result<(), Error> {
        Ok(())
    }
}

fn main() {
    let args = Args::parse();
    let loaded = load_config(args.config.as_deref())
        .unwrap_or_else(|e| panic!("[prism-ddg-input] {e}"));

    let layouts: Vec<ProgramLayout> = serde_json::from_reader(
        File::open(&args.layout).unwrap_or_else(|e| panic!("Cannot open {:?}: {}", args.layout, e)),
    )
    .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {}", e));

    let layout = layouts.into_iter().last().expect("layout JSON is empty");

    let analysis_file = File::open(&args.weights_json)
        .unwrap_or_else(|e| panic!("Cannot open weights JSON {:?}: {}", args.weights_json, e));
    let guide: AnalysisGuide = serde_json::from_reader(analysis_file)
        .unwrap_or_else(|e| panic!("Cannot parse weights JSON: {}", e));
    let plan = build_input_plan(guide);

    let dims = harness_dimensions();
    print_input_plan(
        "prism-ddg-input",
        &loaded,
        &plan,
        dims,
        &args.crashes,
        &args.weights_json,
        &layout,
    );

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
    let plan_for_exec = plan.clone();
    let full_frame_len = dims.input_size;
    let mut harness = move |input: &BytesInput| {
        let bytes = input.target_bytes();
        let data: &[u8] = bytes.as_ref();
        let Some(expanded) = expand_compact_input(&config, data, &plan_for_exec, full_frame_len) else {
            return ExitKind::Ok;
        };
        let _ = execute_testcase_with_heartbeat(
            &config,
            &expanded,
            full_frame_len,
            "prism-ddg-input",
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

    let mut generator = RandBytesGenerator::new(
        std::num::NonZeroUsize::new(
            required_input_len(&loaded.config, plan.compact_frame_size).max(1),
        )
        .unwrap(),
    );

    state
        .generate_initial_inputs_forced(
            &mut fuzzer,
            &mut executor,
            &mut generator,
            &mut mgr,
            args.seeds,
        )
        .unwrap();

    let mutator = CompactByteMutator::new(plan.compact_weights.clone());
    let mutator = HavocScheduledMutator::new(tuple_list!(mutator).merge(havoc_mutations()));
    let mut stages = tuple_list!(StdMutationalStage::new(mutator));

    println!("[prism-ddg-input] Fuzzing — Ctrl+C to stop");
    fuzzer
        .fuzz_loop(&mut stages, &mut executor, &mut state, &mut mgr)
        .unwrap();
}
