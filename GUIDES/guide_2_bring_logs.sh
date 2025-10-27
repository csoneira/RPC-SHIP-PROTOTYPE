#!/bin/bash


set -euo pipefail # Exit on error, undefined variable, or error in a pipeline
IFS=$'\n\t' # Set IFS to handle spaces in filenames

usage() {
  cat <<EOF
Usage: $0 [--force]

Bring laboratory log files from the remote host and update the aggregated
datasets. Only new files are fetched by default. Use --force to reprocess the
existing logs even when no new files are detected.
EOF
}

FORCE_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE2_ROOT="$REPO_ROOT/STAGES/STAGE_2"
LOG_DB="$STAGE2_ROOT/DATA/DATA_LOGS/log_database.csv"
LOG_SCRIPT="$STAGE2_ROOT/SCRIPTS/log_bring_and_clean.sh"
VENV_PATH="$REPO_ROOT/STAGES/STAGE_1/DATA/DATA_FILES/venv"

if [[ ! -d "$VENV_PATH" ]]; then
  echo "Virtual environment not found at $VENV_PATH" >&2
  exit 1
fi

source "$VENV_PATH/bin/activate"
cleanup_venv() {
  deactivate 2>/dev/null || true
}
trap cleanup_venv EXIT

declare -A ALREADY_IMPORTED
if [[ -f "$LOG_DB" ]]; then
  while IFS=, read -r filename _; do
    [[ -z "$filename" || "$filename" == "filename" ]] && continue
    ALREADY_IMPORTED["$filename"]=1
  done < "$LOG_DB"
fi

REMOTE_HOST="${REMOTE_LOG_HOST:-joao}"
REMOTE_DIR="/home/rpcuser/logs"
REMOTE_CMD="cd '$REMOTE_DIR' 2>/dev/null && find . -maxdepth 1 -type f -name '*.log' -printf '%f\n'"
if ! mapfile -t REMOTE_FILES < <(ssh "$REMOTE_HOST" "$REMOTE_CMD"); then
  echo "Unable to query remote log directory at ${REMOTE_HOST}:${REMOTE_DIR}" >&2
  exit 1
fi

if [[ ${#REMOTE_FILES[@]} -eq 0 ]]; then
  echo "No remote log files found at ${REMOTE_HOST}:${REMOTE_DIR}"
  exit 0
fi

NEW_FILES=()
for file in "${REMOTE_FILES[@]}"; do
  if [[ -z "${ALREADY_IMPORTED[$file]:-}" ]]; then
    NEW_FILES+=("$file")
  fi
done

if [[ ${#NEW_FILES[@]} -eq 0 ]]; then
  if [[ "$FORCE_RUN" == "true" ]]; then
    echo "No new log files detected; reprocessing current dataset."
    FETCH_ONLY_FILES="" bash "$LOG_SCRIPT"
    exit 0
  else
    echo "All remote log files already imported. Nothing to do."
    exit 0
  fi
fi

printf "Detected %d new log file(s) to fetch.\n" "${#NEW_FILES[@]}"
FETCH_ONLY_FILES=$(printf "%s\n" "${NEW_FILES[@]}")
FETCH_ONLY_FILES="$FETCH_ONLY_FILES" bash "$LOG_SCRIPT"
