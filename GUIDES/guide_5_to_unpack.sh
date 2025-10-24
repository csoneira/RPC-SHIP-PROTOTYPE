#!/bin/bash

# set -euo pipefail

# --------------------------------------------------------------------------------------------
# Usage helper
# --------------------------------------------------------------------------------------------

show_usage() {
  cat <<EOF
Usage: $0 [--help|-h] [--all|-a]

Moves HLD files from the source directory into the unpack queue and invokes the unpacker.

Options:
  --help, -h    Show this help message and exit.
  --all,  -a    Process every .hld found in the source directory sequentially.
EOF
}

PROCESS_ALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_usage
      exit 0
      ;;
    --all|-a)
      PROCESS_ALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_usage
      exit 1
      ;;
  esac
done

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
HLD_ROOT="$PROJECT_ROOT/DATA_FILES/DATA/HLD_FILES"
HLD_SOURCE_DIR="$HLD_ROOT/NOT_UNPACKED"
HLD_SENT_DIR="$HLD_ROOT/SENT_TO_UNPACKING"
HLD_UNPACK_DIR="$PROJECT_ROOT/unpacker/hlds_toUnpack"
UNPACKED_OUTPUT_DIR="$PROJECT_ROOT/unpacker/unpackedFiles"
IDLE_DIR="$HLD_ROOT/IDLE_IN_UNPACKING_DIR"

mkdir -p "$HLD_SOURCE_DIR" "$HLD_UNPACK_DIR" "$UNPACKED_OUTPUT_DIR" "$IDLE_DIR" "$HLD_SENT_DIR"

# Ensure unpacking staging directories start clean
rm -f "$HLD_UNPACK_DIR"/*
rm -f "$UNPACKED_OUTPUT_DIR"/*

move_idle_contents() {
  shopt -s nullglob
  local contents=("$HLD_UNPACK_DIR"/*)
  if (( ${#contents[@]} > 0 )); then
    echo "Moving residual files from unpacking directory to IDLE storage."
    mv "${contents[@]}" "$IDLE_DIR/"
  fi
  shopt -u nullglob
}

process_single_hld() {
  local hld_path="$1"
  local filename
  filename=$(basename "$hld_path")

  move_idle_contents

  echo "Moving $filename to unpack queue"
  if [[ -f "$HLD_SENT_DIR/$filename" ]]; then
    echo "Copy in SENT_TO_UNPACKING exists; overwriting with latest copy."
  fi
  cp -a "$hld_path" "$HLD_SENT_DIR/"
  mv "$hld_path" "$HLD_UNPACK_DIR/$filename"

  cd "$PROJECT_ROOT"
  source venv/bin/activate
  python unpacker/unpackAll.py
}

process_next_hld() {
  local next_hld
  next_hld=$(find "$HLD_SOURCE_DIR" -maxdepth 1 -type f -name '*.hld' -printf '%T@ %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)

  if [[ -z "$next_hld" ]]; then
      echo "No HLD files available in $HLD_SOURCE_DIR"
      return 1
  fi

  process_single_hld "$next_hld"
  return 0
}

if [[ "$PROCESS_ALL" == "true" ]]; then
  processed_count=0
  while process_next_hld; do
    ((processed_count++))
  done
  if (( processed_count == 0 )); then
    echo "No HLD files processed."
  else
    echo "Processed $processed_count HLD file(s)."
  fi
else
  process_next_hld || exit 0
fi
