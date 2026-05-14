#!/bin/bash
# Usage: ddg_state.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]
#
# Full pipeline for prism-ddg-state:
#   1. Compile ST → shared library + harness (stc.sh)
#   2. Generate byte-weight + input-field guide  (probe_ddg_adv.py)
#   3. Generate state-hash config               (ddg_state_hash_heuristics.py)
#   4. Launch prism-ddg-state with both configs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
    echo "Usage: ddg_state.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]"
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
    echo "[ddg_state] Could not find ST file: $INPUT"
    exit 1
fi

OUTDIR="benchmarks/out"
NAME="$(basename "$ST_PATH" .st)"
TARGET="$OUTDIR/$NAME"

echo "[ddg_state] Preparing target: $NAME"

if [[ -z "${LLVM_SYS_211_PREFIX:-}" ]]; then
    export LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix 2>/dev/null || true)
fi

"$ROOT/scripts/stc.sh" "$ST_PATH" "$OUTDIR"

export PRISM_LIB_DIR="$ROOT/$TARGET"
export PRISM_LIB_NAME="$NAME"

WEIGHTS_JSON="$TARGET/${NAME}_weights.json"
STATE_HASH_JSON="$TARGET/${NAME}_state_hash.json"

echo "[ddg_state] Generating input-field weights..."
python3 "$ROOT/tools/ddg_analysis/probe_ddg_adv.py" \
    "$TARGET/${NAME}_ddg.json" \
    "$TARGET/${NAME}_layout.json" \
    --json "$WEIGHTS_JSON"

echo "[ddg_state] Generating state-hash config..."
python3 "$ROOT/tools/ddg_analysis/ddg_state_hash_heuristics.py" \
    "$TARGET/${NAME}_ddg.json" \
    "$TARGET/${NAME}_layout.json" \
    --json "$STATE_HASH_JSON"

CMD=(cargo run --bin prism-ddg-state --manifest-path "$ROOT/icsprism/Cargo.toml" --
     --ddg     "$TARGET/${NAME}_ddg.json"
     --layout  "$TARGET/${NAME}_layout.json"
     --weights-json "$WEIGHTS_JSON"
     --state-hash   "$STATE_HASH_JSON")

if [[ -n "$CONFIG_PATH" ]]; then
    CMD+=(--config "$CONFIG_PATH")
fi
CMD+=("$@")

echo "[ddg_state] PRISM_LIB_DIR=$PRISM_LIB_DIR"
echo "[ddg_state] PRISM_LIB_NAME=$PRISM_LIB_NAME"
echo "[ddg_state] Running: ${CMD[*]}"
"${CMD[@]}"
