#!/bin/bash
# Usage: ddg_not_dumb.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
    echo "Usage: ddg_not_dumb.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]"
    exit 1
fi

INPUT="$1"
shift || true

CONFIG_PATH=""
if [[ $# -ge 1 && "$1" != "--" && -f "$1" ]]; then
    CONFIG_PATH="$1"
    shift
fi

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
    echo "Could not find ST file: $INPUT"
    exit 1
fi

OUTDIR="benchmarks/out"
NAME="$(basename "$ST_PATH" .st)"
TARGET="$OUTDIR/$NAME"

echo "[ddg_not_dumb] Preparing target: $NAME"

# Preserve LLVM env if set
if [[ -z "${LLVM_SYS_211_PREFIX:-}" ]]; then
    export LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix 2>/dev/null || true)
fi

"$ROOT/scripts/stc.sh" "$ST_PATH" "$OUTDIR"

export PRISM_LIB_DIR="$ROOT/$TARGET"
export PRISM_LIB_NAME="$NAME"

# Generate weights JSON using Python analyser
WEIGHTS_JSON="$TARGET/${NAME}_weights.json"
python3 "$ROOT/tools/probe_ddg_adv.py" "$TARGET/${NAME}_ddg.json" "$TARGET/${NAME}_layout.json" --json "$WEIGHTS_JSON"

CMD=(cargo run --bin prism-ddg-not-dumb --manifest-path "$ROOT/icsprism/Cargo.toml" --
     --ddg "$TARGET/${NAME}_ddg.json"
     --layout "$TARGET/${NAME}_layout.json"
     --weights-json "$WEIGHTS_JSON")

if [[ -n "$CONFIG_PATH" ]]; then
    CMD+=(--config "$CONFIG_PATH")
fi
CMD+=("$@")

echo "[ddg_not_dumb] PRISM_LIB_DIR=$PRISM_LIB_DIR"
echo "[ddg_not_dumb] PRISM_LIB_NAME=$PRISM_LIB_NAME"
echo "[ddg_not_dumb] Running: ${CMD[*]}"
"${CMD[@]}"
