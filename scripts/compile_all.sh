#!/bin/bash
# Usage: compile_all.sh <file.st> <output_dir>
# Compiles an ST file to BC, LL, object, instrumented shared library,
# runs prism-analyze to produce DDG and layout JSON,
# then renders the DDG DOT file via python3 -m ddg to-dot.

set -e

ST=$1
OUTDIR=$2

if [[ -z "$ST" || -z "$OUTDIR" ]]; then
    echo "Usage: compile_all.sh <file.st> <output_dir>"
    exit 1
fi

NAME=$(basename "$ST" .st)
PLC="./rusty/target/debug/plc"
ANALYZE="./icsprism/target/debug/prism-analyze"
TARGET="$OUTDIR/$NAME"

mkdir -p "$TARGET"

echo "[1/6] Compiling ST -> LLVM bitcode"
$PLC -g --bc --error-format clang -o "$TARGET/$NAME.bc" "$ST"

echo "[2/6] Compiling ST -> LLVM IR text"
$PLC -g --ir --error-format clang -o "$TARGET/$NAME.ll" "$ST"

echo "[3/6] Compiling IR -> instrumented object"
clang-21 -x ir "$TARGET/$NAME.ll" \
    -c \
    -fsanitize-coverage=trace-pc-guard \
    -g -O0 \
    -o "$TARGET/$NAME.o"

echo "[4/6] Linking -> shared library"
clang-21 "$TARGET/$NAME.o" \
    -shared -fPIC -g \
    -o "$TARGET/lib$NAME.so"

echo "[5/6] Building prism-analyze (if needed)"
cargo build --bin prism-analyze --manifest-path ./icsprism/Cargo.toml

echo "[6/7] Running prism-analyze -> DDG + layout JSON"
$ANALYZE "$TARGET/$NAME.ll" "$TARGET/$NAME"

echo "[7/7] Rendering DDG DOT"
PYTHONPATH=./tools python3 -m ddg to-dot "$TARGET/${NAME}_ddg.json" "$TARGET/${NAME}_ddg.dot"

echo ""
echo "Output in $TARGET/"
ls -lh "$TARGET/"