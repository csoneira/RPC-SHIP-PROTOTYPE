#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE8_ROOT="$REPO_ROOT/STAGES/STAGE_8"

plot=false

if $plot; then
    echo "Generating plots for all runs..."
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 1 --save
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 2 --save
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 3 --save
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 4 --save
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 5 --save
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 6 --save
else
    echo "Analyzing all runs without generating plots..."
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 1 --no-plot
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 2 --no-plot
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 3 --no-plot
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 4 --no-plot
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 5 --no-plot
    bash "$SCRIPT_DIR/guide_7_to_analyze.sh" -r 6 --no-plot
fi

python3 "$STAGE8_ROOT/SCRIPTS/plot_run_tables.py"
python3 "$STAGE8_ROOT/SCRIPTS/plot_time_series.py" -a
