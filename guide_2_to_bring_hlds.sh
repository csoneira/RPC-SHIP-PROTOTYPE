#!/bin/bash


set -euo pipefail # Exit on error, undefined variable, or error in a pipeline
IFS=$'\n\t' # Set IFS to handle spaces in filenames


# Write a help message
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0 [START_DATE]"
  echo ""
  echo "This script moves the oldest .hld file from the source directory to the unpacking directory,"
  echo "then runs the unpacking process."
  echo ""  echo "Arguments:"
  echo "  START_DATE (optional): If provided, only .hld files from this date onwards will be considered."
  echo "                        Format: YYYY-MM-DD"
  echo "                        Example: $0 2025-01-15"
  exit 0
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
        # echo "$(date) - Found running process: PID $pid - $cmdline"
        if [[ "$cmdline" == *"$script_name"* ]]; then
            echo "------------------------------------------------------"
            echo "$(date): The script $script_name is already running (PID: $pid). Exiting."
            echo "------------------------------------------------------"
            exit 1
        fi
    fi
done


# Create necessary directories if they don't exist
PROJECT_ROOT="/home/csoneira/WORK/LIP_stuff/JOAO_SETUP"
HLD_SOURCE_DIR="$PROJECT_ROOT/DATA_FILES/DATA/HLD_FILES"
mkdir -p "$HLD_SOURCE_DIR"


# First, bring new HLD files from the remote server, use the date filter if provided
# because maybe $1 does not exist, so you should put nothing as argument

bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/SCRIPTS/bring_hlds.sh "${1:-}"