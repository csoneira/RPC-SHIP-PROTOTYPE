#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

DEFAULT_SAVE_DIR="$PROJECT_ROOT/DATA_FILES/DATA/PDF"
SAVE_FLAG=false
SAVE_DIR="$DEFAULT_SAVE_DIR"

usage() {
    echo "Usage: $0 [--save] [--save-dir <path>]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)
            SAVE_FLAG=true
            shift
            ;;
        --save-dir)
            [[ $# -ge 2 ]] || usage
            SAVE_DIR="$2"
            SAVE_FLAG=true
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

MATLAB_SCRIPT="run('DATA_FILES/SCRIPTS/Backbone/caye_edits_minimal.m')"

if [[ "$SAVE_FLAG" == true ]]; then
    ESCAPED_DIR=$(printf "%s" "$SAVE_DIR" | sed "s/'/''/g")
    matlab -batch "save_plots=true; save_plots_dir='${ESCAPED_DIR}'; ${MATLAB_SCRIPT}"
else
    matlab -batch "$MATLAB_SCRIPT"
fi
