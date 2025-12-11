#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

usage() {
  cat <<EOF
Usage: $0 [options]

Run the end-to-end workflow: set up the environment, pull lab/online logs, bring HLDs,
tag remote files, unpack, join/tag, analyze, and optionally generate Stage 8 plots.

Options:
  -r, --run <id>[,<id>...]   Restrict the workflow to the specified run ids.
  -s, --start-date <YYYY-MM-DD>
                             Only bring HLD files newer than the provided date.
  -f, --force                Force Stage 7 analysis even if no new HLD files were fetched.
  --force-run <id>[,<id>...] Force re-fetching and re-unpacking for the provided run ids.
  -p, --plot                 Allow Stage 7 to generate plots (default skips Stage 7 plots).
  --skip-plots               Do not invoke Stage 8 plotting scripts.
  --png-only                 Stream Stage 7/8 plots directly to PNGs (implies --force and enables plots).
  --slide-mode               Produce Stage 7 figures optimized for slide decks.
  --vs-hv                    In Stage 8, plot run-indexed metrics against HV setpoint instead of run id.
  --comprobation-plot        Generate a Stage 4 timestamp vs. run_id scatter after bringing HLDs.
  -h, --help                 Show this message and exit.
EOF
}

declare -a SELECTED_RUNS=()
declare -a FORCE_FETCH_RUNS=()
START_DATE_FILTER=""
SKIP_PLOTS=false
FORCE_ANALYSIS=false
STAGE7_PLOTS_REQUESTED=false
PNG_ONLY_MODE=false
SLIDE_MODE=false
VS_HV_MODE=false
COMPROBATION_PLOT=false

STAGE4_FILE_DB="$REPO_ROOT/STAGES/STAGE_4/DATA/DATA_LOGS/file_database.csv"
STAGE4_RUN_LOGBOOK="$REPO_ROOT/STAGES/STAGE_4/DATA/DATA_LOGS/remote_run_logbook.csv"
STAGE4_RUN_PLOT="$REPO_ROOT/STAGES/STAGE_4/DATA/DATA_LOGS/remote_run_logbook_plot.png"
STAGE4_PLOTTER="$REPO_ROOT/STAGES/STAGE_4/SCRIPTS/plot_remote_run_logbook.py"
VENV_DIR="$REPO_ROOT/STAGES/STAGE_1/DATA/DATA_FILES/venv"

count_tracked_hlds() {
  local target="$1"
  python3 - "$target" <<'PY'
import csv, sys
from pathlib import Path

path = Path(sys.argv[1])
count = 0
if path.exists():
    with path.open(newline='', encoding='utf-8') as handle:
        reader = csv.reader(handle)
        next(reader, None)
        for row in reader:
            if row and row[0].strip():
                count += 1
print(count)
PY
}

parse_runs() {
  IFS=',' read -ra parts <<< "$1"
  for run in "${parts[@]}"; do
    trimmed="${run//[[:space:]]/}"
    if [[ -n "$trimmed" ]]; then
      SELECTED_RUNS+=("$trimmed")
    fi
  done
}

parse_force_runs() {
  IFS=',' read -ra parts <<< "$1"
  for run in "${parts[@]}"; do
    trimmed="${run//[[:space:]]/}"
    if [[ -n "$trimmed" ]]; then
      FORCE_FETCH_RUNS+=("$trimmed")
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
    -s|--start-date)
      if [[ $# -lt 2 ]]; then
        echo "Error: --start-date expects a value." >&2
        exit 1
      fi
      START_DATE_FILTER="$2"
      shift 2
      ;;
    -f|--force)
      FORCE_ANALYSIS=true
      shift
      ;;
    -p|--plot)
      STAGE7_PLOTS_REQUESTED=true
      shift
      ;;
    --force-run)
      if [[ $# -lt 2 ]]; then
        echo "Error: --force-run expects a value." >&2
        exit 1
      fi
      parse_force_runs "$2"
      shift 2
      ;;
    --skip-plots)
      SKIP_PLOTS=true
      shift
      ;;
    --png-only)
      PNG_ONLY_MODE=true
      FORCE_ANALYSIS=true
      STAGE7_PLOTS_REQUESTED=true
      SKIP_PLOTS=false
      shift
      ;;
    --slide-mode)
      SLIDE_MODE=true
      shift
      ;;
    --vs-hv)
      VS_HV_MODE=true
      shift
      ;;
    --comprobation-plot)
      COMPROBATION_PLOT=true
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

RUN_CSV=""
if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
  mapfile -t SELECTED_RUNS < <(printf "%s\n" "${SELECTED_RUNS[@]}" | sort -n)
  RUN_CSV=$(IFS=','; echo "${SELECTED_RUNS[*]}")
  echo "[INFO] Workflow limited to runs: ${RUN_CSV}"
fi

FORCE_RUN_CSV=""
if [[ ${#FORCE_FETCH_RUNS[@]} -gt 0 ]]; then
  mapfile -t FORCE_FETCH_RUNS < <(printf "%s\n" "${FORCE_FETCH_RUNS[@]}" | sort -n | uniq)
  FORCE_RUN_CSV=$(IFS=','; echo "${FORCE_FETCH_RUNS[*]}")
  echo "[INFO] Force re-fetch/unpack enabled for runs: ${FORCE_RUN_CSV}"
fi

echo "[STEP] Guide 1 — prepare Stage 1 environment"
if [[ -x "$VENV_DIR/bin/python" ]]; then
  echo "[INFO] Stage 1 virtual environment already present at $VENV_DIR; skipping setup."
else
  bash "$SCRIPT_DIR/guide_1_to_setup_environment.sh"
fi

# echo "[STEP] Guide 2 — bring laboratory logs"
# bash "$SCRIPT_DIR/guide_2_bring_logs.sh"

echo "[STEP] Guide 3 — download online logbook"
bash "$SCRIPT_DIR/guide_3_bring_logbook.sh"

BEFORE_FETCH_COUNT=$(count_tracked_hlds "$STAGE4_FILE_DB")

echo "[STEP] Guide 4 — bring HLD files"
GUIDE4_ARGS=()
if [[ -n "$RUN_CSV" ]]; then
  GUIDE4_ARGS+=(--run "$RUN_CSV")
fi
if [[ -n "$START_DATE_FILTER" ]]; then
  GUIDE4_ARGS+=(--start-date "$START_DATE_FILTER")
fi
if [[ -n "$FORCE_RUN_CSV" ]]; then
  GUIDE4_ARGS+=(--force-run "$FORCE_RUN_CSV")
fi
bash "$SCRIPT_DIR/guide_4_to_bring_hlds.sh" "${GUIDE4_ARGS[@]}"

AFTER_FETCH_COUNT=$(count_tracked_hlds "$STAGE4_FILE_DB")
NEW_FETCHED=$((AFTER_FETCH_COUNT - BEFORE_FETCH_COUNT))
NEW_DATA_AVAILABLE=false
if (( NEW_FETCHED > 0 )); then
  echo "[INFO] Detected $NEW_FETCHED new HLD file(s) after Stage 4."
  NEW_DATA_AVAILABLE=true
else
  echo "[INFO] No new HLD files were fetched during Stage 4."
fi

if [[ "$COMPROBATION_PLOT" == "true" ]]; then
  echo "[STEP] Stage 4 — comprobation plot"
  if [[ -f "$STAGE4_PLOTTER" && -f "$STAGE4_RUN_LOGBOOK" ]]; then
    python3 "$STAGE4_PLOTTER" --logbook "$STAGE4_RUN_LOGBOOK" --output "$STAGE4_RUN_PLOT"
  else
    echo "[WARN] Cannot generate comprobation plot; expected logbook at $STAGE4_RUN_LOGBOOK"
  fi
fi

echo "[STEP] Guide 5 — unpack HLD files"
GUIDE5_ARGS=(--all)
if [[ -n "$RUN_CSV" ]]; then
  GUIDE5_ARGS+=(--run "$RUN_CSV")
fi
if [[ -n "$FORCE_RUN_CSV" ]]; then
  GUIDE5_ARGS+=(--force-run "$FORCE_RUN_CSV")
fi
bash "$SCRIPT_DIR/guide_5_to_unpack.sh" "${GUIDE5_ARGS[@]}"

echo "[STEP] Guide 6 — tag and join MAT files"
GUIDE6_ARGS=()
if [[ -n "$RUN_CSV" ]]; then
  GUIDE6_ARGS+=(--run "$RUN_CSV")
fi
if [[ -n "$FORCE_RUN_CSV" ]]; then
  GUIDE6_ARGS+=(--force-run "$FORCE_RUN_CSV")
fi
bash "$SCRIPT_DIR/guide_6_to_tag_and_join.sh" "${GUIDE6_ARGS[@]}"

RUN_STAGE7=false
if [[ "$FORCE_ANALYSIS" == "true" || "$NEW_DATA_AVAILABLE" == "true" ]]; then
  RUN_STAGE7=true
fi

if [[ "$RUN_STAGE7" == "true" ]]; then
  echo "[STEP] Guide 7 — analyze joined runs"
  GUIDE7_ARGS=()
  if [[ -n "$RUN_CSV" ]]; then
    GUIDE7_ARGS+=(--run "$RUN_CSV")
  fi
  if [[ "$STAGE7_PLOTS_REQUESTED" != "true" ]]; then
    GUIDE7_ARGS+=(--no-plot)
  fi
  if [[ "$PNG_ONLY_MODE" == "true" ]]; then
    GUIDE7_ARGS+=(--png-only)
  fi
  if [[ "$SLIDE_MODE" == "true" ]]; then
    GUIDE7_ARGS+=(--slide-mode)
  fi
  bash "$SCRIPT_DIR/guide_7_to_analyze.sh" "${GUIDE7_ARGS[@]}"

  if [[ "$SKIP_PLOTS" == "true" ]]; then
    echo "[INFO] Skipping Stage 8 plotting as requested."
  else
    echo "[STEP] Guide 8 — generate plots"
    GUIDE8_ARGS=()
    if [[ -n "$RUN_CSV" ]]; then
      GUIDE8_ARGS+=(--run "$RUN_CSV")
    fi
    if [[ "$PNG_ONLY_MODE" == "true" ]]; then
      GUIDE8_ARGS+=(--png-only)
    fi
    if [[ "$VS_HV_MODE" == "true" ]]; then
       GUIDE8_ARGS+=(--vs-hv)
    fi
    bash "$SCRIPT_DIR/guide_8_plotter.sh" "${GUIDE8_ARGS[@]}"
  fi
else
  echo "[INFO] Skipping Stage 7/8 — no new data fetched. Use --force to re-run analysis anyway."
fi

echo "[DONE] analyze_all_runs workflow completed."
