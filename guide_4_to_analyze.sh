#!/bin/bash

set -euo pipefail

# Create a usage function
usage() {
    echo "Usage: $0 [--help|-h] [--save] [--save-dir <path>]"
    echo ""
    echo "This script analyzes the unpacked HLD files."
    echo ""
    echo "Arguments:"
    echo "  --help, -h    Show this help message"
    echo "  --save        Save the generated plots (default: do not save)"
    echo "  --save-dir <path>  Directory to save plots (default: DATA_FILES/DATA/PDF)"
    exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
fi

# --------------------------------------------------------------------------------------------
# Prevent the script from running multiple instances -----------------------------------------
# --------------------------------------------------------------------------------------------

# Variables
script_name=$(basename "$0")
script_args="$*"
current_pid=$$

for pid in $(ps -eo pid,cmd | grep "[b]ash *$script_name" | grep -v "bin/bash -c" | awk '{print $1}'); do
    if [[ "$pid" != "$current_pid" ]]; then
        cmdline=$(ps -p "$pid" -o args=)
        echo "$(date) - Found running process: PID $pid - $cmdline"
        if [[ "$cmdline" == *"$script_name"* ]]; then
            echo "------------------------------------------------------"
            echo "$(date): The script $script_name is already running (PID: $pid). Exiting."
            echo "------------------------------------------------------"
            exit 1
        fi
    fi
done


PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

DEFAULT_SAVE_DIR="$PROJECT_ROOT/DATA_FILES/DATA/PDF"
SAVE_FLAG=false
SAVE_DIR="$DEFAULT_SAVE_DIR"

usage() {
    echo "Usage: $0 [--save] [--save-dir <path>]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)
            SAVE_FLAG=true
            shift
            ;;
        --save-dir)
            [[ $# -ge 2 ]] || usage
            SAVE_DIR="$2"
            SAVE_FLAG=true
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done



# Expected env:
#   PROJECT_ROOT   (required)
#   SAVE_FLAG      (optional, "true" to enable saving)
#   SAVE_DIR       (optional, dir to save plots when SAVE_FLAG=true)

: "${PROJECT_ROOT:?Environment variable PROJECT_ROOT must be set}"

MST_SAVES_DIR="$PROJECT_ROOT/MST_saves"
UNPACKED_DIR="$PROJECT_ROOT/DATA_FILES/DATA/UNPACKED/UNPROCESSED"
PROCESSING_DIR="$PROJECT_ROOT/DATA_FILES/DATA/UNPACKED/PROCESSING"

# --- helpers -----------------------------------------------------------------

err() { echo "Error: $*" >&2; exit 1; }
warn() { echo "Warning: $*" >&2; }

# Extracts an epoch seconds from a directory base name that ends with _YYYY-MM-DD_HHhMMmSSs
# Returns epoch on stdout; empty if pattern not found or conversion fails.
to_epoch() {
  local name="$1"
  # Pull the final timestamp group: _YYYY-MM-DD_HHhMMmSSs at the end
  if [[ "$name" =~ _([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2})h([0-9]{2})m([0-9]{2})s$ ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local hh="${BASH_REMATCH[2]}"
    local mm="${BASH_REMATCH[3]}"
    local ss="${BASH_REMATCH[4]}"
    local iso="${date_part} ${hh}:${mm}:${ss}"
    # GNU date:
    date -d "$iso" +%s 2>/dev/null || true
  else
    echo ""
  fi
}

# --- checks ------------------------------------------------------------------

[[ -d "$MST_SAVES_DIR" ]] || err "MST_saves directory does not exist: $MST_SAVES_DIR"

mkdir -p "$UNPACKED_DIR" "$PROCESSING_DIR"

# --- 1) Move everything from MST_saves -> UNPACKED/UNPROCESSED --------------

shopt -s nullglob dotglob
moved_any=false
for entry in "$MST_SAVES_DIR"/*; do
  base="$(basename "$entry")"
  target="$UNPACKED_DIR/$base"

  if [[ -e "$target" ]]; then
    warn "Target already exists in UNPROCESSED, skipping: $base"
    continue
  fi

  if mv "$entry" "$target"; then
    moved_any=true
  else
    warn "Failed to move: $entry"
  fi
done
shopt -u nullglob dotglob

# Not a hard error if nothing moved; there may already be backlog in UNPROCESSED
if [[ "$moved_any" == false ]]; then
  echo "Info: nothing moved from MST_saves (possibly empty or all names already present)."
fi

# --- 2) Select the oldest directory in UNPACKED/UNPROCESSED by embedded timestamp

mapfile -t candidates < <(find "$UNPACKED_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if [[ ${#candidates[@]} -eq 0 ]]; then
  err "No directories found in UNPACKED/UNPROCESSED."
fi

oldest_epoch=""
oldest_name=""

for base in "${candidates[@]}"; do
  epoch="$(to_epoch "$base")"
  if [[ -z "$epoch" ]]; then
    warn "Skipping (no timestamp suffix): $base"
    continue
  fi
  if [[ -z "$oldest_epoch" || "$epoch" -lt "$oldest_epoch" ]]; then
    oldest_epoch="$epoch"
    oldest_name="$base"
  fi
done

if [[ -z "$oldest_name" ]]; then
  err "No directories with a valid _YYYY-MM-DD_HHhMMmSSs suffix found in UNPROCESSED."
fi

echo "Selected oldest directory: $oldest_name (epoch $oldest_epoch)"

SOURCE_DIR="$UNPACKED_DIR/$oldest_name"
TARGET_DIR="$PROCESSING_DIR/$oldest_name"

if [[ -e "$TARGET_DIR" ]]; then
  warn "Target already exists in PROCESSING, skipping move: $TARGET_DIR"
else
  mv "$SOURCE_DIR" "$TARGET_DIR" || err "Failed to move directory to PROCESSING."
fi

# --- 3) Run MATLAB on the selected directory ---------------------------------

MATLAB_SCRIPT="run('DATA_FILES/SCRIPTS/Backbone/caye_edits_minimal.m')"

# Default SAVE_FLAG to false if unset
SAVE_FLAG="${SAVE_FLAG:-false}"

if command -v matlab >/dev/null 2>&1; then
  if [[ "$SAVE_FLAG" == "true" ]]; then
    : "${SAVE_DIR:?SAVE_FLAG=true but SAVE_DIR not set}"
    # Escape single quotes for MATLAB string literal
    ESCAPED_DIR="${SAVE_DIR//\'/\'\'}"
    matlab -batch "save_plots=true; save_plots_dir='${ESCAPED_DIR}'; input_dir='${oldest_name}'; ${MATLAB_SCRIPT}"
  else
    matlab -batch "input_dir='${oldest_name}'; ${MATLAB_SCRIPT}"
  fi
else
  err "matlab not found in PATH."
fi
