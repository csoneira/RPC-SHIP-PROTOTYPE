#!/bin/bash

# Google Sheet ID and GID (worksheet/tab ID)
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $0

Download the current online logbook CSV from the configured Google Sheet and
store it as file_online_logbook.csv in the JOAO_SETUP workspace.
EOF
  exit 0
fi

SHEET_ID="1exbML95XhVeCf_810DScvRs1JnUW8ke-efMeSlrKpZ8"
GID="805688773"

# Output filename
OUTPUT="/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/file_online_logbook.csv"

# Download as CSV using available tool (curl, wget, or python)
URL="https://docs.google.com/spreadsheets/d/${SHEET_ID}/export?format=csv&gid=${GID}"

download_with_curl() {
	curl -fsSL -o "$OUTPUT" "$URL"
}

download_with_wget() {
	wget -q -O "$OUTPUT" "$URL"
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
	download_with_python "$URL" "$OUTPUT"
fi

echo "Downloaded to $OUTPUT"
