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

bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/SCRIPTS/log_bring_and_clean.sh