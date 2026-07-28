#!/usr/bin/env bash
# Launch TOMAR's Octave analysis for every runs.csv entry matching one or more
# shell-style run-name patterns. Quote patterns so the calling shell does not
# expand them before this script sees them.
#
# Examples:
#   ./analyze_launcher.sh 'hv_scan_*'
#   ./analyze_launcher.sh --dry-run 'hv_scan_*' 'scint_*'
set -euo pipefail

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=true
    shift
fi
if (( $# == 0 )); then
    echo "Usage: $(basename "$0") [--dry-run] 'RUN_PATTERN' ['RUN_PATTERN' ...]" >&2
    exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tomar_root="$(dirname "$script_dir")"
runs_config="$tomar_root/CONFIGS/runs.csv"

if ! command -v octave-cli >/dev/null 2>&1; then
    echo "error: octave-cli is required but was not found in PATH." >&2
    exit 127
fi
if [[ ! -f "$runs_config" ]]; then
    echo "error: run configuration not found: $runs_config" >&2
    exit 1
fi

declare -a selected_rows=()
declare -A already_selected=()
row_number=0
first_line=true
# The final CSV record may legitimately lack a trailing newline; preserve it.
while IFS=, read -r run_name _ || [[ -n "${run_name:-}" ]]; do
    run_name="${run_name%$'\r'}"
    if [[ "$first_line" == true ]]; then
        first_line=false
        continue
    fi
    [[ -z "$run_name" || "$run_name" == \#* ]] && continue
    ((row_number += 1))
    for pattern in "$@"; do
        if [[ "$run_name" == $pattern && -z "${already_selected[$row_number]:-}" ]]; then
            selected_rows+=("$row_number:$run_name")
            already_selected[$row_number]=1
            break
        fi
    done
done < "$runs_config"

if (( ${#selected_rows[@]} == 0 )); then
    echo "error: no runs in $runs_config match: $*" >&2
    exit 1
fi

for selected in "${selected_rows[@]}"; do
    row="${selected%%:*}"
    run_name="${selected#*:}"
    printf '\n=== Analysing row %s: %s ===\n' "$row" "$run_name"
    if [[ "$dry_run" == true ]]; then
        continue
    fi
    octave-cli --quiet "$tomar_root/run_fast_6x6.m" "@$row"
done
