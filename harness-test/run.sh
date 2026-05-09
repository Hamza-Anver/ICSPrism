#!/bin/bash
# harness-test/run.sh
WORKSPACE=$(cd "$(dirname "$0")/.." && pwd)
LIB_DIR="$WORKSPACE/benchmarks/out"

RUSTFLAGS="-L $LIB_DIR -l dylib=harness_test -C link-arg=-Wl,-rpath,$LIB_DIR" \
    cargo run --bin harness-test