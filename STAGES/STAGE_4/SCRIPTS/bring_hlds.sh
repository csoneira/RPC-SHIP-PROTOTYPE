
# Bring hlds file from rpcuser@odroid64:/home/rpcuser/hlds/*.hld to 
# /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES/NOT_UNPACKED,
# create a csv in /home/csoneira/WORK/LIP_stuff/JOAO_SETUP that tracks which
# files have been copied already and in which date so there are two columns,
# name of the file and date of copy. If the file is already there, do not copy it again.
#
# Usage: bash bring_hlds.sh [START_DATE]
#   START_DATE (optional): Only copy files from this date onwards (format: YYYY-MM-DD)
#   Example: bash bring_hlds.sh 2025-01-15

#!/bin/bash

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -s, --start-date <YYYY-MM-DD>   Only consider files with dates on/after this day.
  -r, --run <id>[,<id>...]        Only copy files tagged for the selected runs.
  -h, --help                      Show this message and exit.

The legacy positional START_DATE argument remains supported.
EOF
}

SRC="joao:/home/rpcuser/hlds/*.hld"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_ROOT="$(dirname "$SCRIPT_DIR")"
STAGES_ROOT="$(dirname "$STAGE_ROOT")"
STAGE5_ROOT="$STAGES_ROOT/STAGE_5"
DATA_ROOT="$STAGE_ROOT/DATA"
DEST="$DATA_ROOT/DATA_FILES/HLD_FILES/NOT_UNPACKED"
CSV="${HLD_FILE_DATABASE:-$DATA_ROOT/DATA_LOGS/file_database.csv}"
REMOTE_RUN_LOG="${HLD_REMOTE_RUN_LOG:-$DATA_ROOT/DATA_LOGS/remote_run_logbook.csv}"
SENT_DIR="${HLD_SENT_DIR:-$DATA_ROOT/DATA_FILES/HLD_FILES/SENT_TO_UNPACKING}"
ERROR_DIR="${HLD_ERROR_DIR:-$DATA_ROOT/DATA_FILES/HLD_FILES/ERROR}"
UNPACK_LOG="${HLD_UNPACK_LOG:-$STAGE5_ROOT/DATA/DATA_LOGS/unpack_database.csv}"
EXCLUDE_CONFIG="${HLD_EXCLUDE_CONFIG:-$DATA_ROOT/CONFIGS/hld_exclude_patterns.txt}"
ALL_UNPACKED_DIR="${HLD_ALL_UNPACKED:-$STAGE5_ROOT/DATA/DATA_FILES/ALL_UNPACKED}"

START_DATE_FILTER=""
declare -a SELECTED_RUNS=()
declare -A SELECTED_RUN_MAP=()
POS_ARGS=()

parse_runs() {
  IFS=',' read -ra parts <<< "$1"
  for run in "${parts[@]}"; do
    trimmed="${run//[[:space:]]/}"
    if [[ -n "$trimmed" ]]; then
      SELECTED_RUNS+=("$trimmed")
      SELECTED_RUN_MAP["$trimmed"]=1
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--start-date)
      if [[ $# -lt 2 ]]; then
        echo "Error: --start-date expects a value." >&2
        exit 1
      fi
      START_DATE_FILTER="$2"
      shift 2
      ;;
    -r|--run|--runs)
      if [[ $# -lt 2 ]]; then
        echo "Error: --run expects a value." >&2
        exit 1
      fi
      parse_runs "$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POS_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$START_DATE_FILTER" && ${#POS_ARGS[@]} -gt 0 ]]; then
  START_DATE_FILTER="${POS_ARGS[0]}"
fi

declare -A recorded_files=()
declare -A recorded_timestamps=()
declare -A allowed_files=()
declare -A file_run_map=()
declare -A sent_exclude_map=()
declare -A error_exclude_map=()
declare -A unpacked_files=()
EXCLUDE_PATTERNS=()

if [[ -f "$UNPACK_LOG" ]]; then
  while IFS=',' read -r fname _; do
    [[ -z "$fname" || "$fname" == "filename" ]] && continue
    unpacked_files["$fname"]=1
  done < <(tail -n +2 "$UNPACK_LOG")
  if [[ ${#unpacked_files[@]} -gt 0 ]]; then
    echo "[INFO] Loaded ${#unpacked_files[@]} unpacked record(s) from $UNPACK_LOG"
  fi
fi

if [[ -n "$SENT_DIR" ]]; then
  mkdir -p "$SENT_DIR"
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ -n "${unpacked_files[$entry]:-}" ]]; then
      sent_exclude_map["$entry"]=1
    else
      echo "[INFO] SENT_TO_UNPACKING entry $entry has no unpack log entry; allowing re-fetch."
    fi
  done < <(find "$SENT_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true)
  if [[ ${#sent_exclude_map[@]} -gt 0 ]]; then
    echo "[INFO] Excluding ${#sent_exclude_map[@]} file(s) already in SENT_TO_UNPACKING."
  fi
fi

if [[ -n "$ERROR_DIR" ]]; then
  mkdir -p "$ERROR_DIR"
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    error_exclude_map["$entry"]=1
  done < <(find "$ERROR_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true)
  if [[ ${#error_exclude_map[@]} -gt 0 ]]; then
    echo "[INFO] Excluding ${#error_exclude_map[@]} file(s) marked as errors."
  fi
fi

if [[ -f "$EXCLUDE_CONFIG" ]]; then
  while IFS= read -r pattern; do
    pattern="${pattern%%#*}"
    pattern="${pattern//$'\r'/}"
    pattern="${pattern//$'\n'/}"
    pattern="${pattern#"${pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    [[ -z "$pattern" ]] && continue
    EXCLUDE_PATTERNS+=("$pattern")
  done < "$EXCLUDE_CONFIG"
  if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
    echo "[INFO] Loaded ${#EXCLUDE_PATTERNS[@]} exclusion pattern(s) from $EXCLUDE_CONFIG"
  fi
fi

if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
  if [[ ! -f "$REMOTE_RUN_LOG" ]]; then
    echo "[ERROR] Run selection requested but remote run log not found at $REMOTE_RUN_LOG" >&2
    exit 1
  fi
  while IFS=',' read -r filename ts run_id; do
    if [[ "$filename" == "filename" ]]; then
      continue
    fi
    filename="${filename//[$'\r\n']/}"
    run_id="${run_id//[$'\r\n']/}"
    if [[ -z "$filename" || -z "$run_id" ]]; then
      continue
    fi
    file_run_map["$filename"]="$run_id"
    if [[ -n "${SELECTED_RUN_MAP[$run_id]:-}" ]]; then
      allowed_files["$filename"]=1
    fi
  done < "$REMOTE_RUN_LOG"

  if [[ ${#allowed_files[@]} -eq 0 ]]; then
    echo "[WARN] No remote files matched the requested runs (${SELECTED_RUNS[*]})." >&2
  fi
fi

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
if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
    echo "Run filter: ${SELECTED_RUNS[*]}"
    if [[ ! -s "$REMOTE_RUN_LOG" ]]; then
        echo "[WARN] Remote run log appears empty ($REMOTE_RUN_LOG)"
    fi
else
    echo "Run filter: None (all tagged files)"
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

mkdir -p "$(dirname "$CSV")"

# Create the CSV file if it doesn't exist
if [ ! -f "$CSV" ]; then
    echo "[INFO] Creating new database file: $CSV"
    echo "filename,date,time" > "$CSV"
else
    echo "[INFO] Using existing database file: $CSV"
    header_line=$(head -n 1 "$CSV")
    if [ "$header_line" = "filename,date" ]; then
        echo "[INFO] Upgrading database schema to include time column"
        tmp_csv=$(mktemp)
        {
            echo "filename,date,time"
            tail -n +2 "$CSV" | while IFS= read -r line || [ -n "$line" ]; do
                if [ -n "$line" ]; then
                    echo "${line},"
                else
                    echo ""
                fi
            done
        } > "$tmp_csv"
        mv "$tmp_csv" "$CSV"
    elif [ "$header_line" != "filename,date,time" ]; then
        echo "[WARNING] Unexpected CSV header '$header_line' (expected filename,date[,time])"
    fi
    existing_count=$(tail -n +2 "$CSV" | grep -c '^[^,]')
    echo "[INFO] Database contains $existing_count previously copied file(s)"
fi
echo ""

if [ -f "$CSV" ]; then
    while IFS=',' read -r fname copy_date copy_time _; do
        if [ -z "$fname" ] || [ "$fname" = "filename" ]; then
            continue
        fi
        recorded_files["$fname"]=1
        if [ -n "$copy_date" ] || [ -n "$copy_time" ]; then
            recorded_timestamps["$fname"]="${copy_date} ${copy_time}"
        fi
    done < <(tail -n +2 "$CSV")
fi

# First, get list of remote files
echo "[INFO] Fetching list of remote files..."
remote_files=$(ssh joao "ls -1 /home/rpcuser/hlds/*.hld 2>/dev/null" | wc -l)
echo "[INFO] Found $remote_files file(s) on remote server"
echo ""

# Counter for statistics
copied_count=0
skipped_local_count=0
skipped_recorded_count=0
skipped_run_filtered_count=0
skipped_unmapped_count=0
skipped_error_archive_count=0
skipped_sent_archive_count=0
skipped_already_unpacked_count=0
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

    if [[ -n "${error_exclude_map[$filename]:-}" ]]; then
        echo "  [SKIP] File is marked as errored; skipping."
        skipped_error_archive_count=$((skipped_error_archive_count + 1))
        echo ""
        continue
    fi

    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        skip_due_to_pattern=false
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$filename" == $pattern ]]; then
                skip_due_to_pattern=true
                matched_pattern="$pattern"
                break
            fi
        done
        if [[ "$skip_due_to_pattern" == true ]]; then
            echo "  [SKIP] Matches exclusion pattern '$matched_pattern'; sending to ERROR directory."
            mkdir -p "$ERROR_DIR"
            if scp "joao:/home/rpcuser/hlds/$filename" "$ERROR_DIR/" ; then
                error_exclude_map["$filename"]=1
            else
                echo "  [WARN] Failed to copy $filename to ERROR directory; marking as skipped."
            fi
            if [[ -f "$DEST/$filename" ]]; then
                mv "$DEST/$filename" "$ERROR_DIR/$filename" 2>/dev/null || rm -f "$DEST/$filename"
            fi
            skipped_error_archive_count=$((skipped_error_archive_count + 1))
            echo ""
            continue
        fi
    fi

    prefix="${filename%.hld}"
    if [[ -d "$ALL_UNPACKED_DIR" ]]; then
        shopt -s nullglob
        matches=("$ALL_UNPACKED_DIR/${prefix}"*)
        shopt -u nullglob
        if [[ ${#matches[@]} -gt 0 ]]; then
            echo "  [SKIP] Directory exists in ALL_UNPACKED for prefix ${prefix}; skipping fetch."
            if [[ -f "$DEST/$filename" ]]; then
                rm -f "$DEST/$filename"
            fi
            skipped_already_unpacked_count=$((skipped_already_unpacked_count + 1))
            echo ""
            continue
        fi
    fi

    if [[ -n "${sent_exclude_map[$filename]:-}" ]]; then
        echo "  [SKIP] File is already stored in SENT_TO_UNPACKING; skipping."
        skipped_sent_archive_count=$((skipped_sent_archive_count + 1))
        echo ""
        continue
    fi
    
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
   
    if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
        run_tag="${file_run_map[$filename]:-}"
        if [[ -z "$run_tag" ]]; then
            echo "  [SKIP] No run tag available; cannot map to requested runs"
            skipped_unmapped_count=$((skipped_unmapped_count + 1))
            echo ""
            continue
        fi
        if [[ -z "${allowed_files[$filename]:-}" ]]; then
            echo "  [SKIP] Tagged for run ${run_tag}, not requested"
            skipped_run_filtered_count=$((skipped_run_filtered_count + 1))
            echo ""
            continue
        fi
    fi
   
    if [[ -n "${recorded_files[$filename]+x}" ]]; then
        if [[ -z "${unpacked_files[$filename]:-}" ]]; then
            echo "  [INFO] File logged previously but no unpack record found; re-copying."
        else
            seen_ts="${recorded_timestamps[$filename]}"
            if [ -n "$seen_ts" ]; then
                echo "  [SKIP] Already logged in database ($seen_ts)"
            else
                echo "  [SKIP] Already logged in database"
            fi
            skipped_recorded_count=$((skipped_recorded_count + 1))
            echo ""
            continue
        fi
    fi

    if [ -f "$DEST/$filename" ]; then
        echo "  [SKIP] File already exists locally"
        skipped_local_count=$((skipped_local_count + 1))
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
            echo "$filename,$copy_date,$copy_time" >> "$CSV"
            echo "  [SUCCESS] Copied to $DEST at $copy_time"
            copied_count=$((copied_count + 1))
            recorded_files["$filename"]=1
            recorded_timestamps["$filename"]="$copy_date $copy_time"
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
echo "Files skipped (already recorded): $skipped_recorded_count"
echo "Files skipped (already exist locally): $skipped_local_count"
echo "Files skipped (present in SENT_TO_UNPACKING): $skipped_sent_archive_count"
echo "Files skipped (marked as errors): $skipped_error_archive_count"
echo "Files skipped (already unpacked): $skipped_already_unpacked_count"
if [[ ${#SELECTED_RUNS[@]} -gt 0 ]]; then
    echo "Files skipped (outside requested runs): $skipped_run_filtered_count"
    echo "Files skipped (missing run tag): $skipped_unmapped_count"
fi
echo "Files failed: $failed_count"
echo "=========================================="
