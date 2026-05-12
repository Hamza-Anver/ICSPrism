# Copilot instructions for ICSPrism

## Scope and repository layout
- Primary active code is in `icsprism/` (workspace with `ir-analysis`, `prism-runtime`, `prism-cov`, `prism-ddg`, `prism-sanity`).
- `rusty/` is a Git submodule (`.gitmodules`) and is treated as an upstream dependency used to produce `./rusty/target/debug/plc`, which the local scripts call.

## Build, test, and lint commands
Run commands from repository root unless noted.

| Task | Command |
| --- | --- |
| Build all ICSPrism crates | `cargo build --manifest-path icsprism/Cargo.toml` |
| Build one crate | `cargo build --manifest-path icsprism/Cargo.toml -p ir-analysis` |
| Build one binary | `cargo build --manifest-path icsprism/Cargo.toml --bin prism-analyze` |
| Run all tests in ICSPrism workspace | `cargo test --manifest-path icsprism/Cargo.toml --workspace` |
| Run a single test | `cargo test --manifest-path icsprism/Cargo.toml -p ir-analysis <test_name> -- --exact` |
| Lint | `cargo clippy --manifest-path icsprism/Cargo.toml --workspace --all-targets` |
| Format | `cargo fmt --all --manifest-path icsprism/Cargo.toml` |

Existing helper scripts for end-to-end compilation/fuzzing prep:

- `scripts/compile_ll_bc.sh <file.st> <output_dir>`: ST -> `.bc` and `.ll`
- `scripts/compile_o_so.sh <file.st> <output_dir>`: ST -> `.bc`/`.ll` -> instrumented `.o` -> `.so`
- `scripts/compile_all.sh <file.st> <output_dir>`: adds `prism-analyze` output (`*_layout.json`, `*_ddg.json`, `*_ddg.dot`)
- `scripts/stc.sh <file.st> <output_dir> [program_name]`: adds harness generation and links shared library with harness
- `scripts/stc_then_fuzz.sh <st_file_or_name> <prism-cov|prism-ddg|prism-sanity> [-- <fuzzer args...>]`: convenience wrapper that resolves `benchmarks/*.st`, runs `stc.sh`, sets `PRISM_LIB_DIR`/`PRISM_LIB_NAME`, then starts selected tool

Runtime/config layer:

- `icsprism/prism-runtime`: shared execution/config crate used by `prism-cov` and `prism-ddg`
- Supports `ExecutionMode::{SingleCycle, ScanSequence}` and shared required-input sizing
- Loads config from `--config <path>` or local `prism-fuzz.toml`, then falls back to defaults

## High-level architecture
ICSPrism is an LLVM-IR-driven fuzzing pipeline around Structured Text programs.

1. ST compilation stage: scripts call `./rusty/target/debug/plc` to generate LLVM IR (`.ll`) and bitcode (`.bc`) from `.st`.
2. IR analysis stage (`icsprism/ir-analysis`):
   - `prism-analyze` parses IR with inkwell and emits:
     - struct layout JSON (`*_layout.json`)
     - DDG graph JSON (`*_ddg.json`)
     - DDG DOT graph (`*_ddg.dot`)
   - `prism-harness` consumes layout JSON and emits C harness code exposing a stable `prism_*` ABI.
3. Harness/shared-library stage: scripts compile IR + generated C harness into `lib<name>.so`.
4. Fuzzing stage:
   - `prism-cov`: coverage-guided fuzzer; now uses `prism-runtime` for shared harness execution and config loading.
   - `prism-ddg`: DDG-biased fuzzer; now uses `prism-runtime` for shared harness execution and config loading.
   - `prism-sanity`: ABI/scan-cycle sanity checker against generated harness libraries.
   - All three dynamically link against the generated `.so` via `PRISM_LIB_DIR` and `PRISM_LIB_NAME` (from each crate’s `build.rs`).

## Key codebase conventions
- Layout JSON is a top-level array of program layouts; `prism-ddg` currently uses the **last entry** as the top-level program struct.
- Fuzzable fields are consistently filtered to exclude:
  - `__vtable`
  - nested struct-typed fields (`llvm_type` starting with `%`)
  - pointers (`ptr`) where treated as state/internal fields
- Scan-execution defaults are behavior-safe:
  - default mode is `single_cycle`
  - sequence mode (`scan_sequence`) is opt-in through config
- Output naming is stable and script-driven:
  - `<prefix>_layout.json`, `<prefix>_ddg.json`, `<prefix>_ddg.dot`
  - generated harness source `<name>_harness.c`
  - runtime shared object `lib<name>.so`
- `prism-cov` and `prism-ddg` implement SanitizerCoverage hooks in-process and share a fixed coverage map size (`MAP_SIZE = 65536`).
- `build.rs` in `prism-cov`, `prism-ddg`, and `prism-sanity` requires:
  - `PRISM_LIB_DIR` = directory containing `lib<name>.so`
  - `PRISM_LIB_NAME` = library basename without `lib` prefix / `.so` suffix
