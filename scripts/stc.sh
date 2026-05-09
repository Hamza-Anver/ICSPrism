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

mkdir -p "$TARGET"

echo "[1/8] ST -> bitcode"
$PLC -g --bc --error-format clang -o "$TARGET/$NAME.bc" "$ST"

echo "[2/8] ST -> LLVM IR"
$PLC -g --ir --error-format clang -o "$TARGET/$NAME.ll" "$ST"

echo "[3/8] Building prism-analyze"
cargo build --bin prism-analyze --manifest-path ./icsprism/Cargo.toml -q

echo "[4/8] prism-analyze -> DDG + layout"
$ANALYZE "$TARGET/$NAME.ll" "$TARGET/$NAME"

echo "[5/8] Building prism-harness"
cargo build --bin prism-harness --manifest-path ./icsprism/Cargo.toml -q

# If no program name given, detect from layout JSON
if [[ -z "$PROGRAM_NAME" ]]; then
    PROGRAM_NAME=$(python3 -c "
import json
layouts = json.load(open('$TARGET/${NAME}_layout.json'))
print(layouts[-1]['struct_name'])
")
    echo "[5/8] Detected program name: $PROGRAM_NAME"
fi

echo "[5/8] Generating C harness for $PROGRAM_NAME"
$HARNESS "$TARGET/${NAME}_layout.json" "$PROGRAM_NAME" "$TARGET/${NAME}_harness.c"

echo "[6/8] Compiling IR -> instrumented object"
clang-21 -x ir "$TARGET/$NAME.ll" \
    -c -fsanitize-coverage=trace-pc-guard -g -O0 \
    -o "$TARGET/$NAME.o"

echo "[7/8] Compiling harness"
clang-21 "$TARGET/${NAME}_harness.c" \
    -c -g -O0 \
    -o "$TARGET/${NAME}_harness.o"

echo "[8/8] Linking -> shared library"
clang-21 "$TARGET/$NAME.o" "$TARGET/${NAME}_harness.o" \
    -shared -fPIC -g \
    -o "$TARGET/lib$NAME.so"

echo ""
echo "Output in $TARGET/"
ls -lh "$TARGET/"
echo "Program name: $PROGRAM_NAME"
echo "Run with:"
echo "  PRISM_LIB_DIR=/workspaces/ICSPrism/$TARGET PRISM_LIB_NAME=$NAME cargo build --bin prism-cov --manifest-path icsprism/Cargo.toml"