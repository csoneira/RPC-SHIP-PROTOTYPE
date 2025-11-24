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
      --runs <id>[,<id>...]  Alias for --run.
  --full-pdf                 Export every figure (can be heavy).
  --simple-pdf               Limit PDFs to a lightweight subset (default).
  --pdf-max-pages <n>        Hard cap on exported PDF pages for both plotters.
  --png-only                 Stream Stage 8 plots directly to PNGs (skips PDF export).
  --vs-hv                    Use HV setpoint for the X axis instead of run id in run-summary plots.
  -h, --help                 Show this help message and exit.
USAGE
}

declare -a SELECTED_RUNS=()
PDF_MODE="simple"
PDF_MAX_PAGES=""
PNG_ONLY_MODE=false
VS_HV_MODE=false

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
    --runs)
      if [[ $# -lt 2 ]]; then
        echo "Error: --runs expects a value." >&2
        exit 1
      fi
      parse_runs "$2"
      shift 2
      ;;
    --simple-pdf)
      PDF_MODE="simple"
      shift
      ;;
    --full-pdf)
      PDF_MODE="full"
      shift
      ;;
    --pdf-max-pages)
      if [[ $# -lt 2 ]]; then
        echo "Error: --pdf-max-pages expects a value." >&2
        exit 1
      fi
      PDF_MAX_PAGES="$2"
      shift 2
      ;;
    --png-only)
      PNG_ONLY_MODE=true
      shift
      ;;
    --vs-hv)
      VS_HV_MODE=true
      shift
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

if [[ "$PDF_MODE" == "simple" ]]; then
  RUN_TABLE_ARGS+=(--simple-pdf)
  RUN_TIME_ARGS+=(--simple-pdf)
elif [[ "$PDF_MODE" == "full" ]]; then
  RUN_TABLE_ARGS+=(--full-pdf)
  RUN_TIME_ARGS+=(--full-pdf)
fi

if [[ -n "$PDF_MAX_PAGES" ]]; then
  RUN_TABLE_ARGS+=(--pdf-max-pages "$PDF_MAX_PAGES")
  RUN_TIME_ARGS+=(--pdf-max-pages "$PDF_MAX_PAGES")
fi

if [[ "$PNG_ONLY_MODE" == "true" ]]; then
  RUN_TABLE_ARGS+=(--png-only)
  RUN_TIME_ARGS+=(--png-only)
fi

if [[ "$VS_HV_MODE" == "true" ]]; then
  RUN_TABLE_ARGS+=(--vs-hv)
fi

python3 "$STAGE8_ROOT/SCRIPTS/plot_run_tables.py" "${RUN_TABLE_ARGS[@]}"
python3 "$STAGE8_ROOT/SCRIPTS/plot_time_series.py" "${RUN_TIME_ARGS[@]}"
