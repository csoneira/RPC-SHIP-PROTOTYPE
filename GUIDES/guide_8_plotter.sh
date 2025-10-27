#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE8_ROOT="$REPO_ROOT/STAGES/STAGE_8"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<USAGE
Usage: $0

Generate the summary plots by running plot_run_tables.py and plot_time_series.py --all.
USAGE
  exit 0
fi

OUTPUT_DIR="$STAGE8_ROOT/DATA/DATA_FILES/OUTPUTS_8"
mkdir -p "$OUTPUT_DIR"

python3 "$STAGE8_ROOT/SCRIPTS/plot_run_tables.py"
python3 "$STAGE8_ROOT/SCRIPTS/plot_time_series.py" --all
