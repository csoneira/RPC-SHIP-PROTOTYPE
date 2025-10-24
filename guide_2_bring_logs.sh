#!/bin/bash


set -euo pipefail # Exit on error, undefined variable, or error in a pipeline
IFS=$'\n\t' # Set IFS to handle spaces in filenames

# Write a help message
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0"
  echo ""
  echo "This script brings the laboratory log files of temperature, pressure, humidity,"
  echo "high voltage and current and DAQ rates for monitoring."
  echo "Only new log files (not yet recorded in log_database.csv) are transferred."
  echo "Run using the line below:"
  echo bash "$0"
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
LOG_ROOT="${PROJECT_ROOT}/LOG_FILES"
LOG_DB="${LOG_ROOT}/log_database.csv"

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
  echo "All remote log files already imported. Nothing to do."
  exit 0
fi

printf "Detected %d new log file(s) to fetch.\n" "${#NEW_FILES[@]}"
FETCH_ONLY_FILES=$(printf "%s\n" "${NEW_FILES[@]}")
FETCH_ONLY_FILES="$FETCH_ONLY_FILES" bash "$PROJECT_ROOT/LOG_FILES/SCRIPTS/log_bring_and_clean.sh"
