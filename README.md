

The steps of the analysis, in parallel.

Setting up the environment:
1. Set up the Python environment, as described in `PYTHON_ENVIRONMENT_SETUP_COMPLETE.md` (or `PYTHON_SETUP.md` for manual steps)

    bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/setup_environment.sh

The log branch:
1. Bring the log files from the joao computer. This script brings the files and calls to `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/SCRIPTS/log_aggregate_and_join.py`.

    bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/SCRIPTS/log_bring_and_clear.sh

The data branch:
1. **Data bringing** The data is brought in hld format from a certain date, though if the files are already present they are not copied back. HLDs are brought to `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/unpacker/hlds_toUnpack`.

    bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/SCRIPTS/bring_hlds.sh <date_cut YYYY-MM-DD>

2. **Unpacking.** The data is unpacked using the following script, which calls `python unpacker/unpackAll.py` with the environment. It puts the unpacked data in `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabcYYDDDHHMMSS-dabcYYDDDHHMMSS_YYYY-MM-DD_HHhMMmSSs` being the first timestamp the start of the run and the second timestamp the end of the run, and the date and time of the unpacking.

    bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_to_unpack.sh

3. **Data analysis.** The unpacked data is analyzed using the following script, which calls `matlab -batch "run('DATA_FILES/SCRIPTS/Backbone/caye_edits_minimal.m')"` with the environment. It puts the analyzed data in `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/TABLES/analyzed_dabcYYDDDHHMMSS-dabcYYDDDHHMMSS_YYYY-MM-DD_HHhMMmSSs.csv` being the date and time of the analysis.

    bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_to_analyze.sh