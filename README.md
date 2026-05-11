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

# Run prism-cov with config
PRISM_LIB_DIR=/workspaces/ICSPrism/benchmarks/out/abort_oracle \
PRISM_LIB_NAME=abort_oracle \
cargo run --bin prism-cov --manifest-path icsprism/Cargo.toml -- \
  --config /workspaces/ICSPrism/icsprism/prism-fuzz.toml \
  --crashes /workspaces/ICSPrism/benchmarks/out/abort_oracle/crashes_cov

# Run prism-ddg with config
PRISM_LIB_DIR=/workspaces/ICSPrism/benchmarks/out/abort_oracle \
PRISM_LIB_NAME=abort_oracle \
cargo run --bin prism-ddg --manifest-path icsprism/Cargo.toml -- \
  --ddg /workspaces/ICSPrism/benchmarks/out/abort_oracle/abort_oracle_ddg.json \
  --layout /workspaces/ICSPrism/benchmarks/out/abort_oracle/abort_oracle_layout.json \
  --config /workspaces/ICSPrism/icsprism/prism-fuzz.toml \
  --crashes /workspaces/ICSPrism/benchmarks/out/abort_oracle/crashes_ddg
```

Abort oracle (brief):
- Benchmarks can declare `{external} FUNCTION prism_bug_abort_if : DINT` and call it at a manually injected bug condition.
- The generated harness provides this symbol; when called with `should_abort != 0`, it triggers `__builtin_trap()`.
- Fuzzers record that trap as a crash objective, giving a simple ASAN-like bug signal without modifying RuSTy.
