#!/bin/bash

plot=false

if $plot; then
    echo "Generating plots for all runs..."
    bash guide_4_to_analyze.sh -r 1 --save
    bash guide_4_to_analyze.sh -r 2 --save
    bash guide_4_to_analyze.sh -r 3 --save
    bash guide_4_to_analyze.sh -r 4 --save
    bash guide_4_to_analyze.sh -r 5 --save
else
    echo "Analyzing all runs without generating plots..."
    bash guide_4_to_analyze.sh -r 1 --no-plot
    bash guide_4_to_analyze.sh -r 2 --no-plot
    bash guide_4_to_analyze.sh -r 3 --no-plot
    bash guide_4_to_analyze.sh -r 4 --no-plot
    bash guide_4_to_analyze.sh -r 5 --no-plot
fi

python3 plot_run_tables.py
python3 plot_time_series.py -a