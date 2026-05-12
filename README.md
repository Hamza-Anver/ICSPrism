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
./scripts/stc_prism_cov_fuzz benchmarks/harness_test_buggy.st
./scripts/stc_prism_ddg_fuzz benchmarks/harness_test_buggy.st
./scripts/stc_prism_cov_fuzz benchmarks/pump_controller.st icsprism/prism-fuzz.toml
```

Abort oracle (brief):
- Benchmarks can declare `{external} FUNCTION prism_bug_abort_if : DINT` and call it at a manually injected bug condition.
- The generated harness provides this symbol; when called with `should_abort != 0`, it triggers `__builtin_trap()`.
- Fuzzers record that trap as a crash objective, giving a simple ASAN-like bug signal without modifying RuSTy.
