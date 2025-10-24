#!/bin/bash

set -euo pipefail

PROJECT_ROOT="/home/csoneira/WORK/LIP_stuff/JOAO_SETUP"
ALL_UNPACKED_DIR="$PROJECT_ROOT/DATA_FILES/DATA/ALL_UNPACKED"
RUNS_ROOT="$PROJECT_ROOT/DATA_FILES/DATA/RUNS"
JOINED_ROOT="$PROJECT_ROOT/DATA_FILES/DATA/JOINED"
LOGBOOK="$PROJECT_ROOT/file_logbook.csv"

mkdir -p "$RUNS_ROOT" "$JOINED_ROOT"

# Update tagging information
python3 "$PROJECT_ROOT/run_tagger.py"

if [[ ! -f "$LOGBOOK" ]]; then
  echo "Logbook $LOGBOOK not found; aborting."
  exit 1
fi

declare -A RUN_FILES
while IFS=, read -r filename timestamp run_id; do
  [[ "$filename" == "filename" ]] && continue
  run_id="${run_id//[$'\r\n']}"
  filename="${filename//[$'\r\n']}"
  if [[ -n "$run_id" && -n "$filename" ]]; then
    RUN_FILES["$run_id"]+=" $filename"
  fi
done < "$LOGBOOK"

if [[ ${#RUN_FILES[@]} -eq 0 ]]; then
  echo "No runs found in logbook; nothing to process."
  exit 0
fi

for run_id in $(printf '%s\n' "${!RUN_FILES[@]}" | sort -n); do
  run_dir="$RUNS_ROOT/RUN_${run_id}"
  mkdir -p "$run_dir/time" "$run_dir/charge"
  rm -f "$run_dir/time"/*.mat "$run_dir/charge"/*.mat 2>/dev/null || true
  for hld_file in ${RUN_FILES[$run_id]}; do
    dataset_prefix="${hld_file%.hld}"
    match_dir=$(ls "$ALL_UNPACKED_DIR" 2>/dev/null | grep -E "^${dataset_prefix}(_|$)" | head -n 1 || true)
    if [[ -z "$match_dir" ]]; then
      echo "Warning: no unpacked directory found for $hld_file"
      continue
    fi
    full_match="$ALL_UNPACKED_DIR/$match_dir"
    for sub in time charge; do
      if [[ -d "$full_match/$sub" ]]; then
        for mat_file in "$full_match/$sub"/*.mat; do
          [[ -f "$mat_file" ]] || continue
          cp -n "$mat_file" "$run_dir/$sub/" 2>/dev/null || cp "$mat_file" "$run_dir/$sub/"
        done
      fi
    done
  done

  output_dir="$JOINED_ROOT/RUN_${run_id}"
  rm -rf "$output_dir"
  mkdir -p "$output_dir"

  ESC_RUN="${run_dir//\'/\'\'}"
  ESC_OUT="${output_dir//\'/\'\'}"
  matlab -batch "runs={'$ESC_RUN'}; output_root='$ESC_OUT'; run('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/SCRIPTS/join_mat_files.m'); exit;" || \
    echo "Joiner encountered an issue for run ${run_id}; moving on."
done
