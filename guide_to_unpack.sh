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

# % Say that this warning is normal in the screen:
# Number of words found in event X: Y (for the central_CTS FPGA: c001), 
# while the expected is Y (provided by the 1st word of the event)
# aborting...
# Este es el origen del cambio en el unpacker. Una FPGA del TRB3 no funciona
# y João ha modificado el unpacker para que funcione, pero dejando este warning — todo ok.

filename=$(basename "$next_hld")
echo "Moving $filename to unpack queue"
mv "$next_hld" "$HLD_UNPACK_DIR/$filename"

cd "$PROJECT_ROOT"
source venv/bin/activate
python unpacker/unpackAll.py
