# ICSPrism — Codebase Overview

ICSPrism is a fuzzing framework for ICS PLC programs written in Structured Text (ST).
It compiles ST programs to LLVM IR, analyzes the IR to extract field semantics and
data-dependency structure, then fuzzes the compiled shared library with coverage and
state-aware feedback to find bugs (typically triggered by `prism_bug_abort_if`).

---

## Repository layout

```
ICSPrism/
├── rusty/                      # submodule — RuSTy ST compiler (LLVM 21)
├── icsprism/                   # Rust workspace — analysis + fuzzer binaries
│   ├── ir-analysis/            # LLVM IR analysis: layout + DDG extraction
│   ├── prism-runtime/          # shared library ABI wrapper + execution primitives
│   ├── prism-cov/              # baseline AFL-style fuzzer (coverage only)
│   ├── prism-ddg/              # DDG-weighted byte mutations
│   ├── prism-ddg-not-dumb/     # DDG + field-role-aware mutations
│   ├── prism-ddg-state/        # DDG + secondary state-hash coverage signal
│   └── prism-go-explore/       # Go-Explore: checkpoint + zone-burst fuzzer
├── tools/
│   └── ddg/                    # Python analysis package (run via python -m ddg <cmd>)
│       ├── __main__.py         # CLI entry point
│       ├── graph.py            # DDG → NetworkX DiGraph builder
│       ├── fields.py           # ICmp/GEP resolution, layout field lookups
│       ├── io.py               # JSON loader helpers
│       ├── probe.py            # basic proximity score probe
│       ├── probe_adv.py        # semantic analysis → _weights.json
│       ├── state_hash.py       # state variable selection → _harness_heuristics.json
│       ├── to_dot.py           # DDG → GraphViz DOT
│       └── zones.py            # zone constraint derivation → _zone_constraints.json
├── scripts/
│   ├── stc.sh                  # 11-step ST → shared library pipeline
│   ├── ddg_goexplore.sh        # end-to-end go-explore launcher
│   ├── ddg_fuzz.sh             # ddg fuzzer launcher
│   ├── ddg_state.sh            # ddg-state fuzzer launcher
│   ├── cov_fuzz.sh             # coverage fuzzer launcher
│   └── compile_*.sh            # individual compile sub-steps
└── benchmarks/                 # ST benchmark programs + compiled artifacts (benchmarks/out/)
```

---

## Full pipeline

### Step 1 — ST compilation (`stc.sh`)
`rusty/target/debug/plc` compiles `<name>.st` into `<name>.bc` (bitcode) and `<name>.ll`
(LLVM IR text) with debug info (`-g`) and without optimization.

### Step 2 — IR analysis (`prism-analyze`)
`ir-analysis` reads the LLVM IR using inkwell and produces:
- `<name>_layout.json` — array of struct descriptors (struct_name, total_bytes, fields[]).
  Each field has name, llvm_type, byte_offset, byte_size.
  The **last entry** is the top-level program struct.
- `<name>_ddg.json` — Data Dependency Graph.
  Nodes carry: id, function, basic_block, opcode, ir, defines, callee, has_dynamic_index.
  Edges carry: from, to, kind (data_ssa | data_memory | memory_overwrite), symbol.

### Step 3 — C harness generation (`prism-harness`)
Reads the layout JSON and emits `<name>_harness.c` that exposes:
```c
void*  prism_alloc()                           // allocate zeroed PLC struct
void   prism_reset(void* inst)                 // zero struct (keep vtable)
void   prism_free(void* inst)
void   prism_run(void* inst, uint8_t* frame, size_t len)  // set inputs + run one scan
void   prism_step(void* inst)                  // run one scan without changing inputs
void   prism_get_state(void* inst, uint8_t* out)
void   prism_set_state(void* inst, uint8_t* state, size_t len)
size_t prism_state_size(), prism_input_size(), prism_struct_size()
char*  prism_program_name()
uint32_t prism_field_count()
char*  prism_field_name(uint32_t idx)
size_t prism_field_size(uint32_t idx), prism_field_offset(uint32_t idx)
int    prism_field_is_input(uint32_t idx)
size_t prism_get_field(void* inst, uint32_t idx, uint8_t* out)
int    prism_set_field(void* inst, uint32_t idx, uint8_t* data, size_t len)
```
This ABI is stable across all fuzzer variants. `prism_field_is_input` distinguishes
VAR_INPUT fields from internal state.

### Step 4 — Compilation
clang-21 compiles the instrumented LLVM IR (`-fsanitize-coverage=trace-pc-guard`) and
the C harness into a shared library `lib<name>.so`.
Fuzzers load the library at link-time via `PRISM_LIB_DIR` + `PRISM_LIB_NAME` env vars
set by the build scripts, which are consumed by `build.rs` in each fuzzer crate.

### Step 5 — Python analysis (`tools/ddg`)
All subcommands are run as `PYTHONPATH=./tools python3 -m ddg <cmd>`.

**`probe-adv`** (`probe_adv.py`) → `_weights.json`
- Finds `prism_bug_abort_if` call sites → resolves the guarding ICmp → (field, pred, threshold).
  This gives the "abort target" and "discriminant" field (e.g. FillHead).
- Finds all ICmp comparisons and store-guard relationships in the main function.
- Builds an accumulation chain: walks backward from the abort field to reconstruct the
  causal sequence of state variables that must accumulate for the abort to fire.
- Classifies each VAR_INPUT field into roles:
  - `inhibitor` — when non-zero, triggers a reset of a chain variable
  - `driver` — guards an increment of a chain variable
  - `activator` — gates a non-chain state write
  - `fault_gate` — appears only in the abort guard (sgt with high threshold)
  - `neutral` — no structural role found
- Computes per-byte weights: inhibitors=1.0, drivers=0.9, activators=0.7, neutral=0.1.
- Outputs per-field `target_values` (boundary ± 1 values around each ICmp threshold).

**`state-hash`** (`state_hash.py`) → `_harness_heuristics.json`
- Selects internal state variables (not inputs) that have ICmp comparisons or GEP sinks.
- Assigns a bucket scheme per variable:
  - `identity` — switch dispatch (small discrete set)
  - `threshold_fine` — fine-grained 0..N (small ICmp threshold)
  - `threshold_log2` — log2-spaced buckets (large threshold)
  - `raw_capped` — raw value 0..bound-1 + OOB (small array bound)
  - `binary` — fallback
- Marks `high_watermark = true` for accumulating variables (with reset stores or GEP sinks).
  Fuzzers track the per-run maximum of these rather than their current value.

**`zones`** (`zones.py`) → `_zone_constraints.json`
- Reads the discriminant field from `_weights.json` abort_targets.
- Divides the discriminant's [0, max_fillhead] range evenly into N zones (default 8).
- For each non-inhibitor input field, derives [lo, hi] from its ICmp comparisons.
  Higher zone index → progressively tighter range (up to 40% narrowing at the last zone).
- Optionally extracts sub-accumulator fields (state variables that gate the discriminant's
  increment) using one of three strategies (priority order):
  1. DDG backward BFS from discriminant increment stores through CFG branch guards
  2. High-watermark fields from the state-hash heuristics JSON
  3. `accumulation_chain.accumulation_guards` from the weights JSON

---

## prism-runtime

Shared library depended on by all fuzzer binaries. Has two layers:

### `prism_runtime` (lib.rs) — execution primitives

| Function | Purpose |
|---|---|
| `load_config()` | Load `prism-fuzz.toml` (or default) |
| `harness_dimensions()` | Return input_size, state_size, struct_size from harness |
| `required_input_len()` | Total bytes needed for configured execution mode |
| `field_count()`, `field_name()`, `field_offset()`, `field_size()`, `field_is_input()` | Field metadata wrappers |
| `execute_testcase()` | Run one testcase (simple, no snapshot) |
| `execute_testcase_with_state_snapshots()` | Run + call closure after every scan cycle with the full struct snapshot |
| `execute_testcase_from_checkpoint()` | Restore snapshot, then run new frames — core Go-Explore primitive |
| `Instance` | RAII wrapper around a heap-allocated PLC instance |

### `prism_runtime::fuzzing` (fuzzing.rs) — shared fuzzing types and mutators

All code that was previously duplicated across `prism-go-explore`, `prism-ddg-state`,
and `prism-ddg-not-dumb` now lives here as a single source of truth:

| Item | Kind | Purpose |
|---|---|---|
| `Ddg`, `DdgNode`, `DdgEdge` | types | DDG JSON deserialization |
| `ProgramLayout`, `FieldLayout` | types | Layout JSON deserialization |
| `WeightsJson`, `InputFieldGuide` | types | Weights JSON deserialization |
| `StateHashConfigRaw`, `StateHashField`, `BucketScheme` | types | State hash config |
| `SubAccumulatorField` | type | Zone constraints (go-explore specific but shared for `snapshot_quality`) |
| `FieldRole`, `FieldValueModel`, `InputField` | types | Input field model |
| `build_ddg_distances`, `build_name_scores`, `infer_i16_targets_from_ddg` | fns | DDG analysis |
| `build_runtime_input_fields` | fn | DDG-fallback input field building (uses `field_*` wrappers) |
| `input_fields_from_weights_json` | fn | Parse input fields + byte weights from weights JSON |
| `ddg_byte_weights` | fn | Derive per-byte weights from DDG fields |
| `parse_state_hash_config`, `read_i32_from_state`, `compute_bucket` | fns | State hash ops |
| `snapshot_quality` | fn | Score a struct snapshot for checkpoint selection |
| `WeightedIndex`, `pick_usize`, `expand_weights_for_sequence` | helpers | Weighted random |
| `AccumulationWindowMutator` | mutator | Joint-good-frame window stamping |
| `FieldValueMutator` | mutator | DDG-score-weighted field mutation |
| `FramePatternMutator` | mutator | Role-aware bool field patterns |
| `InputRangeMutator` | mutator | Byte-weight-guided candidate value selection |
| `DdgByteMutator` | mutator | Per-byte DDG proximity weighted flip |
| `COV_MAP_SIZE`, `STATE_MAP_SIZE` | consts | Shared shmem sizes |

### Execution modes (`prism-fuzz.toml` or config file)
- `SingleCycle` — one input frame per testcase (default)
- `ScanSequence` — `cycles` frames per testcase, with optional `warmup_cycles`

---

## prism-go-explore

The most sophisticated fuzzer. Uses Go-Explore: interleave standard mutation with
checkpoint-and-burst exploration.

### Data structures
- **Checkpoint table** — `Vec<Option<(snapshot: Vec<u8>, quality: u32)>>` indexed by
  discriminant bucket value (0..max_discriminant). One slot per possible discriminant value.
- **State hash fields** — parsed from `_harness_heuristics.json`; drive a secondary
  `StdMapObserver` fed into LibAFL's `MaxMapFeedback`.
- **Zone constraints** — parsed from `_zone_constraints.json`; drive burst frame generation.
- **Input fields** — parsed from either `_weights.json` (preferred) or inferred from DDG.

### Main loop
```
loop {
  // Phase 1: standard LibAFL mutation fuzzing
  for _ in 0..burst_size {
      // Write chk_gen to shmem bytes 3-4 before fork (child will echo it back)
      fuzzer.fuzz_one(...)   // normal LibAFL iteration
      // harness closure (in child): tracks state hash HWM + discriminant peak, writes checkpoint shmem
      // parent (after waitpid): validates generation, reads checkpoint, updates table
  }

  // Phase 2: checkpoint bursts
  for each selected checkpoint (Best or RoundRobin strategy):
      for _ in 0..burst_repeats:
          checkpoint_burst(bucket, snapshot, zone_config, ..., chk_gen)
}
```

### Checkpoint shmem IPC (5-byte header)
A shared memory region of size `CHECKPOINT_HDR(5) + struct_size`:
- Byte 0:   flag (1 = new checkpoint available)
- Bytes 1-2: discriminant bucket as u16 LE (supports max_discriminant > 255)
- Bytes 3-4: generation counter as u16 LE (parent writes before fork, child echoes back)
- Bytes 5+:  PLC struct snapshot

The generation counter detects stale shmem reads: if the echoed generation does not
match what the parent wrote before the fork, the read is discarded.
The parent writes `chk_gen` to bytes 3-4 before each `fuzz_one`; the child reads and
echoes it. After `waitpid`, the parent checks that the returned generation matches.

### Zone-aware burst frame generation
For each burst:
1. Resolve current zone from bucket value.
2. If within `RAMP_WINDOW` buckets of zone boundary: generate 70% current-zone frames
   + 30% next-zone frames to help transition across the boundary.
3. Each frame: inhibitors → 0, zone-constrained fields → uniform sample from [lo, hi],
   other I16 fields → 80% from target_values list / 20% random, booleans → random 0/1.

### Mutator stack
1. `FieldValueMutator` — DDG-score-weighted field selection, model-appropriate values
2. `FramePatternMutator` — copy frames, pulse activators, blank inhibitors
3. `InputRangeMutator` — byte-weight-guided field selection, sample from candidate list
4. `AccumulationWindowMutator` — replace a window of frames with accumulation-friendly values
5. `DdgByteMutator` — byte-weight-guided single-byte mutation
6. LibAFL `havoc_mutations()` — standard havoc stack

---

## Artifact naming conventions

| Artifact | Producer | Consumer |
|---|---|---|
| `<name>.ll`, `<name>.bc` | RuSTy (`plc`) | prism-analyze, clang |
| `<name>_layout.json` | prism-analyze | prism-harness, all fuzzers, Python tools |
| `<name>_ddg.json` | prism-analyze | Python tools, prism-go-explore (DDG analysis) |
| `<name>_ddg.dot` | `ddg to-dot` | Graphviz (human review) |
| `<name>_harness.c` | prism-harness | clang |
| `lib<name>.so` | clang | all fuzzer binaries (dlopen at build time) |
| `<name>_weights.json` | `ddg probe-adv` | prism-go-explore, `ddg zones` |
| `<name>_harness_heuristics.json` | `ddg state-hash` | prism-ddg-state, prism-go-explore, `ddg zones` |
| `<name>_zone_constraints.json` | `ddg zones` | prism-go-explore |

---

## Build and validation

| Task | Command |
|---|---|
| Build the ICSPrism workspace | `cargo build --manifest-path icsprism/Cargo.toml` |
| Build one crate | `cargo build --manifest-path icsprism/Cargo.toml -p ir-analysis` |
| Build one binary | `cargo build --manifest-path icsprism/Cargo.toml --bin prism-analyze` |
| Test the workspace | `cargo test --manifest-path icsprism/Cargo.toml --workspace` |
| Lint | `cargo clippy --manifest-path icsprism/Cargo.toml --workspace --all-targets` |
| Format | `cargo fmt --all --manifest-path icsprism/Cargo.toml` |

Set `LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix)` before RuSTy/inkwell builds.

End-to-end run: `./scripts/ddg_goexplore.sh benchmarks/pump_controller.st icsprism/goexplore-config.toml`

---

## Editing conventions

- `prism-runtime` owns all harness ABI interaction and execution primitives.
  Add new execution patterns here, not in individual fuzzer `main.rs` files.
- Layout JSON last-entry convention: code that reads layout always uses `layouts.last()`.
- `prism_field_is_input` is the canonical way to distinguish VAR_INPUT from state fields.
- Artifact naming is `<name>_<kind>.json` and `lib<name>.so`. Do not rename.
- Changes to `harness_gen.rs` (prism-harness output) must stay consistent with
  `prism-runtime/src/lib.rs` `extern "C"` declarations.
- Keep RuSTy (`rusty/`) as a read-only upstream dependency unless the task concerns
  the ST compiler itself.
