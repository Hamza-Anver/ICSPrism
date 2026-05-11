To build RuSTy:

Using a weird docker setup rn

```bash
LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix) cargo build
```

Or to set in environment:

```bash
export LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix)
```