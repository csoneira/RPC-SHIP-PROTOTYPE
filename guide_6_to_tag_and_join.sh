#!/bin/bash


# Tag the datafiles that are in file_database.csv and out them to file_logbook.csv
python3 /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/run_tagger.py

# Run with no GUI the MATLAB script that joins the .mat files
matlab -nodesktop -nosplash -r "run('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/SCRIPTS/join_mat_files.m'); exit;"


