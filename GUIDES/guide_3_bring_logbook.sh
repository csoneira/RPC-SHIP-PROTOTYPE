#!/bin/bash

# Google Sheet ID and GID (worksheet/tab ID)
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $0

Download the current online logbook CSV from the configured Google Sheet and
store it as file_online_logbook.csv in this repository workspace.
EOF
  exit 0
fi

SHEET_ID="1exbML95XhVeCf_810DScvRs1JnUW8ke-efMeSlrKpZ8"
GID="805688773"

# Output filename
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT="$REPO_ROOT/STAGES/STAGE_3/DATA/DATA_LOGS/file_online_logbook.csv"

mkdir -p "$(dirname "$OUTPUT")"

# Download as CSV using available tool (curl, wget, or python), then trim unused
# trailing empty columns so downstream scripts see only the populated fields.
URL="https://docs.google.com/spreadsheets/d/${SHEET_ID}/export?format=csv&gid=${GID}"
TMP_CSV="$(mktemp)"
cleanup() { rm -f "$TMP_CSV"; }
trap cleanup EXIT

download_with_curl() {
	curl -fsSL -o "$TMP_CSV" "$URL"
}

download_with_wget() {
	wget -q -O "$TMP_CSV" "$URL"
}

download_with_python() {
	python3 - <<'PYCODE'
import sys
import urllib.request

url = sys.argv[1]
output = sys.argv[2]

try:
	with urllib.request.urlopen(url) as response, open(output, "wb") as f:
		f.write(response.read())
except Exception as exc:
	raise SystemExit(f"Failed to download {url}: {exc}")
PYCODE
}

if command -v curl >/dev/null 2>&1; then
	download_with_curl
elif command -v wget >/dev/null 2>&1; then
	download_with_wget
else
	download_with_python "$URL" "$TMP_CSV"
fi

# Normalize columns: drop trailing empty columns across the file
python3 - <<'PYCODE' "$TMP_CSV" "$OUTPUT"
import csv
import sys
from pathlib import Path

src, dest = sys.argv[1], sys.argv[2]

with open(src, newline="", encoding="utf-8") as handle:
	rows = list(csv.reader(handle))

last_non_empty = -1
for row in rows:
	for idx, cell in enumerate(row):
		if cell.strip():
			last_non_empty = max(last_non_empty, idx)

dest_path = Path(dest)
dest_path.parent.mkdir(parents=True, exist_ok=True)
with dest_path.open("w", newline="", encoding="utf-8") as handle:
	writer = csv.writer(handle)
	for row in rows:
		writer.writerow(row[: last_non_empty + 1] if last_non_empty >= 0 else [])
PYCODE

echo "Downloaded and normalized to $OUTPUT"
