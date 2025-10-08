#!/bin/bash


set -euo pipefail # Exit on error, undefined variable, or error in a pipeline
IFS=$'\n\t' # Set IFS to handle spaces in filenames

# Write a help message
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0 [START_DATE]"
  echo ""
  echo "This script brings the laboratory log files of temperature, pressure, humidity,"
  echo "high voltage and current and DAQ rates for monitoring."
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

bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/SCRIPTS/log_bring_and_clean.sh