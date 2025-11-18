#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE8_ROOT="$REPO_ROOT/STAGES/STAGE_8"

usage() {
  cat <<USAGE
Usage: $0 [options]

Generate run summary and time-series plots (Stage 8 outputs).

Options:
  -r, --run <id>[,<id>...]   Restrict plots to specific run ids (comma-separated or repeat flag).
  -h, --help                 Show this help message and exit.
USAGE
}

declare -a SELECTED_RUNS=()

parse_runs() {
  IFS=',' read -ra parts <<< "$1"
  for run in "${parts[@]}"; do
    trimmed="${run//[[:space:]]/}"
    if [[ -n "$trimmed" ]]; then
      SELECTED_RUNS+=("$trimmed")
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--run)
      if [[ $# -lt 2 ]]; then
        echo "Error: --run expects a value." >&2
        exit 1
      fi
      parse_runs "$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

OUTPUT_DIR="$STAGE8_ROOT/DATA/DATA_FILES/OUTPUTS_8"
mkdir -p "$OUTPUT_DIR"

RUN_TABLE_ARGS=()
RUN_TIME_ARGS=()

if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
  RUN_TABLE_ARGS+=(--runs)
  RUN_TABLE_ARGS+=("${SELECTED_RUNS[@]}")
  RUN_LIST=$(IFS=','; echo "${SELECTED_RUNS[*]}")
  RUN_TIME_ARGS+=(--run "$RUN_LIST")
else
  RUN_TIME_ARGS+=(--all)
fi

python3 "$STAGE8_ROOT/SCRIPTS/plot_run_tables.py" "${RUN_TABLE_ARGS[@]}"
python3 "$STAGE8_ROOT/SCRIPTS/plot_time_series.py" "${RUN_TIME_ARGS[@]}"
