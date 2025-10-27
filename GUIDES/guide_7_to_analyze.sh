#!/bin/bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [--help|-h] [--save] [--save-dir <path>] [--run|-r <1-5>] [--no-plot] [--debug|-d]

This script analyzes the unpacked HLD files.

Arguments:
  --help, -h           Show this help message
  --save               Save the generated plots (default: do not save)
  --save-dir <path>    Directory to save plots (default: STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/PDF)
  --no-plot            Skip all figure generation (only produce CSV output)
  --run, -r <1-5>      Analyze predefined test run number (enables test mode)
  --debug, -d          Enable verbose debug output inside MATLAB
EOF
    exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
fi

SELECTED_INPUT=""

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


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

DEFAULT_SAVE_DIR="$REPO_ROOT/STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/PDF"
SAVE_FLAG=false
NO_PLOT_FLAG=false
SAVE_DIR="$DEFAULT_SAVE_DIR"
RUN_OVERRIDE=""
SELECTED_INPUT=""
DEBUG_FLAG=false
CLI_ARGS=()

mkdir -p "$DEFAULT_SAVE_DIR"

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
        --no-plot)
            NO_PLOT_FLAG=true
            CLI_ARGS+=("--no-plot")
            shift
            ;;
        -r|--run)
            [[ $# -ge 2 ]] || usage
            RUN_OVERRIDE="$2"
            shift 2
            ;;
        --debug|-d)
            DEBUG_FLAG=true
            CLI_ARGS+=("--debug")
            shift
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

if [[ "$NO_PLOT_FLAG" == "true" ]]; then
    SAVE_FLAG=false
fi


MATLAB_SCRIPT="feval('run','STAGES/STAGE_7/SCRIPTS/caye_edits_minimal.m');"
MATLAB_WRAP="try, ${MATLAB_SCRIPT} catch ME, disp(getReport(ME,'extended')); exit(1); end"

JOINED_ROOT="$REPO_ROOT/STAGES/STAGE_6/DATA/DATA_FILES/JOINED"

# --- helpers -----------------------------------------------------------------

err() { echo "Error: $*" >&2; exit 1; }
warn() { echo "Warning: $*" >&2; }

# --- checks ------------------------------------------------------------------

if [[ ! -d "$JOINED_ROOT" ]]; then
  err "Joined data directory not found: $JOINED_ROOT"
fi

if [[ -n "$RUN_OVERRIDE" ]]; then
  echo "Run override provided: analyzing run ${RUN_OVERRIDE}."
  candidate="$JOINED_ROOT/RUN_${RUN_OVERRIDE}"
  [[ -d "$candidate" ]] || err "Run directory not found: $candidate"
  SELECTED_INPUT="$(cd "$candidate" && pwd)"
else
  echo "Selecting oldest joined run directory for analysis."
  mapfile -t candidates < <(find "$JOINED_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n)
  if [[ ${#candidates[@]} -eq 0 ]]; then
    err "No run directories found in $JOINED_ROOT."
  fi
  oldest_line="${candidates[0]}"
  SELECTED_INPUT="${oldest_line#* }"
  SELECTED_INPUT="$(cd "$SELECTED_INPUT" && pwd)"
fi

echo "Selected input directory: $SELECTED_INPUT"

# --- 3) Run MATLAB on the selected directory ---------------------------------
# Default SAVE_FLAG to false if unset
SAVE_FLAG="${SAVE_FLAG:-false}"

if [[ -z "$SELECTED_INPUT" ]]; then
  err "No input directory selected for analysis."
fi

ESCAPED_INPUT="${SELECTED_INPUT//\'/\'\'}"
if [[ -n "$RUN_OVERRIDE" ]]; then
  MATLAB_PREFIX="test=false; run=${RUN_OVERRIDE}; input_dir='${ESCAPED_INPUT}';"
else
  MATLAB_PREFIX="test=false; run=0; input_dir='${ESCAPED_INPUT}';"
fi

if [[ "$NO_PLOT_FLAG" == "true" ]]; then
  MATLAB_PREFIX+=" no_plot=true;"
fi

if [[ "$DEBUG_FLAG" == "true" ]]; then
  MATLAB_PREFIX+=" debug_mode=true;"
fi

if [[ "$NO_PLOT_FLAG" == "true" && " ${CLI_ARGS[*]} " != *" --no-plot "* ]]; then
  CLI_ARGS+=("--no-plot")
fi

if [[ "$DEBUG_FLAG" == "true" && " ${CLI_ARGS[*]} " != *" --debug "* ]]; then
  CLI_ARGS+=("--debug")
fi

if [[ ${#CLI_ARGS[@]} -gt 0 ]]; then
  cell_elems=()
  for arg in "${CLI_ARGS[@]}"; do
    escaped=${arg//\'/\'\'}
    cell_elems+=("'${escaped}'")
  done
  old_ifs=$IFS
  IFS=,
  joined="${cell_elems[*]}"
  IFS=$old_ifs
  MATLAB_PREFIX+=" caye_cli_args={${joined}};"
fi

if [[ "$DEBUG_FLAG" == "true" ]]; then
  echo "Debug logging enabled for MATLAB run."
fi

if command -v matlab >/dev/null 2>&1; then
  if [[ "$SAVE_FLAG" == "true" ]]; then
    : "${SAVE_DIR:?SAVE_FLAG=true but SAVE_DIR not set}"
    # Escape single quotes for MATLAB string literal
    ESCAPED_DIR="${SAVE_DIR//\'/\'\'}"
    MATLAB_CMD="${MATLAB_PREFIX} save_plots=true; save_plots_dir='${ESCAPED_DIR}'; ${MATLAB_WRAP}"
  else
    MATLAB_CMD="${MATLAB_PREFIX} ${MATLAB_WRAP}"
  fi
  matlab -batch "${MATLAB_CMD}"
else
  err "matlab not found in PATH."
fi
