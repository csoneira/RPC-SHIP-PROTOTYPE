
# Bring hlds file from rpcuser@odroid64:/home/rpcuser/hlds/*.hld to 
# /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/unpacker/hlds_toUnpack,
# create a csv in /home/csoneira/WORK/LIP_stuff/JOAO_SETUP that tracks which
# files have been copied already and in which date so there are two columns,
# name of the file and date of copy. If the file is already there, do not copy it again.
#
# Usage: bash bring_hlds.sh [START_DATE]
#   START_DATE (optional): Only copy files from this date onwards (format: YYYY-MM-DD)
#   Example: bash bring_hlds.sh 2025-01-15

#!/bin/bash

SRC="joao:/home/rpcuser/hlds/*.hld"
DEST="/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES"
CSV="/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/file_database.csv"

# Optional start date filter (format: YYYY-MM-DD)
START_DATE_FILTER="$1"

# Function to strip suffix from filename
strip_suffix() {
  local name="$1"
  name="${name%.hld}"
  printf '%s' "$name"
}

# Function to extract date from filename
compute_start_date() {
  local name="$1"
  local base
  base=$(strip_suffix "$name")
  if [[ $base =~ ([0-9]{11})$ ]]; then
    local digits=${BASH_REMATCH[1]}
    local yy=${digits:0:2}
    local doy=${digits:2:3}
    local hhmmss=${digits:5:6}
    local hh=${hhmmss:0:2}
    local mm=${hhmmss:2:2}
    local ss=${hhmmss:4:2}
    local year=$((2000 + 10#$yy))
    local offset=$((10#$doy - 1))
    (( offset < 0 )) && offset=0
    local date_value
    date_value=$(date -d "${year}-01-01 +${offset} days ${hh}:${mm}:${ss}" '+%Y-%m-%d_%H.%M.%S' 2>/dev/null) || date_value=""
    printf '%s' "$date_value"
  else
    printf ''
  fi
}

# Function to check if file date is >= start date filter
should_copy_file() {
  local filename="$1"
  local filter_date="$2"
  
  # If no filter is set, copy all files
  if [ -z "$filter_date" ]; then
    return 0
  fi
  
  # Extract date from filename
  local file_datetime
  file_datetime=$(compute_start_date "$filename")
  
  if [ -z "$file_datetime" ]; then
    # Could not parse date from filename, skip it
    return 1
  fi
  
  # Extract just the date part (YYYY-MM-DD)
  local file_date="${file_datetime:0:10}"
  
  # Convert dates to seconds since epoch for comparison
  local file_epoch
  local filter_epoch
  file_epoch=$(date -d "$file_date" +%s 2>/dev/null)
  filter_epoch=$(date -d "$filter_date" +%s 2>/dev/null)
  
  if [ -z "$file_epoch" ] || [ -z "$filter_epoch" ]; then
    # Date conversion failed
    return 1
  fi
  
  # Return 0 (true) if file date >= filter date
  [ "$file_epoch" -ge "$filter_epoch" ]
  return $?
}

echo "=========================================="
echo "HLD File Transfer Script"
echo "=========================================="
echo "Source: $SRC"
echo "Destination: $DEST"
echo "Database: $CSV"
if [ -n "$START_DATE_FILTER" ]; then
    echo "Date filter: Only files >= $START_DATE_FILTER"
else
    echo "Date filter: None (all files)"
fi
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Create the destination directory if it doesn't exist
if [ ! -d "$DEST" ]; then
    echo "[INFO] Creating destination directory: $DEST"
    mkdir -p "$DEST"
else
    echo "[INFO] Destination directory exists: $DEST"
fi
echo ""

# Create the CSV file if it doesn't exist
if [ ! -f "$CSV" ]; then
    echo "[INFO] Creating new database file: $CSV"
    echo "filename,date" > "$CSV"
else
    echo "[INFO] Using existing database file: $CSV"
    existing_count=$(tail -n +2 "$CSV" | wc -l)
    echo "[INFO] Database contains $existing_count previously copied file(s)"
fi
echo ""

# First, get list of remote files
echo "[INFO] Fetching list of remote files..."
remote_files=$(ssh joao "ls -1 /home/rpcuser/hlds/*.hld 2>/dev/null" | wc -l)
echo "[INFO] Found $remote_files file(s) on remote server"
echo ""

# Counter for statistics
copied_count=0
skipped_count=0
failed_count=0
filtered_count=0
file_number=0

# Copy the files and update the CSV
echo "=========================================="
echo "Starting file transfer..."
echo "=========================================="
echo ""

# Get the list of files into an array
mapfile -t remote_file_list < <(ssh joao "ls -1 /home/rpcuser/hlds/*.hld 2>/dev/null")

# Check if we got any files
if [ ${#remote_file_list[@]} -eq 0 ]; then
    echo "[WARNING] No .hld files found on remote server or connection failed"
    echo "=========================================="
    exit 1
fi

for file in "${remote_file_list[@]}"; do
    filename=$(basename "$file")
    
    # Skip if filename is empty or is a wildcard pattern
    if [ -z "$filename" ] || [[ "$filename" == "*"* ]]; then
        echo "[WARNING] Invalid filename detected: '$filename' - skipping"
        continue
    fi
    
    file_number=$((file_number + 1))
    
    echo "[$file_number/$remote_files] Processing: $filename"
    
    # Check if file passes date filter
    if ! should_copy_file "$filename" "$START_DATE_FILTER"; then
        file_datetime=$(compute_start_date "$filename")
        if [ -n "$file_datetime" ]; then
            file_date="${file_datetime:0:10}"
            echo "  [FILTERED] File date ($file_date) is before filter date ($START_DATE_FILTER)"
        else
            echo "  [FILTERED] Could not parse date from filename"
        fi
        filtered_count=$((filtered_count + 1))
        echo ""
        continue
    fi
    
    # Display file date if parsed successfully
    file_datetime=$(compute_start_date "$filename")
    if [ -n "$file_datetime" ]; then
        echo "  [DATE] File timestamp: $file_datetime"
    fi
    
    if [ -f "$DEST/$filename" ]; then
        echo "  [SKIP] File already exists locally"
        skipped_count=$((skipped_count + 1))
    else
        # Get file size from remote
        file_size=$(ssh joao "stat -c%s /home/rpcuser/hlds/$filename 2>/dev/null")
        if [ -n "$file_size" ]; then
            file_size_mb=$(echo "scale=2; $file_size / 1048576" | bc)
            echo "  [COPY] File size: ${file_size_mb} MB"
        fi
        
        echo "  [COPY] Starting transfer at $(date '+%H:%M:%S')..."
        
        # Use scp (will show progress automatically if terminal supports it)
        if scp "joao:/home/rpcuser/hlds/$filename" "$DEST/" ; then
            copy_date=$(date +%Y-%m-%d)
            copy_time=$(date '+%H:%M:%S')
            echo "$filename,$copy_date" >> "$CSV"
            echo "  [SUCCESS] Copied to $DEST at $copy_time"
            copied_count=$((copied_count + 1))
        else
            echo "  [ERROR] Failed to copy $filename (exit code: $?)"
            failed_count=$((failed_count + 1))
        fi
    fi
    echo ""
done

# Final summary
echo "=========================================="
echo "Transfer Summary"
echo "=========================================="
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Total files found: $remote_files"
if [ -n "$START_DATE_FILTER" ]; then
    echo "Files filtered (before $START_DATE_FILTER): $filtered_count"
fi
echo "Files copied: $copied_count"
echo "Files skipped (already exist): $skipped_count"
echo "Files failed: $failed_count"
echo "=========================================="


