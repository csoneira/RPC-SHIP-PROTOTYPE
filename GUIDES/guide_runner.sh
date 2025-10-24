#!/bin/bash

# This code is made to run the guide_*.sh scripts in order from the crontab.
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $0

Invoke the guide scripts in sequence (as configured inside this file) and log
their combined output to /home/csoneira/guide_runner.log. Intended for cron use.
EOF
  exit 0
fi

LOG="/home/csoneira/guide_runner.log"
{
  echo "=== START $(date -Iseconds) ==="

# bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_-1_bring_logs.sh
# bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_0_bring_logbook.sh
# bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_1_to_setup_environment.sh
# bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_2_to_bring_hlds.sh 2025-10-01
bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_3_to_unpack.sh
bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_4_to_analyze.sh --save

echo "=== END   $(date -Iseconds) ==="
} >>"$LOG" 2>&1


