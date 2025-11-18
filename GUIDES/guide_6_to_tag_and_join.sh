#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE5_ROOT="$REPO_ROOT/STAGES/STAGE_5"
STAGE6_ROOT="$REPO_ROOT/STAGES/STAGE_6"
ALL_UNPACKED_DIR="$STAGE5_ROOT/DATA/DATA_FILES/ALL_UNPACKED"
TO_JOIN_ROOT="$STAGE6_ROOT/DATA/DATA_FILES/TO_JOIN"
ALREADY_JOINED_ROOT="$STAGE6_ROOT/DATA/DATA_FILES/ALREADY_JOINED"
LOGBOOK="$STAGE5_ROOT/DATA/DATA_LOGS/file_logbook.csv"
STORAGE_ROOT="$STAGE5_ROOT/DATA/DATA_FILES/ANCILLARY"
JOIN_LOG="$STAGE6_ROOT/DATA/DATA_LOGS/run_join_sources.csv"

declare -A PREMERGED_SOURCES=(
  ["1"]="$STORAGE_ROOT/RUN_1"
  ["2"]="$STORAGE_ROOT/RUN_2"
  ["3"]="$STORAGE_ROOT/RUN_3"
)

show_help() {
  cat <<EOF
Usage: $0 [options]

Tag unpacked datasets per run, populate STAGES/STAGE_6/DATA/DATA_FILES/TO_JOIN/RUN_<id>
with the corresponding MAT files, and invoke the joiner to write merged outputs under
STAGES/STAGE_6/DATA/DATA_FILES/ALREADY_JOINED/RUN_<id>.

Options:
  -r, --run <id>[,<id>...]   Only join the selected run ids (comma-separated or repeat flag).
  -h, --help                 Show this help message and exit.
EOF
}

SELECTED_RUNS=()
declare -A SELECTED_RUNS_MAP=()
declare -A JOIN_HISTORY=()

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

mkdir -p "$TO_JOIN_ROOT" "$ALREADY_JOINED_ROOT" "$STORAGE_ROOT" "$(dirname "$LOGBOOK")"
mkdir -p "$(dirname "$JOIN_LOG")"
if [[ -f "$JOIN_LOG" ]]; then
  while IFS=',' read -r rid sources; do
    if [[ "$rid" == "run_id" || -z "$rid" ]]; then
      continue
    fi
    JOIN_HISTORY["$rid"]="$sources"
  done < "$JOIN_LOG"
else
  echo "run_id,hlds" > "$JOIN_LOG"
fi

if [[ ! -f "$LOGBOOK" ]]; then
  echo "Logbook $LOGBOOK not found; ensure Stage 5 tagging/unpacking has been run."
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
    run_dir="$TO_JOIN_ROOT/RUN_${run_id}"
    out_dir="$ALREADY_JOINED_ROOT/RUN_${run_id}"

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
      JOIN_HISTORY["$run_id"]="PREMERGED"
      continue
    else
      echo "Warning: expected premerged directory ${source_dir} not found for run ${run_id}."
    fi
  fi

  run_dir="$TO_JOIN_ROOT/RUN_${run_id}"
  mkdir -p "$run_dir/time" "$run_dir/charge"
  rm -f "$run_dir/time"/*.mat "$run_dir/charge"/*.mat 2>/dev/null || true
  collected_hlds=()
  for hld_file in ${RUN_FILES[$run_id]}; do
    dataset_prefix="${hld_file%.hld}"
    match_dir=$(ls "$ALL_UNPACKED_DIR" 2>/dev/null | grep -E "^${dataset_prefix}(_|$)" | head -n 1 || true)
    if [[ -z "$match_dir" ]]; then
      echo "Warning: no unpacked directory found for $hld_file"
      continue
    fi
    collected_hlds+=("$hld_file")
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
  NEW_SIGNATURE=""
  unset SORTED_HLDS || true
  if [[ ${#collected_hlds[@]} -gt 0 ]]; then
    mapfile -t SORTED_HLDS < <(printf '%s\n' "${collected_hlds[@]}" | sort -u)
    NEW_SIGNATURE=$(IFS=';'; echo "${SORTED_HLDS[*]}")
  fi

  if [[ -z "$NEW_SIGNATURE" ]]; then
    echo "No unpacked datasets matched run ${run_id}; skipping join step."
    continue
  fi

  if [[ ${#gathered_mat[@]} -eq 0 ]]; then
    echo "No MAT files collected for run ${run_id}; skipping join step."
    continue
  fi

  PREVIOUS_SIGNATURE="${JOIN_HISTORY[$run_id]:-}"
  if [[ -n "$PREVIOUS_SIGNATURE" && "$PREVIOUS_SIGNATURE" == "$NEW_SIGNATURE" ]]; then
    echo "Run ${run_id}: HLD inputs unchanged since last join; skipping merge."
    continue
  fi

  output_dir="$ALREADY_JOINED_ROOT/RUN_${run_id}"
  rm -rf "$output_dir"
  mkdir -p "$output_dir"

  ESC_RUN="${run_dir//\'/\'\'}"
  ESC_OUT="${output_dir//\'/\'\'}"
  if matlab -batch "runs={'$ESC_RUN'}; output_root='$ESC_OUT'; run('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/STAGES/STAGE_6/SCRIPTS/join_mat_files.m'); exit;"; then
    JOIN_HISTORY["$run_id"]="$NEW_SIGNATURE"
  else
    echo "Joiner encountered an issue for run ${run_id}; moving on."
    continue
  fi

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

tmp_join_log=$(mktemp)
{
  echo "run_id,hlds"
  if [[ ${#JOIN_HISTORY[@]} -gt 0 ]]; then
    for rid in $(printf '%s\n' "${!JOIN_HISTORY[@]}" | sort -n); do
      printf '%s,%s\n' "$rid" "${JOIN_HISTORY[$rid]}"
    done
  fi
} > "$tmp_join_log"
mv "$tmp_join_log" "$JOIN_LOG"
