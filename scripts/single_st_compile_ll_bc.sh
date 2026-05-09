
#!/bin/bash
# Usage: stc.sh <file.st> <output_dir>
 
ST=$1
OUTDIR=$2
NAME=$(basename "$ST" .st)
PLC="./rusty/target/debug/plc"
 
mkdir -p "$OUTDIR"
 
$PLC -g --bc --error-format clang -o "$OUTDIR/$NAME.bc" "$ST"
$PLC -g --ir --error-format clang -o "$OUTDIR/$NAME.ll" "$ST"
