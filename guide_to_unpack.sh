#!/bin/bash

# This script unpacks all .hld files in the hlds_toUnpack directory and moves them automatically from hlds_toUnpack
# and puts the results of the unpacking in ...

cd /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/
source venv/bin/activate && python unpacker/unpackAll.py