#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE5_ROOT="$REPO_ROOT/STAGES/STAGE_5"
STAGE6_ROOT="$REPO_ROOT/STAGES/STAGE_6"
ALL_UNPACKED_DIR="$STAGE5_ROOT/DATA/DATA_FILES/ALL_UNPACKED"
RUNS_ROOT="$STAGE6_ROOT/DATA/DATA_FILES/RUNS"
JOINED_ROOT="$STAGE6_ROOT/DATA/DATA_FILES/JOINED"
LOGBOOK="$STAGE6_ROOT/DATA/DATA_LOGS/file_logbook.csv"
STORAGE_ROOT="$STAGE5_ROOT/DATA/DATA_FILES/ANCILLARY"

declare -A PREMERGED_SOURCES=(
  ["1"]="$STORAGE_ROOT/RUN_1"
  ["2"]="$STORAGE_ROOT/RUN_2"
  ["3"]="$STORAGE_ROOT/RUN_3"
)

show_help() {
  cat <<EOF
Usage: $0 [options]

Tag unpacked datasets per run, populate STAGES/STAGE_6/DATA/DATA_FILES/RUNS/RUN_<id>
with the corresponding MAT files, and invoke the joiner to write merged outputs under
STAGES/STAGE_6/DATA/DATA_FILES/JOINED/RUN_<id>.

Options:
  -r, --run <id>[,<id>...]   Only join the selected run ids (comma-separated or repeat flag).
  -h, --help                 Show this help message and exit.
EOF
}

SELECTED_RUNS=()
declare -A SELECTED_RUNS_MAP=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -r|--run)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --run requires one or more run ids." >&2
        exit 1
      fi
      IFS=',' read -ra run_args <<< "$1"
      for run in "${run_args[@]}"; do
        trimmed="${run//[[:space:]]/}"
        if [[ -n "$trimmed" ]]; then
          SELECTED_RUNS+=("$trimmed")
          SELECTED_RUNS_MAP["$trimmed"]=1
        fi
      done
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
  shift || true
done

mkdir -p "$RUNS_ROOT" "$JOINED_ROOT" "$STORAGE_ROOT" "$(dirname "$LOGBOOK")"

# Update tagging information
python3 "$STAGE6_ROOT/SCRIPTS/run_tagger.py"

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
  if [[ ${#SELECTED_RUNS[@]} -gt 0 && -z "${SELECTED_RUNS_MAP[$run_id]:-}" ]]; then
    echo "Skipping run ${run_id}; not requested via --run."
    continue
  fi
  if [[ -n "${PREMERGED_SOURCES[$run_id]:-}" ]]; then
    source_dir="${PREMERGED_SOURCES[$run_id]}"
    storage_dir="$STORAGE_ROOT/RUN_${run_id}"
    run_dir="$RUNS_ROOT/RUN_${run_id}"
    out_dir="$JOINED_ROOT/RUN_${run_id}"

    if [[ -d "$source_dir" ]]; then
      if [[ ! -d "$storage_dir" ]]; then
        echo "Caching premerged data for run ${run_id} from ${source_dir}"
        cp -a "$source_dir" "$storage_dir"
      fi
      rm -rf "$run_dir"
      cp -a "$storage_dir" "$run_dir"
      rm -rf "$out_dir"
      cp -a "$storage_dir" "$out_dir"
      echo "Run ${run_id} uses premerged data; skipping new merge."
      continue
    else
      echo "Warning: expected premerged directory ${source_dir} not found for run ${run_id}."
    fi
  fi

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

  shopt -s nullglob
  gathered_mat=("$run_dir/time"/*.mat "$run_dir/charge"/*.mat)
  shopt -u nullglob
  if [[ ${#gathered_mat[@]} -eq 0 ]]; then
    echo "No MAT files collected for run ${run_id}; skipping join step."
    continue
  fi

  output_dir="$JOINED_ROOT/RUN_${run_id}"
  rm -rf "$output_dir"
  mkdir -p "$output_dir"

  ESC_RUN="${run_dir//\'/\'\'}"
  ESC_OUT="${output_dir//\'/\'\'}"
  matlab -batch "runs={'$ESC_RUN'}; output_root='$ESC_OUT'; run('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/STAGES/STAGE_6/SCRIPTS/join_mat_files.m'); exit;" || echo "Joiner encountered an issue for run ${run_id}; moving on."

  # Rename joined outputs to canonical RUN_<id> filenames
  for subdir in time charge; do
    target_dir="$output_dir/$subdir"
    if [[ -d "$target_dir" ]]; then
      shopt -s nullglob
      for src_path in "$target_dir"/*_a*_*.*; do
        [[ -f "$src_path" ]] || continue
        filename=$(basename "$src_path")
        suffix="${filename#*_}"
        dest_path="$target_dir/RUN_${run_id}_${suffix}"
        if [[ "$src_path" != "$dest_path" ]]; then
          mv -f "$src_path" "$dest_path"
        fi
      done
      shopt -u nullglob
    fi
  done
done
