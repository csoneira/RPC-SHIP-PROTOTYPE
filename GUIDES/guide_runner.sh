#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# This code is made to run the guide_*.sh scripts in order from the crontab.
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<USAGE
Usage: $0

Invoke the guide scripts in sequence (as configured inside this file) and log
their combined output to /home/csoneira/guide_runner.log. Intended for cron use.
USAGE
  exit 0
fi

LOG="/home/csoneira/guide_runner.log"
{
  echo "=== START $(date -Iseconds) ==="

  bash "$SCRIPT_DIR/guide_2_bring_logs.sh"
  bash "$SCRIPT_DIR/guide_3_bring_logbook.sh"
  bash "$SCRIPT_DIR/guide_4_to_bring_hlds.sh"
  bash "$SCRIPT_DIR/guide_5_to_unpack.sh" --all
  bash "$SCRIPT_DIR/guide_6_to_tag_and_join.sh"
  bash "$SCRIPT_DIR/guide_7_to_analyze.sh" --save
  bash "$SCRIPT_DIR/guide_8_plotter.sh"

  echo "=== END   $(date -Iseconds) ==="
} >>"$LOG" 2>&1
