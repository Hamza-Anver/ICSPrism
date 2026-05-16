# Copilot instructions for ICSPrism

## What matters here
- Treat [icsprism/](icsprism) as the active workspace. The code you usually want is in `ir-analysis`, `prism-runtime`, `prism-cov`, `prism-ddg`, `prism-ddg-input`, and `prism-sanity`.
- Treat [rusty/](rusty) as an upstream submodule dependency unless the task explicitly concerns the compiler itself.
- Prefer linking to [README.md](README.md) for broad project context instead of restating it here.

## Build and validation
Run commands from the repository root unless the script says otherwise.

| Task | Command |
| --- | --- |
| Build the ICSPrism workspace | `cargo build --manifest-path icsprism/Cargo.toml` |
| Build one crate | `cargo build --manifest-path icsprism/Cargo.toml -p ir-analysis` |
| Build one binary | `cargo build --manifest-path icsprism/Cargo.toml --bin prism-analyze` |
| Test the workspace | `cargo test --manifest-path icsprism/Cargo.toml --workspace` |
| Lint | `cargo clippy --manifest-path icsprism/Cargo.toml --workspace --all-targets` |
| Format | `cargo fmt --all --manifest-path icsprism/Cargo.toml` |

- For RuSTy builds, set `LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix)` first; the README’s build note is the source of truth.
- Prefer the narrowest command that validates the touched slice. Use the workspace test/build commands above before broader checks.

## Workflow conventions
- Use the helper scripts in [scripts/](scripts) for end-to-end ST compilation and fuzzing flows: `compile_ll_bc.sh`, `compile_o_so.sh`, `compile_all.sh`, `stc.sh`, `stc_prism_cov_fuzz`, `stc_prism_ddg_fuzz`, and `stc_prism_ddg_input_fuzz`.
- `prism-runtime` owns shared execution and config loading for the fuzzers. Default execution mode is `SingleCycle`; switch to `scan_sequence` in config when a benchmark needs state to persist across cycles.
- Multi-cycle accumulator programs such as `pump_controller` are the main place this matters. If a fuzzing run stalls at baseline coverage, check the execution mode before changing analysis code.
- `prism-ddg-input` mutates compact input bytes, not the full PLC frame; keep field offset and layout JSON handling consistent with that model.

## Artifact and analysis conventions
- The common outputs are `<prefix>_layout.json`, `<prefix>_ddg.json`, `<prefix>_weights.json`, `<prefix>_harness.c`, and `lib<prefix>.so`.
- Layout JSON is an array; fuzzers use the last entry as the top-level program struct.
- DDG analysis lives in [tools/probe_ddg_adv.py](tools/probe_ddg_adv.py) and [tools/ddg_to_dot.py](tools/ddg_to_dot.py). Link to those tools instead of duplicating their logic here.
- `probe_ddg_adv.py` is the place to reason about control-flow guards, source-level field roles, and byte-weight generation.

## Editing rules
- Keep changes focused on the active crate or script path; avoid rewriting generated artifacts under `target/`.
- Preserve existing file and output naming conventions so the scripts and build scripts continue to line up.
- If a benchmark or fuzzer behavior looks off, inspect the local crate or script first before broadening the search.
