#!/bin/bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $0

Generate the summary plots by running plot_run_tables.py and plot_time_series.py --all.
EOF
  exit 0
fi

mkdir -p /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/OUTPUTS_8


# Run the Python plotting script to generate plots from the run tables
python3 /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/plot_run_tables.py


# Run the Python plotting script to generate time series plots
python3 /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/plot_time_series.py --all
