# Go-Explore: Next Steps

Improvements to the current approach, roughly ordered by impact.
Each item is self-contained and can be tackled independently.

---

## 1. Consolidate duplicated code into `prism-runtime`

**Problem.** `prism-go-explore`, `prism-ddg-state`, and `prism-ddg-not-dumb` all
duplicate: DDG/layout/weights JSON deserialization structs, all five custom mutators,
`WeightedIndex`, `pick_usize`, the `SanitizerCoverage` callback pair, and LibAFL
boilerplate setup.  Changes to any of these must be applied in every binary.

**Action.**
- Move shared deserialisation types (`InputField`, `FieldValueModel`, `FieldRole`,
  `WeightsJson`, `DdgNode`/`DdgEdge`/`Ddg`, `ProgramLayout`) into `prism-runtime`.
- Move all five mutators into `prism-runtime` as public types.
- Move `build_ddg_distances`, `build_name_scores`, `infer_i16_targets_from_ddg`, and
  `build_runtime_input_fields` into `prism-runtime`.
- Each fuzzer binary's `main.rs` should only contain the loop logic, not data loading
  or field parsing.

**Benefit.** Single source of truth; fixes propagate everywhere.

---

## 2. Remove program-specific naming from Go-Explore

**Problem.** Variable names (`fillhead_*`), log messages ("FillHead bucket"),
and the `SubAccumulatorField` concept all assume the discriminant is named "FillHead".
The code actually supports any field — the naming is just misleading residue from the
pump_controller benchmark.

**Action.**
- Rename all `fillhead_*` variables to `discriminant_*`.
- Update log strings accordingly ("discriminant bucket", "discriminant advance").
- Rename `fillhead_info: Option<(usize, usize)>` → `discriminant_info`.
- Rename `fillhead_lo`/`fillhead_hi` fields in `ZoneConstraint` to `lo`/`hi`
  (update both Rust deserialization and Python `zones.py` output).

**Benefit.** The tool reads as generic without changing any behavior.

---

## 3. Make the checkpoint shmem protocol more robust

**Problem.** The current IPC is a 2-byte header (flag + u8 bucket) followed by a raw
struct snapshot.  This has two bugs:
- The discriminant bucket is capped at 255 (`as u8`), so programs with max_fillhead > 255
  silently truncate the bucket index and map all large values onto slot 255.
- The parent and burst child both write the same shmem region concurrently (no lock);
  a partial write from the burst child can corrupt the parent's read.

**Action.**
- Extend the header to `[flag: u8][bucket_lo: u8][bucket_hi: u8]` (u16 LE for bucket).
  Update both writer and reader sides.  Checkpoint table size becomes `max_fillhead + 1`
  without the 255 cap.
- Add a generation counter (u16) at byte 3-4 so the parent can detect stale reads.
- In `checkpoint_burst`, zero the shmem region at the start of the child rather than
  just setting the flag; the parent should only read after `waitpid` returns.

---

## 4. Unify the analysis JSON artifacts

**Problem.** The pipeline produces three separate JSON files (`_weights.json`,
`_harness_heuristics.json`, `_zone_constraints.json`) that are each partially
redundant and must be kept in sync.  `ddg_goexplore.sh` checks for each separately.

**Action.**
- Add a `ddg analyze` command that runs `probe-adv`, `state-hash`, and `zones` in one
  pass and writes a single `<name>_analysis.json` with keys `weights`, `state_hash`,
  and `zones`.
- Update `prism-go-explore` to accept `--analysis <name>_analysis.json` instead of
  three separate flags.  Keep the three individual flags for backward compatibility.
- Update `ddg_goexplore.sh` to call the unified command.

**Benefit.** One artifact to manage, one command to run, no sync bugs.

---

## 5. Checkpoint quality: use discriminant-distance, not sub-accumulator sum

**Problem.** The current quality score sums sub-accumulator field values, which is a
reasonable proxy but has no direct relationship to "how close is this snapshot to
triggering the abort?".  Two snapshots with the same sub-accumulator sum can have very
different distances to the abort condition.

**Action.**
- Add a `discriminant_distance` field to the checkpoint entry: distance = max_fillhead −
  discriminant_value_at_snapshot.  Lower distance = better starting point for bursts.
- When selecting bursts under the `best` strategy, prefer the checkpoint with lowest
  discriminant_distance rather than highest bucket index.  (Highest bucket = closest, so
  currently equivalent, but the naming and intent become clearer.)
- For the `round-robin` strategy, weight checkpoint selection inversely by distance.

---

## 6. Adaptive zone tightening based on burst outcomes

**Problem.** Zone field constraints are computed once statically from ICmp thresholds.
They do not adapt to whether bursts from a given zone actually produce discriminant
advances.

**Action.**
- Track per-zone burst outcome counts: `advances` (burst_bucket > start_bucket) and
  `stalls` (burst_bucket == start_bucket or child exited without writing checkpoint).
- After every `burst_repeats` cycles, for zones with advance_rate < 20%, widen their
  field constraints by 10% (loosen the range).  For zones with advance_rate > 80%,
  tighten by 10%.
- Persist these adjusted constraints in the checkpoint table alongside the snapshot.
- This replaces the hardcoded 40% tightening factor in `zones.py` with a runtime-adaptive
  version.

---

## 7. Crash reproduction path

**Problem.** When a burst produces a crash, `checkpoint_burst` saves `snapshot + frames`
to `crashes/checkpoint_crash_bucket{N}`.  But this file is not directly replayable:
the caller needs to know they must restore the snapshot first, then feed the frames.
The existing fuzzer crash format (just raw frames) is also incompatible.

**Action.**
- Define a crash file format: a small JSON header `{schema: 1, type: "checkpoint_burst",
  struct_size: N, frame_size: M, frames: K}` followed by the raw bytes (snapshot then frames).
- Add a `prism-replay` binary to `icsprism/` that reads this format, calls
  `execute_testcase_from_checkpoint`, and optionally runs under AddressSanitizer or Valgrind.
- Add a `prism-minimize` wrapper that shrinks the frame sequence while preserving the crash.

---

## 8. Richer input field model: state-machine transitions

**Problem.** The current field model (`Bool`, `I16{targets}`, `Raw`) ignores the `Mode`
field pattern — a switch-dispatched state variable where only specific transition sequences
are valid.  The burst frame generator produces random Mode values that are never
reachable transitions, wasting most burst budget.

**Action.**
- In `probe-adv`, detect input fields that drive switch-dispatched state writes (from
  the store-guard analysis).  Emit a new model `"state_machine"` with the valid
  transition table.
- In `FieldValueModel`, add `StateMachine { transitions: Vec<(current: i16, next: i16)> }`.
- In burst frame generation, when a state machine field is present:
  read the current value from the snapshot, sample only valid successor values for
  that frame.

---

## 9. Structured seed corpus

**Problem.** Initial seeds are purely random bytes.  For multi-cycle ScanSequence mode
with 500 cycles, random seeds almost never satisfy the warmup conditions that cause
any state accumulation.

**Action.**
- Add a `prism-seed-gen` binary (or a `ddg seed` subcommand) that reads the
  accumulation chain from `_weights.json` and generates a sequence of frames designed
  to drive each chain variable past its threshold.  Strategy: for each chain link in
  order, set driver fields to their threshold+1 target value, inhibitors to 0, for
  `min_window` frames, then continue.
- Feed these seeds as the initial corpus instead of `RandBytesGenerator`.
- This directly reduces the time to first checkpoint advance.

---

## 10. Eliminate `looks_boolish` name heuristic from Rust

**Problem.** `looks_boolish()` in `prism-go-explore/src/main.rs` checks field name
substrings to decide if a field is boolean.  This duplicates — and may contradict —
the Python `probe-adv` classification.  The correct model comes from the JSON.

**Action.**
- `probe-adv` already emits `"model": "bool"` for `i8`-typed fields.  When the
  `_weights.json` is present (which it always is for go-explore), derive the model
  solely from the JSON.
- Delete `looks_boolish` from Rust.
- In the DDG-only fallback path (no weights JSON), keep a simple heuristic but base it
  on `llvm_type == "i8" && size == 1` only, not field names.

---

## 11. Parallel burst workers

**Problem.** Each burst is a `fork` → wait cycle.  With `burst_repeats = 50` and
`rollout_frames = 128`, the burst phase is purely sequential despite most cycles being
CPU-bound.

**Action.**
- Replace the sequential burst loop with a `rayon` parallel iterator (or manual thread
  pool) that spawns up to N burst workers concurrently, where N = `num_cpus::get() - 1`.
- Each worker needs its own shmem region for the checkpoint IPC.  Allocate one
  `(chk_shmem, chk_ptr)` pair per worker at startup.
- Workers write results to a `Mutex<Vec<(burst_bucket, snapshot, quality)>>` channel;
  the main thread drains and updates the checkpoint table after the parallel batch.

---

## 12. Graceful degradation when analysis artifacts are missing

**Problem.** `ddg_goexplore.sh` exits if `_harness_heuristics.json` is absent.
`prism-go-explore` panics if the weights JSON is malformed.  Missing artifacts make
the tool unusable on new benchmarks even when a partial run is possible.

**Action.**
- In `ddg_goexplore.sh`: if `_harness_heuristics.json` is missing, run `ddg state-hash`
  automatically (same pattern as zone constraints).
- In `prism-go-explore`: when `--weights-json` is absent or fails to parse, fall back
  to DDG-only field inference rather than panicking.
- When `--zone-constraints` is absent, fall back to uniform burst frame generation
  (the empty `field_constraints` map path already exists — just make it the default).
- Print a clear `[goexplore] WARNING: running without <X>, quality may be lower` rather
  than exiting.

---

## 13. Coverage map collision reduction

**Problem.** The SanitizerCoverage bitmap is fixed at 65536 bytes for all programs.
For programs with more than ~32K basic blocks, PC guard indices wrap modulo 65536,
causing collisions that mask coverage progress.

**Action.**
- Query the number of instrumented edges from the harness at startup: call
  `prism_struct_size()` or add a `prism_edge_count()` export from the harness.
  Alternatively, count non-zero slots in the map after a warm-up seed.
- Round the required map size up to the next power of two.  Cap at 1M bytes
  (LibAFL's practical limit for `HitcountsMapObserver`).
- Make `COV_MAP_SIZE` a runtime constant rather than a compile-time constant.
  This requires allocating the shmem dynamically and updating the SanitizerCoverage
  callbacks to read the size from a global rather than a literal.

---

## 14. Checkpoint persistence across restarts

**Problem.** All checkpoints are in-process memory and are lost when the fuzzer exits.
Resuming a long run from scratch loses all accumulated state.

**Action.**
- At startup, scan `crashes/checkpoints/` for files named `checkpoint_bucket{N}.bin`
  and load them into the checkpoint table.
- After each table update (new or quality-upgraded entry), atomically write the snapshot
  to `crashes/checkpoints/checkpoint_bucket{N}.bin`.
- Use a simple binary format: 4-byte magic, 4-byte bucket, 4-byte quality, then the raw
  snapshot bytes.  Loading is a directory scan on startup.
