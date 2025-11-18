#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE4_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_LOG_DIR="$STAGE4_ROOT/DATA/DATA_LOGS"
mkdir -p "$DATA_LOG_DIR"

REMOTE_HOST="${HLD_REMOTE_HOST:-joao}"
REMOTE_DIR="${HLD_REMOTE_DIR:-/home/rpcuser/hlds}"
REMOTE_GLOB="${HLD_REMOTE_GLOB:-*.hld}"
OUTPUT_PATH="${HLD_REMOTE_DB:-$DATA_LOG_DIR/remote_file_database.csv}"

show_usage() {
  cat <<EOF
Usage: $0 [--help]

Inventory remote HLD files located in \$REMOTE_DIR on \$REMOTE_HOST and emit a CSV
to \$OUTPUT_PATH (default: $OUTPUT_PATH).

Environment overrides:
  HLD_REMOTE_HOST   SSH host to query (default: joao)
  HLD_REMOTE_DIR    Directory on the remote host containing HLD files (default: /home/rpcuser/hlds)
  HLD_REMOTE_GLOB   Glob for remote files (default: *.hld)
  HLD_REMOTE_DB     Destination CSV path (default: $OUTPUT_PATH)
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_usage
  exit 0
fi

remote_command="cd '$REMOTE_DIR' && find . -maxdepth 1 -type f -name '$REMOTE_GLOB' -printf '%f,%s,%T@\\n'"

if ! ssh_output=$(ssh "$REMOTE_HOST" "$remote_command"); then
  echo "[ERROR] Failed to query remote HLD directory ${REMOTE_HOST}:${REMOTE_DIR}" >&2
  exit 1
fi

tmp_csv=$(mktemp)
trap 'rm -f "$tmp_csv"' EXIT

{
  echo "filename,remote_path,remote_size_bytes,remote_mtime_epoch"
  while IFS=',' read -r filename size epoch; do
    filename="${filename#./}"
    if [[ -z "$filename" ]]; then
      continue
    fi
    size="${size:-0}"
    epoch="${epoch:-0}"
    remote_path="${REMOTE_DIR%/}/$filename"
    printf '%s,%s,%s,%s\n' "$filename" "$remote_path" "$size" "$epoch"
  done <<< "$ssh_output"
} > "$tmp_csv"

mv "$tmp_csv" "$OUTPUT_PATH"
echo "[INFO] Remote inventory written to: $OUTPUT_PATH"
