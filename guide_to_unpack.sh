#!/bin/bash

set -euo pipefail

PROJECT_ROOT="/home/csoneira/WORK/LIP_stuff/JOAO_SETUP"
HLD_SOURCE_DIR="$PROJECT_ROOT/DATA_FILES/DATA/HLD_FILES"
HLD_UNPACK_DIR="$PROJECT_ROOT/unpacker/hlds_toUnpack"

mkdir -p "$HLD_SOURCE_DIR" "$HLD_UNPACK_DIR"

next_hld=$(find "$HLD_SOURCE_DIR" -maxdepth 1 -type f -name '*.hld' -printf '%T@ %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)

if [[ -z "$next_hld" ]]; then
    echo "No HLD files available in $HLD_SOURCE_DIR"
    exit 0
fi

filename=$(basename "$next_hld")
echo "Moving $filename to unpack queue"
mv "$next_hld" "$HLD_UNPACK_DIR/$filename"

cd "$PROJECT_ROOT"
source venv/bin/activate
python unpacker/unpackAll.py
