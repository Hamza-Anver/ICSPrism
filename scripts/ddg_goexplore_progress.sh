#!/bin/bash
# ddg_goexplore_progress.sh — end-to-end launcher for prism-go-explore-progress.
#
# Extension of ddg_goexplore.sh: adds a `ddg stages` step that extracts
# Hierarchical Discriminant Sequence (HDS) progress stages from the compiled
# program's analysis artifacts and merges them into the zone constraints JSON.
# The progress stages provide Go-Explore checkpoint signal during the prerequisite
# phases (PRIME, FLOW, …) before the primary discriminant (FillHead) starts moving.
#
# Usage:
#   ddg_goexplore_progress.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]
#
# If the program has no multi-phase structure, stages extraction returns empty and
# prism-go-explore-progress runs identically to prism-go-explore.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
    echo "Usage: ddg_goexplore_progress.sh <st_file_or_name> [config_file] [-- <fuzzer args...>]"
    exit 1
fi

INPUT="$1"
shift || true

CONFIG_PATH=""
if [[ $# -ge 1 && "$1" != "--" && -f "$1" ]]; then
    CONFIG_PATH="$1"
    shift
fi
if [[ "${1:-}" == "--" ]]; then shift; fi

resolve_st_path() {
    local input="$1"
    if   [[ -f "$input" ]];              then printf '%s\n' "$input"
    elif [[ -f "benchmarks/$input" ]];   then printf '%s\n' "benchmarks/$input"
    elif [[ -f "benchmarks/$input.st" ]]; then printf '%s\n' "benchmarks/$input.st"
    else return 1; fi
}

if ! ST_PATH="$(resolve_st_path "$INPUT")"; then
    echo "[gxp] Could not find ST file: $INPUT"; exit 1
fi

OUTDIR="benchmarks/out"
NAME="$(basename "$ST_PATH" .st)"
TARGET="$OUTDIR/$NAME"

echo "[gxp] Preparing target: $NAME"

if [[ -z "${LLVM_SYS_211_PREFIX:-}" ]]; then
    export LLVM_SYS_211_PREFIX=$(llvm-config-21 --prefix 2>/dev/null || true)
fi

# ─── Step 1: compile ST → shared library + harness ───────────────────────────
"$ROOT/scripts/stc.sh" "$ST_PATH" "$OUTDIR"

export PRISM_LIB_DIR="$ROOT/$TARGET"
export PRISM_LIB_NAME="$NAME"

WEIGHTS_JSON="$TARGET/${NAME}_weights.json"
STATE_HASH_JSON="$TARGET/${NAME}_harness_heuristics.json"
ZONE_CONSTRAINTS_JSON="$TARGET/${NAME}_zone_constraints.json"
STAGES_JSON="$TARGET/${NAME}_stages.json"

# ─── Step 2: generate input-field weights ────────────────────────────────────
echo "[gxp] Generating input-field weights..."
PYTHONPATH="$ROOT/tools" python3 -m ddg probe-adv \
    "$TARGET/${NAME}_ddg.json" \
    "$TARGET/${NAME}_layout.json" \
    --json "$WEIGHTS_JSON"

if [[ ! -f "$STATE_HASH_JSON" ]]; then
    echo "[gxp] Missing harness heuristics — regenerating..."
    PYTHONPATH="$ROOT/tools" python3 -m ddg state-hash \
        "$TARGET/${NAME}_ddg.json" \
        "$TARGET/${NAME}_layout.json" \
        --json "$STATE_HASH_JSON"
fi

# ─── Step 3: generate zone constraints ───────────────────────────────────────
if [[ ! -f "$ZONE_CONSTRAINTS_JSON" ]]; then
    echo "[gxp] Zone constraints not found — auto-generating..."
    PYTHONPATH="$ROOT/tools" python3 -m ddg zones \
        "$WEIGHTS_JSON" \
        "$TARGET/${NAME}_layout.json" \
        --ddg        "$TARGET/${NAME}_ddg.json" \
        --state-hash "$STATE_HASH_JSON" \
        --output     "$ZONE_CONSTRAINTS_JSON"
fi

# ─── Step 4: extract HDS progress stages ─────────────────────────────────────
echo "[gxp] Extracting HDS progress stages..."
PYTHONPATH="$ROOT/tools" python3 -m ddg stages \
    "$STATE_HASH_JSON" \
    "$TARGET/${NAME}_layout.json" \
    --ddg     "$TARGET/${NAME}_ddg.json" \
    --weights "$WEIGHTS_JSON" \
    --output  "$STAGES_JSON"

# Merge progress_stages into zone_constraints.json so the fuzzer reads one file.
# If stages is empty, the merge is a no-op and the fuzzer runs as standard go-explore.
export ZONE_CONSTRAINTS_JSON STAGES_JSON
python3 - <<'PYEOF'
import json, os
zc_path = os.environ["ZONE_CONSTRAINTS_JSON"]
st_path = os.environ["STAGES_JSON"]
zc = json.load(open(zc_path))
st = json.load(open(st_path))
stages = st.get("progress_stages", [])
zc["progress_stages"] = stages
with open(zc_path, "w") as f:
    json.dump(zc, f, indent=2)
    f.write("\n")
print(f"[gxp] Merged {len(stages)} progress stage(s) into {zc_path}")
PYEOF

echo "[gxp] Zone constraints: $ZONE_CONSTRAINTS_JSON"

# ─── Step 5: launch prism-go-explore-progress ────────────────────────────────
CMD=(cargo run --bin prism-go-explore-progress --manifest-path "$ROOT/icsprism/Cargo.toml" --
     --ddg             "$TARGET/${NAME}_ddg.json"
     --layout          "$TARGET/${NAME}_layout.json"
     --weights-json    "$WEIGHTS_JSON"
     --state-hash      "$STATE_HASH_JSON"
     --zone-constraints "$ZONE_CONSTRAINTS_JSON")

if [[ -n "$CONFIG_PATH" ]]; then CMD+=(--config "$CONFIG_PATH"); fi
CMD+=("$@")

echo "[gxp] PRISM_LIB_DIR=$PRISM_LIB_DIR"
echo "[gxp] PRISM_LIB_NAME=$PRISM_LIB_NAME"
echo "[gxp] Running: ${CMD[*]}"
"${CMD[@]}"
