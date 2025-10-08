#!/bin/bash

# set -euo pipefail

# Create an usage message
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0"
  echo ""
  echo "This script moves the oldest .hld file from the source directory to the unpacking directory,"
  echo "then runs the unpacking process."
  echo ""
  echo "Arguments: None"
  exit 0
fi

# --------------------------------------------------------------------------------------------
# Prevent the script from running multiple instances -----------------------------------------
# --------------------------------------------------------------------------------------------

script_name=$(basename "$0")
lockfile="/tmp/${script_name}.lock"

# Acquire non-blocking lock on FD 9
exec 9>"$lockfile"
if ! flock -n 9; then
  echo "$(date): $script_name is already running. Exiting."
  exit 1
fi

# Optional: record PID in the lock (useful for debugging)
echo $$ 1>&9
# set -euo pipefail # Exit on error, undefined variable, or error in a pipeline
# IFS=$'\n\t' # Set IFS to handle spaces in filenames

# # Variables
# script_name=$(basename "$0")
# script_args="$*"
# current_pid=$$

# for pid in $(ps -eo pid,cmd | grep "[b]ash *$script_name*" | grep -v "bin/bash -c" | awk '{print $1}'); do
#     if [[ "$pid" != "$current_pid" ]]; then
#         cmdline=$(ps -p "$pid" -o args=)
#         # echo "$(date) - Found running process: PID $pid - $cmdline"
#         if [[ "$cmdline" == *"$script_name"* ]]; then
#             echo "------------------------------------------------------"
#             echo "$(date): The script $script_name is already running (PID: $pid). Exiting."
#             echo "------------------------------------------------------"
#             exit 1
#         fi
#     fi
# done


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
