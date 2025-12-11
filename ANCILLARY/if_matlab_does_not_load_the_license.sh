#!bin/bash

sudo pkill -f "MATLAB"
sudo pkill -f "matlab_helper"
sudo pkill -f "lmgrd"
sudo pkill -f "mlm"  # license manager processes
sudo pkill -f "MathWorksServiceHost" || true
