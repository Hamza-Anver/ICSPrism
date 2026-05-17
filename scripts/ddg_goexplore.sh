#!/bin/bash
# Usage: ddg_goexplore.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]
#
# Full pipeline for prism-go-explore:
#   1. Compile ST → shared library + harness (stc.sh)
#   2. Generate byte-weight + input-field guide (python3 -m ddg probe-adv)
#   3. Launch prism-go-explore with weights, state-hash, and zone constraints
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
    echo "Usage: ddg_goexplore.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]"
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
    echo "[goexplore] Could not find ST file: $INPUT"
    exit 1
fi

OUTDIR="benchmarks/out"
NAME="$(basename "$ST_PATH" .st)"
TARGET="$OUTDIR/$NAME"

echo "[goexplore] Preparing target: $NAME"

if [[ -z "${LLVM_SYS_211_PREFIX:-}" ]]; then
    export LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix 2>/dev/null || true)
fi

"$ROOT/scripts/stc.sh" "$ST_PATH" "$OUTDIR"

export PRISM_LIB_DIR="$ROOT/$TARGET"
export PRISM_LIB_NAME="$NAME"

WEIGHTS_JSON="$TARGET/${NAME}_weights.json"
STATE_HASH_JSON="$TARGET/${NAME}_harness_heuristics.json"
ZONE_CONSTRAINTS_JSON="$TARGET/${NAME}_zone_constraints.json"

echo "[goexplore] Generating input-field weights..."
PYTHONPATH="$ROOT/tools" python3 -m ddg probe-adv \
    "$TARGET/${NAME}_ddg.json" \
    "$TARGET/${NAME}_layout.json" \
    --json "$WEIGHTS_JSON"

if [[ ! -f "$STATE_HASH_JSON" ]]; then
    echo "[goexplore] Missing harness heuristics JSON: $STATE_HASH_JSON"
    exit 1
fi

# Auto-generate zone constraints if not already present.
if [[ ! -f "$ZONE_CONSTRAINTS_JSON" ]]; then
    echo "[goexplore] Zone constraints not found — auto-generating from weights + layout..."
    PYTHONPATH="$ROOT/tools" python3 -m ddg zones \
        "$WEIGHTS_JSON" \
        "$TARGET/${NAME}_layout.json" \
        --output "$ZONE_CONSTRAINTS_JSON"
fi
echo "[goexplore] Zone constraints: $ZONE_CONSTRAINTS_JSON"

CMD=(cargo run --bin prism-go-explore --manifest-path "$ROOT/icsprism/Cargo.toml" --
     --ddg     "$TARGET/${NAME}_ddg.json"
     --layout  "$TARGET/${NAME}_layout.json"
     --weights-json "$WEIGHTS_JSON"
     --state-hash   "$STATE_HASH_JSON"
     --zone-constraints "$ZONE_CONSTRAINTS_JSON")

if [[ -n "$CONFIG_PATH" ]]; then
    CMD+=(--config "$CONFIG_PATH")
fi
CMD+=("$@")

echo "[goexplore] PRISM_LIB_DIR=$PRISM_LIB_DIR"
echo "[goexplore] PRISM_LIB_NAME=$PRISM_LIB_NAME"
echo "[goexplore] Running: ${CMD[*]}"
"${CMD[@]}"
