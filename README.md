To build RuSTy:

Using a weird docker setup rn

```bash
LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix) cargo build
```

Or to set in environment:

```bash
export LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix)
```

Quick run commands:

```bash
# Build all ICSPrism crates
cargo build --manifest-path icsprism/Cargo.toml

# Compile an ST benchmark to lib + analysis artifacts
./scripts/stc.sh benchmarks/abort_oracle.st benchmarks/out

# Compile + run prism-cov with config (single command)
./scripts/stc_fuzz_conf.sh abort_oracle prism-cov icsprism/prism-fuzz.toml -- \
  --crashes /workspaces/ICSPrism/benchmarks/out/abort_oracle/crashes_cov

# Compile + run prism-ddg with config (single command)
./scripts/stc_fuzz_conf.sh abort_oracle prism-ddg icsprism/prism-fuzz.toml -- \
  --crashes /workspaces/ICSPrism/benchmarks/out/abort_oracle/crashes_ddg

# Stateful sequence example
./scripts/stc_fuzz_conf.sh pump_controller prism-cov icsprism/prism-fuzz-pump-seq.toml -- \
  --seeds 256 --crashes /workspaces/ICSPrism/benchmarks/out/pump_controller/crashes_cov_seq
```

Abort oracle (brief):
- Benchmarks can declare `{external} FUNCTION prism_bug_abort_if : DINT` and call it at a manually injected bug condition.
- The generated harness provides this symbol; when called with `should_abort != 0`, it triggers `__builtin_trap()`.
- Fuzzers record that trap as a crash objective, giving a simple ASAN-like bug signal without modifying RuSTy.
