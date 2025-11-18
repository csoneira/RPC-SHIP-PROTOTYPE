#!/bin/bash

set -euo pipefail

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


usage() {
  cat <<EOF
Usage: $0 [options]

Bring HLD files from the remote storage, optionally filtering by run id and/or start date.

Options:
  -r, --run <id>[,<id>...]   Only bring files assigned to the selected run ids.
  -s, --start-date <YYYY-MM-DD>
                             Copy files newer than or equal to the provided date.
  -h, --help                 Show this help message and exit.

You may also pass a bare YYYY-MM-DD argument for backward compatibility.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE3_ROOT="$REPO_ROOT/STAGES/STAGE_3"
STAGE4_ROOT="$REPO_ROOT/STAGES/STAGE_4"
STAGE5_ROOT="$REPO_ROOT/STAGES/STAGE_5"
HLD_SOURCE_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/NOT_UNPACKED"
HLD_SENT_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/SENT_TO_UNPACKING"
ALL_UNPACKED_DIR="$STAGE5_ROOT/DATA/DATA_FILES/ALL_UNPACKED"
HLD_ERROR_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/ERROR"
EXCLUDE_CONFIG="$STAGE4_ROOT/DATA/CONFIGS/hld_exclude_patterns.txt"
FILE_DATABASE="$STAGE4_ROOT/DATA/DATA_LOGS/file_database.csv"
REMOTE_DB="$STAGE4_ROOT/DATA/DATA_LOGS/remote_file_database.csv"
REMOTE_LOG="$STAGE4_ROOT/DATA/DATA_LOGS/remote_run_logbook.csv"
RUN_DICT="$STAGE3_ROOT/DATA/DATA_FILES/file_run_dictionary.csv"
RUN_DICT_GENERATOR="$STAGE3_ROOT/SCRIPTS/run_dictionary_creator"
RUN_TAGGER_SCRIPT="$STAGE4_ROOT/SCRIPTS/run_tagger.py"
UNPACK_LOG_PATH="$STAGE5_ROOT/DATA/DATA_LOGS/unpack_database.csv"
mkdir -p "$HLD_SOURCE_DIR"

declare -a SELECTED_RUNS=()
SELECTED_MAP=()
START_DATE_FILTER=""
POSITIONAL_ARGS=()

parse_run_list() {
  IFS=',' read -ra parts <<< "$1"
  for candidate in "${parts[@]}"; do
    trimmed="${candidate//[[:space:]]/}"
    if [[ -n "$trimmed" ]]; then
      SELECTED_RUNS+=("$trimmed")
      SELECTED_MAP["$trimmed"]=1
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--run)
      if [[ $# -lt 2 ]]; then
        echo "Error: --run expects a value." >&2
        exit 1
      fi
      parse_run_list "$2"
      shift 2
      ;;
    -s|--start-date)
      if [[ $# -lt 2 ]]; then
        echo "Error: --start-date expects a value." >&2
        exit 1
      fi
      START_DATE_FILTER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$START_DATE_FILTER" && ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
  START_DATE_FILTER="${POSITIONAL_ARGS[0]}"
fi

echo "[STEP] Generating run dictionary from the Stage 3 logbook..."
if [[ -x "$RUN_DICT_GENERATOR" ]]; then
  "$RUN_DICT_GENERATOR" --quiet
else
  echo "[WARN] Run dictionary generator not found at $RUN_DICT_GENERATOR; continuing with existing CSV."
fi

RUN_ARG=()
if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
  RUN_ARG+=(--run "$(IFS=','; echo "${SELECTED_RUNS[*]}")")
fi

echo "[STEP] Inventorying remote HLD directory..."
bash "$STAGE4_ROOT/SCRIPTS/remote_inventory.sh"

echo "[STEP] Tagging remote HLD listings..."
python3 "$RUN_TAGGER_SCRIPT" \
  --runs-file "$RUN_DICT" \
  --database "$REMOTE_DB" \
  --output "$REMOTE_LOG"

export HLD_FILE_DATABASE="$FILE_DATABASE"
export HLD_REMOTE_RUN_LOG="$REMOTE_LOG"
export HLD_SENT_DIR
export HLD_UNPACK_LOG="$UNPACK_LOG_PATH"
export HLD_ERROR_DIR
export HLD_ALL_UNPACKED="$ALL_UNPACKED_DIR"
export HLD_EXCLUDE_CONFIG="$EXCLUDE_CONFIG"
echo "[INFO] Tracking fetched files in: $HLD_FILE_DATABASE"

BRING_ARGS=()
if [[ -n "$START_DATE_FILTER" ]]; then
  BRING_ARGS+=(--start-date "$START_DATE_FILTER")
fi
if [[ ${#RUN_ARG[@]} -gt 0 ]]; then
  BRING_ARGS+=("${RUN_ARG[@]}")
fi

bash "$STAGE4_ROOT/SCRIPTS/bring_hlds.sh" "${BRING_ARGS[@]}"

# Ensure lock is released and file removed on exit
trap 'flock -u 9; rm -f "$lockfile"' EXIT
