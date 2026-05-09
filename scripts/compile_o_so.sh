#!/bin/bash
# Usage: stc.sh <file.st> <output_dir>
# Compiles an ST file to BC, LL, object, and instrumented shared library.

set -e

ST=$1
OUTDIR=$2
NAME=$(basename "$ST" .st)
PLC="./rusty/target/debug/plc"
TARGET="$OUTDIR/$NAME"

mkdir -p "$TARGET"

echo "[1/4] Compiling ST -> LLVM bitcode"
$PLC -g --bc --error-format clang -o "$TARGET/$NAME.bc" "$ST"

echo "[2/4] Compiling ST -> LLVM IR text"
$PLC -g --ir --error-format clang -o "$TARGET/$NAME.ll" "$ST"

echo "[3/4] Compiling IR -> instrumented object"
clang-21 -x ir "$TARGET/$NAME.ll" \
    -c \
    -fsanitize-coverage=trace-pc-guard \
    -g -O0 \
    -o "$TARGET/$NAME.o"

echo "[4/4] Linking -> shared library"
clang-21 "$TARGET/$NAME.o" \
    -shared -fPIC -g \
    -o "$TARGET/lib$NAME.so"

echo ""
echo "Output in $TARGET/"
ls -lh "$TARGET/"