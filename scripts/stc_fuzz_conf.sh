#!/bin/bash
# Usage: stc_fuzz_conf.sh <st_file_or_name> <prism-cov|prism-ddg|prism-ddg-not-dumb|prism-sanity> <config_file> [-- <fuzzer args...>]
# Examples:
#   ./scripts/stc_fuzz_conf.sh pump_controller prism-cov icsprism/prism-fuzz.toml
#   ./scripts/stc_fuzz_conf.sh benchmarks/pump_controller.st prism-ddg icsprism/prism-fuzz-pump-seq.toml -- --seeds 64

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: stc_fuzz_conf.sh <st_file_or_name> <prism-cov|prism-ddg|prism-ddg-not-dumb|prism-sanity> <config_file> [-- <fuzzer args...>]"
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

INPUT="$1"
STRATEGY="$2"
CONFIG_PATH="$3"
shift 3

if [[ "${1:-}" == "--" ]]; then
    shift
fi

resolve_st_path() {
    local input="$1"
    if [[ -f "$input" ]]; then
        printf '%s\n' "$input"
    elif [[ -f "benchmarks/$input" ]]; then
        printf '%s\n' "benchmarks/$input"
    elif [[ -f "benchmarks/$input.st" ]]; then
        printf '%s\n' "benchmarks/$input.st"
    else
        return 1
    fi
}

if ! ST_PATH="$(resolve_st_path "$INPUT")"; then
    echo "Could not find ST file: $INPUT (tried direct path and benchmarks/)"
    exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Config file not found: $CONFIG_PATH"
    exit 1
fi

OUTDIR="benchmarks/out"
NAME="$(basename "$ST_PATH" .st)"
TARGET="$OUTDIR/$NAME"

if [[ -z "${LLVM_SYS_211_PREFIX:-}" ]] && command -v llvm-config-21 >/dev/null 2>&1; then
    export LLVM_SYS_211_PREFIX
    LLVM_SYS_211_PREFIX="$(llvm-config-21 --prefix)"
fi

echo "[stc_fuzz_conf] Compiling $ST_PATH with stc.sh"
"$ROOT/scripts/stc.sh" "$ST_PATH" "$OUTDIR"

export PRISM_LIB_DIR="$ROOT/$TARGET"
export PRISM_LIB_NAME="$NAME"

case "$STRATEGY" in
    prism-cov)
        CMD=(
            cargo run --bin prism-cov --manifest-path "$ROOT/icsprism/Cargo.toml" --
            --config "$CONFIG_PATH"
            "$@"
        )
        ;;
    prism-ddg)
        CMD=(
            cargo run --bin prism-ddg --manifest-path "$ROOT/icsprism/Cargo.toml" --
            --ddg "$TARGET/${NAME}_ddg.json"
            --layout "$TARGET/${NAME}_layout.json"
            --config "$CONFIG_PATH"
            "$@"
        )
        ;;
    prism-ddg-not-dumb)
        CMD=(
            cargo run --bin prism-ddg-not-dumb --manifest-path "$ROOT/icsprism/Cargo.toml" --
            --ddg "$TARGET/${NAME}_ddg.json"
            --layout "$TARGET/${NAME}_layout.json"
            --config "$CONFIG_PATH"
            "$@"
        )
        ;;
    prism-sanity)
        echo "[stc_fuzz_conf] NOTE: prism-sanity does not use --config; running without config."
        CMD=(cargo run --bin prism-sanity --manifest-path "$ROOT/icsprism/Cargo.toml" -- "$@")
        ;;
    *)
        echo "Unknown strategy: $STRATEGY (expected prism-cov, prism-ddg, prism-ddg-not-dumb, or prism-sanity)"
        exit 1
        ;;
esac

echo "[stc_fuzz_conf] PRISM_LIB_DIR=$PRISM_LIB_DIR"
echo "[stc_fuzz_conf] PRISM_LIB_NAME=$PRISM_LIB_NAME"
echo "[stc_fuzz_conf] CONFIG=$CONFIG_PATH"
echo "[stc_fuzz_conf] Running: ${CMD[*]}"
"${CMD[@]}"
