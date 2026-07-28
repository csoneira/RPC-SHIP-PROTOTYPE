#!/usr/bin/env bash

# Copy MAT files that are missing locally or have changed remotely.
set -euo pipefail

# TOMAR DAQ acquisition directory (via the configured SSH alias). Keep the local
# destination unchanged: the Octave analysis reads MAT files from TOMAR/DATA.
remote_host='tomar_at_rpcadvance'
remote_dir='~/gate/tomar/system/devices/TRB3/data/daqData/varData'
destination_dir='/home/csoneira/RPC-SHIP-PROTOTYPE/TOMAR/DATA'

mkdir -p "$destination_dir"

while IFS=$'\t' read -r file_name remote_size remote_mtime_raw; do
    [[ -z "$file_name" ]] && continue
    destination_file="$destination_dir/$file_name"
    remote_mtime="${remote_mtime_raw%%.*}"
    if [[ ! -e "$destination_file" ]]; then
        printf '[COPY] %s\n' "$file_name"
        scp -p "$remote_host:$remote_dir/$file_name" "$destination_file"
        continue
    fi

    local_size="$(stat -c '%s' "$destination_file")"
    local_mtime="$(stat -c '%Y' "$destination_file")"
    if [[ "$local_size" == "$remote_size" && "$local_mtime" == "$remote_mtime" ]]; then
        printf '[SKIP] Unchanged: %s\n' "$file_name"
    else
        printf '[UPDATE] Remote version changed: %s\n' "$file_name"
        scp -p "$remote_host:$remote_dir/$file_name" "$destination_file"
    fi
done < <(ssh "$remote_host" "find $remote_dir -maxdepth 1 -type f -name 'dabc*.mat' -printf '%f\\t%s\\t%T@\\n' | sort")
