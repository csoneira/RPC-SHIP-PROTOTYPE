#!/bin/bash

# set -euo pipefail

# --------------------------------------------------------------------------------------------
# Usage helper
# --------------------------------------------------------------------------------------------

show_usage() {
  cat <<EOF
Usage: $0 [--help|-h] [--all|-a]

Moves HLD files from the source directory into the unpack queue and invokes the unpacker.

Options:
  --help, -h    Show this help message and exit.
  --all,  -a    Process every .hld found in the source directory sequentially.
  --run,  -r    Only unpack files that belong to the specified run id(s). Accepts comma lists.
EOF
}

PROCESS_ALL=false
declare -a SELECTED_RUNS=()
declare -A SELECTED_RUN_MAP=()

parse_runs() {
  IFS=',' read -ra parts <<< "$1"
  for run in "${parts[@]}"; do
    trimmed="${run//[[:space:]]/}"
    if [[ -n "$trimmed" ]]; then
      SELECTED_RUNS+=("$trimmed")
      SELECTED_RUN_MAP["$trimmed"]=1
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_usage
      exit 0
      ;;
    --all|-a)
      PROCESS_ALL=true
      shift
      ;;
    --run|-r)
      if [[ $# -lt 2 ]]; then
        echo "Error: --run expects a value." >&2
        exit 1
      fi
      parse_runs "$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_usage
      exit 1
      ;;
  esac
done

# --------------------------------------------------------------------------------------------
# Prevent the script from running multiple instances -----------------------------------------
# --------------------------------------------------------------------------------------------

script_name=$(basename "$0")
lockfile="/tmp/${script_name}.lock"

# Acquire non-blocking lock on FD 9
exec 9>"$lockfile"
if ! flock -n 9; then
  echo "$(date): $script_name is already running. Exiting."
  exit 1
fi

# Optional: record PID in the lock (useful for debugging)
echo $$ 1>&9
# set -euo pipefail # Exit on error, undefined variable, or error in a pipeline
# IFS=$'\n\t' # Set IFS to handle spaces in filenames

# # Variables
# script_name=$(basename "$0")
# script_args="$*"
# current_pid=$$

# for pid in $(ps -eo pid,cmd | grep "[b]ash *$script_name*" | grep -v "bin/bash -c" | awk '{print $1}'); do
#     if [[ "$pid" != "$current_pid" ]]; then
#         cmdline=$(ps -p "$pid" -o args=)
#         # echo "$(date) - Found running process: PID $pid - $cmdline"
#         if [[ "$cmdline" == *"$script_name"* ]]; then
#             echo "------------------------------------------------------"
#             echo "$(date): The script $script_name is already running (PID: $pid). Exiting."
#             echo "------------------------------------------------------"
#             exit 1
#         fi
#     fi
# done


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE4_ROOT="$REPO_ROOT/STAGES/STAGE_4"
STAGE5_ROOT="$REPO_ROOT/STAGES/STAGE_5"
RUN_TAGGER_SCRIPT="$STAGE4_ROOT/SCRIPTS/run_tagger.py"
LOCAL_DB_PATH="$STAGE4_ROOT/DATA/DATA_LOGS/file_database.csv"
VENV_DIR="$REPO_ROOT/STAGES/STAGE_1/DATA/DATA_FILES/venv"
HLD_SOURCE_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/NOT_UNPACKED"
HLD_SENT_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/SENT_TO_UNPACKING"
HLD_ERROR_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/ERROR"
EXCLUDE_CONFIG="$STAGE4_ROOT/DATA/CONFIGS/hld_exclude_patterns.txt"
IDLE_DIR="$STAGE4_ROOT/DATA/DATA_FILES/HLD_FILES/IDLE_IN_UNPACKING_DIR"
PROCESSING_ROOT="$STAGE5_ROOT/DATA/DATA_FILES/PROCESSING"
HLD_UNPACK_DIR="$PROCESSING_ROOT/hlds_toUnpack"
UNPACKED_OUTPUT_DIR="$PROCESSING_ROOT/unpackedFiles"
CHARGE_TEMP_DIR="$PROCESSING_ROOT/charge"
BLINE_TEMP_DIR="$PROCESSING_ROOT/baseLine"
TIME_TEMP_DIR="$PROCESSING_ROOT/time"
PLOTS_TEMP_DIR="$PROCESSING_ROOT/plots"
ERROR_DIR="$PROCESSING_ROOT/error_hlds"
ALL_UNPACKED_DIR="$STAGE5_ROOT/DATA/DATA_FILES/ALL_UNPACKED"
UNPACK_LOG_DIR="$STAGE5_ROOT/DATA/DATA_LOGS"
UNPACK_LOG="${HLD_UNPACK_DATABASE:-$UNPACK_LOG_DIR/unpack_database.csv}"
RUN_TAG_LOG="$STAGE5_ROOT/DATA/DATA_LOGS/file_logbook.csv"

mkdir -p "$HLD_SOURCE_DIR" "$HLD_UNPACK_DIR" "$UNPACKED_OUTPUT_DIR" \
         "$CHARGE_TEMP_DIR" "$BLINE_TEMP_DIR" "$TIME_TEMP_DIR" "$PLOTS_TEMP_DIR" \
         "$IDLE_DIR" "$HLD_SENT_DIR" "$HLD_ERROR_DIR" "$ERROR_DIR" "$ALL_UNPACKED_DIR" "$UNPACK_LOG_DIR"

# Ensure unpacking staging directories start clean
rm -f "$HLD_UNPACK_DIR"/* 2>/dev/null || true
rm -f "$UNPACKED_OUTPUT_DIR"/* 2>/dev/null || true
rm -f "$CHARGE_TEMP_DIR"/* 2>/dev/null || true
rm -f "$BLINE_TEMP_DIR"/* 2>/dev/null || true
rm -f "$TIME_TEMP_DIR"/* 2>/dev/null || true
rm -f "$PLOTS_TEMP_DIR"/* 2>/dev/null || true

declare -A already_unpacked=()
declare -A unpacked_timestamps=()
declare -A filename_run_map=()
declare -A sent_prefix_exclude=()
declare -A error_file_exclude=()
skipped_run_filtered=0
skipped_unmapped=0
skipped_sent_archive=0
skipped_error_archive=0

refresh_run_tags() {
  if [[ ! -f "$RUN_TAGGER_SCRIPT" ]]; then
    echo "[ERROR] Run tagger script not found at $RUN_TAGGER_SCRIPT" >&2
    exit 1
  fi
  if python3 "$RUN_TAGGER_SCRIPT" --database "$LOCAL_DB_PATH" --output "$RUN_TAG_LOG" --allow-missing-database --quiet; then
    echo "[INFO] Updated run tagging log at $RUN_TAG_LOG"
  else
    echo "[ERROR] Failed to refresh run tagging logbook at $RUN_TAG_LOG" >&2
    exit 1
  fi
}

load_run_tags() {
  if [[ ! -f "$RUN_TAG_LOG" ]]; then
    echo "[WARN] Run tag log not found ($RUN_TAG_LOG); run filtering will be disabled."
    return
  fi
  while IFS=',' read -r fname ts run_id; do
    if [[ "$fname" == "filename" ]]; then
      continue
    fi
    fname="${fname//[$'\r\n']/}"
    run_id="${run_id//[$'\r\n']/}"
    if [[ -n "$fname" && -n "$run_id" ]]; then
      filename_run_map["$fname"]="$run_id"
    fi
  done < "$RUN_TAG_LOG"
}

load_sent_excludes() {
  if [[ ! -d "$HLD_SENT_DIR" ]]; then
    return
  fi
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ -n "${already_unpacked[$entry]+x}" ]]; then
      prefix="${entry%%.*}"
      sent_prefix_exclude["$prefix"]=1
    else
      echo "[INFO] SENT_TO_UNPACKING entry $entry lacks unpack record; it will be reconsidered."
    fi
  done < <(find "$HLD_SENT_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true)
  if [[ ${#sent_prefix_exclude[@]} -gt 0 ]]; then
    echo "[INFO] Skipping ${#sent_prefix_exclude[@]} file(s) already tracked in SENT_TO_UNPACKING."
  fi
}

load_error_excludes() {
  if [[ ! -d "$HLD_ERROR_DIR" ]]; then
    return
  fi
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    error_file_exclude["$entry"]=1
  done < <(find "$HLD_ERROR_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true)
  if [[ ${#error_file_exclude[@]} -gt 0 ]]; then
    echo "[INFO] Skipping ${#error_file_exclude[@]} file(s) marked as failed."
  fi
}

ensure_unpacked_database() {
  if [[ ! -f "$UNPACK_LOG" || ! -s "$UNPACK_LOG" ]]; then
    echo "filename,unpacked_date,unpacked_time" > "$UNPACK_LOG"
    return
  fi

  local header
  header=$(head -n 1 "$UNPACK_LOG")
  if [[ "$header" != "filename,unpacked_date,unpacked_time" ]]; then
    echo "[WARNING] Unexpected header in $UNPACK_LOG (found '$header'). Proceeding but new data will follow the standard schema."
  fi
}

load_unpacked_database() {
  while IFS=',' read -r fname unpack_date unpack_time _; do
    if [[ -z "$fname" || "$fname" == "filename" ]]; then
      continue
    fi
    already_unpacked["$fname"]=1
    if [[ -n "$unpack_date" || -n "$unpack_time" ]]; then
      unpacked_timestamps["$fname"]="${unpack_date} ${unpack_time}"
    fi
  done < <(tail -n +2 "$UNPACK_LOG")
  local total=${#already_unpacked[@]}
  echo "[INFO] Loaded $total previously unpacked file(s) from $UNPACK_LOG"
}

record_unpacked_file() {
  local filename="$1"
  local unpack_date unpack_time
  unpack_date=$(date +%Y-%m-%d)
  unpack_time=$(date '+%H:%M:%S')
  echo "$filename,$unpack_date,$unpack_time" >> "$UNPACK_LOG"
  already_unpacked["$filename"]=1
  unpacked_timestamps["$filename"]="$unpack_date $unpack_time"
  echo "[INFO] Marked $filename as unpacked at $unpack_date $unpack_time"
}

ensure_unpacked_database
load_unpacked_database
echo "[INFO] Tracking unpacked files in: $UNPACK_LOG"
refresh_run_tags
load_run_tags
load_sent_excludes
load_error_excludes
if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
  if [[ ${#filename_run_map[@]} -eq 0 ]]; then
    echo "[WARN] Run filtering requested but no tag mapping available; continuing without filtering."
    SELECTED_RUNS=()
    SELECTED_RUN_MAP=()
  else
    echo "[INFO] Run filter: ${SELECTED_RUNS[*]}"
  fi
fi

move_idle_contents() {
  shopt -s nullglob
  local contents=("$HLD_UNPACK_DIR"/*)
  if (( ${#contents[@]} > 0 )); then
    echo "Moving residual files from unpacking directory to IDLE storage."
    mv "${contents[@]}" "$IDLE_DIR/"
  fi
  shopt -u nullglob
}

process_single_hld() {
  local hld_path="$1"
  local filename
  filename=$(basename "$hld_path")
  local prefix="${filename%%.*}"

  if [[ -n "${error_file_exclude[$filename]:-}" ]]; then
    echo "  [SKIP] $filename — previously marked with errors."
    skipped_error_archive=$((skipped_error_archive + 1))
    return 0
  fi

  if [[ -n "${sent_prefix_exclude[$prefix]:-}" ]]; then
    echo "  [SKIP] $filename — recorded in SENT_TO_UNPACKING archive."
    skipped_sent_archive=$((skipped_sent_archive + 1))
    return 0
  fi

  if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
    local run_tag="${filename_run_map[$filename]:-}"
    if [[ -z "$run_tag" ]]; then
      echo "Skipping $filename — no run tag available."
      skipped_unmapped=$((skipped_unmapped + 1))
      return 0
    fi
    if [[ -z "${SELECTED_RUN_MAP[$run_tag]:-}" ]]; then
      echo "Skipping $filename — tagged for run ${run_tag}, not requested."
      skipped_run_filtered=$((skipped_run_filtered + 1))
      return 0
    fi
    echo "[INFO] Processing run ${run_tag} file: $filename"
  fi

  if [[ -n "${already_unpacked[$filename]+x}" ]]; then
    local ts="${unpacked_timestamps[$filename]}"
    if [[ -n "$ts" ]]; then
      echo "Skipping $filename — already unpacked at $ts"
    else
      echo "Skipping $filename — already recorded as unpacked"
    fi
    return 0
  fi

  move_idle_contents

  echo "Moving $filename to unpack queue"
  if [[ -f "$HLD_SENT_DIR/$filename" ]]; then
    echo "SENT_TO_UNPACKING already has $filename; skipping re-unpack."
    skipped_sent_archive=$((skipped_sent_archive + 1))
    return 0
  fi
  cp -a "$hld_path" "$HLD_SENT_DIR/"
  mv "$hld_path" "$HLD_UNPACK_DIR/$filename"

  cd "$REPO_ROOT"
  if "$VENV_DIR/bin/python" STAGES/STAGE_5/SCRIPTS/unpacker/unpackAll.py; then
    record_unpacked_file "$filename"
  else
    echo "[ERROR] Unpacker failed for $filename"
    mv "$HLD_UNPACK_DIR/$filename" "$ERROR_DIR/$filename" 2>/dev/null || true
    if mv "$HLD_SENT_DIR/$filename" "$HLD_ERROR_DIR/$filename" 2>/dev/null; then
      :
    else
      mv "$ERROR_DIR/$filename" "$HLD_ERROR_DIR/$filename" 2>/dev/null || true
    fi
    if [[ -n "$EXCLUDE_CONFIG" ]]; then
      mkdir -p "$(dirname "$EXCLUDE_CONFIG")"
      if ! grep -Fxq "$filename" "$EXCLUDE_CONFIG" 2>/dev/null; then
        echo "$filename" >> "$EXCLUDE_CONFIG"
        echo "[INFO] Added $filename to exclude patterns ($EXCLUDE_CONFIG)."
      fi
    fi
    error_file_exclude["$filename"]=1
    skipped_error_archive=$((skipped_error_archive + 1))
    return 0
  fi
}

process_next_hld() {
  mapfile -t available_hlds < <(find "$HLD_SOURCE_DIR" -maxdepth 1 -type f -name '*.hld' -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-)

  if [[ ${#available_hlds[@]} -eq 0 ]]; then
    echo "No HLD files available in $HLD_SOURCE_DIR"
    return 1
  fi

  local candidate=""
  for path in "${available_hlds[@]}"; do
    local fname
    fname=$(basename "$path")
    local prefix="${fname%%.*}"
    if [[ -n "${error_file_exclude[$fname]:-}" ]]; then
      echo "Skipping $fname — marked with previous unpack errors."
      skipped_error_archive=$((skipped_error_archive + 1))
      continue
    fi
    if [[ -n "${sent_prefix_exclude[$prefix]:-}" ]]; then
      echo "Skipping $fname — recorded in SENT_TO_UNPACKING archive."
      skipped_sent_archive=$((skipped_sent_archive + 1))
      continue
    fi
    if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
      local run_tag="${filename_run_map[$fname]:-}"
      if [[ -z "$run_tag" ]]; then
        echo "Skipping $fname — missing run tag."
        skipped_unmapped=$((skipped_unmapped + 1))
        continue
      fi
      if [[ -z "${SELECTED_RUN_MAP[$run_tag]:-}" ]]; then
        echo "Skipping $fname — run ${run_tag} not requested."
        skipped_run_filtered=$((skipped_run_filtered + 1))
        continue
      fi
    fi
    if [[ -n "${already_unpacked[$fname]+x}" ]]; then
      local ts="${unpacked_timestamps[$fname]}"
      if [[ -n "$ts" ]]; then
        echo "Skipping $fname — already unpacked at $ts"
      else
        echo "Skipping $fname — already recorded as unpacked"
      fi
      continue
    fi
    candidate="$path"
    break
  done

  if [[ -z "$candidate" ]]; then
    echo "All available HLD files are already logged as unpacked or filtered out."
    return 1
  fi

  process_single_hld "$candidate"
}

if [[ "$PROCESS_ALL" == "true" ]]; then
  processed_count=0
  while process_next_hld; do
    ((processed_count++))
  done
  if (( processed_count == 0 )); then
    echo "No HLD files processed."
  else
    echo "Processed $processed_count HLD file(s)."
  fi
else
  process_next_hld || exit 0
fi

if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
  echo "[INFO] Run-filter skips — outside selection: $skipped_run_filtered, missing tags: $skipped_unmapped"
fi
echo "[INFO] Files skipped due to SENT_TO_UNPACKING archive: $skipped_sent_archive"
echo "[INFO] Files skipped due to ERROR archive: $skipped_error_archive"
