#!/bin/bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [--help|-h] [--save] [--save-dir <path>] [--run|-r <ids>] [--no-plot] [--debug|-d] [--full-pdf] [--simple-pdf] [--pdf-max-pages <n>]

This script analyzes the unpacked HLD files.

Arguments:
  --help, -h           Show this help message
  --save               Save the generated plots (default: do not save)
  --save-dir <path>    Directory to save plots (default: STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/PDF)
  --simple-pdf         Limit PDF export to a lightweight subset (default when --save is used)
  --full-pdf           Export every available figure to the PDF (can be heavy)
  --pdf-max-pages <n>  Hard cap on the number of figure pages exported
  --no-plot            Skip all figure generation (only produce CSV output)
  --run, -r <ids>      Analyze specific run id(s). Accepts comma lists or repeated flags.
  --debug, -d          Enable verbose debug output inside MATLAB
EOF
    exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
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


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

DEFAULT_SAVE_DIR="$REPO_ROOT/STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/PDF"
SAVE_FLAG=false
NO_PLOT_FLAG=false
SAVE_DIR="$DEFAULT_SAVE_DIR"
DEBUG_FLAG=false
CLI_ARGS=()
PDF_MODE="simple"
PDF_MAX_PAGES=""
declare -a REQUESTED_RUNS=()

mkdir -p "$DEFAULT_SAVE_DIR"

parse_runs() {
    IFS=',' read -ra entries <<< "$1"
    for entry in "${entries[@]}"; do
        trimmed="${entry//[[:space:]]/}"
        if [[ -n "$trimmed" ]]; then
            REQUESTED_RUNS+=("$trimmed")
        fi
    done
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
        --simple-pdf)
            PDF_MODE="simple"
            shift
            ;;
        --full-pdf)
            PDF_MODE="full"
            shift
            ;;
        --pdf-max-pages)
            [[ $# -ge 2 ]] || usage
            PDF_MAX_PAGES="$2"
            shift 2
            ;;
        --no-plot)
            NO_PLOT_FLAG=true
            CLI_ARGS+=("--no-plot")
            shift
            ;;
        -r|--run)
            [[ $# -ge 2 ]] || usage
            parse_runs "$2"
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

if [[ "$PDF_MODE" == "simple" ]]; then
    CLI_ARGS+=("--simple-pdf")
elif [[ "$PDF_MODE" == "full" ]]; then
    CLI_ARGS+=("--full-pdf")
fi

if [[ -n "$PDF_MAX_PAGES" ]]; then
    CLI_ARGS+=("--pdf-limit=${PDF_MAX_PAGES}")
fi


MATLAB_SCRIPT="feval('run','STAGES/STAGE_7/SCRIPTS/caye_edits_minimal.m');"
MATLAB_WRAP="try, ${MATLAB_SCRIPT} catch ME, disp(getReport(ME,'extended')); exit(1); end"

JOINED_ROOT="$REPO_ROOT/STAGES/STAGE_6/DATA/DATA_FILES/ALREADY_JOINED"

# --- helpers -----------------------------------------------------------------

err() { echo "Error: $*" >&2; exit 1; }
warn() { echo "Warning: $*" >&2; }

select_joined_dir_for_run() {
  local run_id="$1"
  local candidate="$JOINED_ROOT/RUN_${run_id}"
  [[ -d "$candidate" ]] || err "Run directory not found: $candidate"
  (cd "$candidate" && pwd)
}

select_oldest_joined_dir() {
  mapfile -t candidates < <(find "$JOINED_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n)
  if [[ ${#candidates[@]} -eq 0 ]]; then
    err "No run directories found in $JOINED_ROOT."
  fi
  local oldest_line="${candidates[0]}"
  local path="${oldest_line#* }"
  (cd "$path" && pwd)
}

run_analysis_for_input() {
  local input_dir="$1"
  local run_label="${2:-0}"

  echo "Selected input directory: $input_dir"

  local ESCAPED_INPUT="${input_dir//\'/\'\'}"
  local MATLAB_PREFIX="test=false; run=${run_label}; input_dir='${ESCAPED_INPUT}';"

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

  local MATLAB_CMD
  if command -v matlab >/dev/null 2>&1; then
    if [[ "$SAVE_FLAG" == "true" ]]; then
      : "${SAVE_DIR:?SAVE_FLAG=true but SAVE_DIR not set}"
      local ESCAPED_DIR="${SAVE_DIR//\'/\'\'}"
      MATLAB_CMD="${MATLAB_PREFIX} save_plots=true; save_plots_dir='${ESCAPED_DIR}'; ${MATLAB_WRAP}"
    else
      MATLAB_CMD="${MATLAB_PREFIX} ${MATLAB_WRAP}"
    fi
    matlab -batch "${MATLAB_CMD}"
  else
    err "matlab not found in PATH."
  fi
}

# --- checks & execution ------------------------------------------------------

if [[ ! -d "$JOINED_ROOT" ]]; then
  err "Joined data directory not found: $JOINED_ROOT"
fi

SAVE_FLAG="${SAVE_FLAG:-false}"

if [[ ${#REQUESTED_RUNS[@]} -gt 0 ]]; then
  echo "Analyzing run(s): ${REQUESTED_RUNS[*]}"
  for run_id in "${REQUESTED_RUNS[@]}"; do
    input_dir="$(select_joined_dir_for_run "$run_id")"
    run_analysis_for_input "$input_dir" "$run_id"
  done
else
  echo "No run override provided; analyzing every RUN_* directory under $JOINED_ROOT."
  mapfile -t ALL_RUN_DIRS < <(find "$JOINED_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'RUN_*' | sort)
  if [[ ${#ALL_RUN_DIRS[@]} -eq 0 ]]; then
    err "No RUN_* directories found in $JOINED_ROOT."
  fi
  for path in "${ALL_RUN_DIRS[@]}"; do
    base=$(basename "$path")
    if [[ "$base" =~ ^RUN_(.+)$ ]]; then
      run_label="${BASH_REMATCH[1]}"
    else
      run_label="$base"
    fi
    echo "Analyzing $base ..."
    run_analysis_for_input "$path" "$run_label"
  done
fi
