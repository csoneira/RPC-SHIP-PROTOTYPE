#!/bin/bash

# I want to use this script to retrieve logs from joao:/home/rpcuser/logs and place them under
# /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/DATA/RAW

set -euo pipefail

# ----------------------------------------------
# Only this changes between mingos and computers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_ROOT="${LOG_ROOT}/DATA"
STATUS_DIR="${DATA_ROOT}/STATUS"
RAW_DIR="${DATA_ROOT}/RAW"
CLEAN_DIR="${DATA_ROOT}/CLEAN"
LOG_DB="${LOG_ROOT}/log_database.csv"

STATUS_HELPER="${SCRIPT_DIR}/status_csv.py"
STATUS_TIMESTAMP=""
STATUS_CSV="${STATUS_DIR}/log_bring_and_clean.csv"

mkdir -p "${RAW_DIR}" "${CLEAN_DIR}" "${STATUS_DIR}"
if [ ! -f "$LOG_DB" ]; then
  echo "filename,log_date,bring_date" > "$LOG_DB"
elif ! grep -q '^filename,' "$LOG_DB" 2>/dev/null; then
  tmp_file="${LOG_DB}.tmp"
  {
    echo "filename,log_date,bring_date"
    cat "$LOG_DB"
  } > "$tmp_file"
  mv "$tmp_file" "$LOG_DB"
fi

declare -A PROCESSED_FILES
while IFS=, read -r stored_filename _; do
  [[ -z "$stored_filename" || "$stored_filename" == "filename" ]] && continue
  PROCESSED_FILES["$stored_filename"]=1
done < "$LOG_DB"
python_script_path="${SCRIPT_DIR}/log_aggregate_and_join.py"

if [ ! -x "$python_script_path" ] && [ ! -f "$python_script_path" ]; then
  echo "Error: Expected python script at $python_script_path" >&2
  exit 1
fi

if ! STATUS_TIMESTAMP="$(python3 "$STATUS_HELPER" append "$STATUS_CSV")"; then
  echo "Warning: unable to record status in $STATUS_CSV" >&2
  STATUS_TIMESTAMP=""
fi

finish() {
  local exit_code="$1"
  if [[ ${exit_code} -eq 0 && -n "${STATUS_TIMESTAMP:-}" && -n "${STATUS_CSV:-}" ]]; then
    python3 "$STATUS_HELPER" complete "$STATUS_CSV" "$STATUS_TIMESTAMP" >/dev/null 2>&1 || true
  fi
}

trap 'finish $?' EXIT

local_destination="${RAW_DIR}"
DONE_DIR="${local_destination}/done"
OUTPUT_DIR="${CLEAN_DIR}"

mkdir -p "${local_destination}" "${DONE_DIR}" "${OUTPUT_DIR}"


echo '--------------------------- bash script starts ---------------------------'

remote_host="${REMOTE_LOG_HOST:-joao}"
remote_path="${remote_host}:/home/rpcuser/logs/"

# Sync data from the remote server
rsync -avz --delete \
    --exclude='/clean_*' \
    --exclude='/done/clean_*' \
    --exclude='/done/merged_*' \
    "$remote_path" "$local_destination"

echo 'Received data from remote computer'

mkdir -p "$OUTPUT_DIR"

declare -A COLUMN_COUNTS
COLUMN_COUNTS["hv4_"]=24
COLUMN_COUNTS["hv5_"]=23
COLUMN_COUNTS["rates_"]=29
COLUMN_COUNTS["sensors_bus0_"]=7

extract_log_date() {
    local name="$1"
    local base="${name%.log}"
    local date_part="${base##*_}"
    printf '%s' "$date_part"
}

record_log_entry() {
    local filename="$1"
    local log_date="$2"
    local bring_date
    bring_date="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s,%s,%s\n' "$filename" "$log_date" "$bring_date" >> "$LOG_DB"
    PROCESSED_FILES["$filename"]=1
}

process_file() {
    local file=$1
    local filename=$(basename "$file")

    if [[ $filename == .* ]]; then
        return
    fi

    if [[ -n "${PROCESSED_FILES[$filename]:-}" ]]; then
        return
    fi

    local output_file="$OUTPUT_DIR/$filename"
    local log_date
    log_date=$(extract_log_date "$filename")

    # Check if the file needs to be processed
    if [[ -f "$output_file" ]]; then
        # Compare modification timestamps
        local source_mtime=$(stat -c %Y "$file")
        local processed_mtime=$(stat -c %Y "$output_file")
        
        #source_mtime_save=$(stat -c %Y "$file")
        #processed_mtime_save=$(stat -c %Y "$output_file")
        
        if [[ $source_mtime -le $processed_mtime ]]; then
            #echo "File $filename is already processed and up-to-date. Skipping."
            record_log_entry "$filename" "$log_date"
            return
        fi
    fi

    # Process the file
    for prefix in "${!COLUMN_COUNTS[@]}"; do
        if [[ $filename == $prefix* ]]; then
            local column_count=${COLUMN_COUNTS[$prefix]}
            awk -v col_count=$column_count -v output_file="$output_file" -v file="$file" '
		    BEGIN { OFS=" "; invalid_count=0; valid_count=0 }
		    {
			  gsub(/T/, " ", $1);      # Replace T with space
			  gsub(/[,;]/, " ");       # Replace commas and semicolons with space
			  gsub(/  +/, " ");        # Replace multiple spaces with a single space
			  if (NF >= col_count) {   # Keep rows with at least the expected number of fields
				valid_count++;
				print $0 > output_file
			  } else {
				invalid_count++;
			  }
		    }
		    END {
			  if (invalid_count > 0) {   # Only print the message if invalid rows were found
				print "Processed: " valid_count " valid rows, " invalid_count " discarded rows." > "/dev/stderr"
				print "Processed " file " into " output_file > "/dev/stderr"
			  }
		    }
		' "$file"

            #echo "Processed $file into $output_file."
		#echo $source_mtime_save
		#echo $processed_mtime_save
		#echo '-------------------'
            record_log_entry "$filename" "$log_date"
            return
        fi
    done

    #echo "Unknown file prefix: $filename. Skipping $file."
}

process_directory() {
    local dir=$1
    for file in "$dir"/*; do
        if [[ -f "$file" ]]; then
            process_file "$file"
        fi
    done
}

process_directory "$local_destination"
process_directory "$DONE_DIR"

echo "Files cleaned into $OUTPUT_DIR"

# Call the python joiner execution
python3 -u "$python_script_path"

echo '------------------------------------------------------'
echo "log_bring_and_clear.sh completed on: $(date '+%Y-%m-%d %H:%M:%S')"
echo '------------------------------------------------------'
