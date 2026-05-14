#!/bin/bash
# Usage: stc.sh <file.st> <output_dir> [program_name]
set -e

ST=$1
OUTDIR=$2
PROGRAM_NAME=${3:-""}   # optional override

NAME=$(basename "$ST" .st)
PLC="./rusty/target/debug/plc"
ANALYZE="./icsprism/target/debug/prism-analyze"
HARNESS="./icsprism/target/debug/prism-harness"
TARGET="$OUTDIR/$NAME"
ABS_TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"

mkdir -p "$TARGET"

echo "[1/10] ST -> bitcode"
$PLC -g --bc --error-format clang -o "$TARGET/$NAME.bc" "$ST"

echo "[2/10] ST -> LLVM IR"
$PLC -g --ir --error-format clang -o "$TARGET/$NAME.ll" "$ST"

echo "[3/10] Building prism-analyze"
cargo build --bin prism-analyze --manifest-path ./icsprism/Cargo.toml -q

echo "[4/10] prism-analyze -> DDG + layout"
$ANALYZE "$TARGET/$NAME.ll" "$TARGET/$NAME"

echo "[5/10] Rendering DDG DOT"
python3 ./tools/ddg_to_dot.py "$TARGET/${NAME}_ddg.json" "$TARGET/${NAME}_ddg.dot"

echo "[6/10] Building prism-harness"
cargo build --bin prism-harness --manifest-path ./icsprism/Cargo.toml -q

# If no program name given, detect from layout JSON
if [[ -z "$PROGRAM_NAME" ]]; then
    PROGRAM_NAME=$(python3 -c "
import json
layouts = json.load(open('$TARGET/${NAME}_layout.json'))
print(layouts[-1]['struct_name'])
")
    echo "Detected program name: $PROGRAM_NAME"
fi

echo "[7/10] Generating C harness for $PROGRAM_NAME"
$HARNESS "$TARGET/${NAME}_layout.json" "$PROGRAM_NAME" "$TARGET/${NAME}_harness.c"

echo "[8/11] Saving harness heuristics JSON"
python3 ./tools/ddg_analysis/ddg_state_hash_heuristics.py \
    "$TARGET/${NAME}_ddg.json" \
    "$TARGET/${NAME}_layout.json" \
    --json "$TARGET/${NAME}_harness_heuristics.json"

echo "[9/11] Compiling IR -> instrumented object"
clang-21 -x ir "$TARGET/$NAME.ll" \
    -c -fsanitize-coverage=trace-pc-guard -g -O0 \
    -o "$TARGET/$NAME.o"

echo "[10/11] Compiling harness"
clang-21 "$TARGET/${NAME}_harness.c" \
    -c -g -O0 \
    -o "$TARGET/${NAME}_harness.o"

echo "[11/11] Linking -> shared library"
clang-21 "$TARGET/$NAME.o" "$TARGET/${NAME}_harness.o" \
    -shared -fPIC -g \
    -o "$TARGET/lib$NAME.so"

echo ""
echo "Output in $TARGET/"
ls -lh "$TARGET/"
echo "Program name: $PROGRAM_NAME"
echo "Run with:"
echo "  PRISM_LIB_DIR=$ABS_TARGET PRISM_LIB_NAME=$NAME cargo build --bin prism-cov --manifest-path icsprism/Cargo.toml"
