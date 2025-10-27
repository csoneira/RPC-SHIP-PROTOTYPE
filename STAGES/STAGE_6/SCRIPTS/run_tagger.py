from pathlib import Path
import csv
from datetime import datetime, timezone

SCRIPT_DIR = Path(__file__).resolve().parent
STAGE_ROOT = SCRIPT_DIR.parent
REPO_ROOT = STAGE_ROOT.parents[1]
STAGE4_ROOT = REPO_ROOT / "STAGES" / "STAGE_4"

run_path = REPO_ROOT / "file_run_dictionary.csv"
db_path = STAGE4_ROOT / "DATA" / "DATA_LOGS" / "file_database.csv"
out_path = STAGE_ROOT / "DATA" / "DATA_LOGS" / "file_logbook.csv"

out_path.parent.mkdir(parents=True, exist_ok=True)

if not run_path.exists() or not db_path.exists():
    raise FileNotFoundError("Required input files are missing in the current directory.")

# Load run windows in order so the first match wins.
runs = []
with run_path.open(newline="", encoding="utf-8") as run_file:
    reader = csv.DictReader(run_file)
    for row in reader:
        try:
            # allow either run_id or run as the identifier column
            run_id = (row.get("run_id") or row.get("run") or "").strip()
            start_str = (row.get("start") or "").strip()
            end_str = (row.get("end") or "").strip()
            if not start_str:
                raise ValueError("missing start")
            start = datetime.strptime(start_str, "%Y-%m-%d %H:%M:%S")
            if end_str:
                end = datetime.strptime(end_str, "%Y-%m-%d %H:%M:%S")
            else:
                end = datetime.now(timezone.utc).replace(tzinfo=None)
        except (KeyError, AttributeError, ValueError):
            continue  # Skip rows missing required fields.
        if not run_id or start > end:
            continue  # Ignore empty IDs or malformed windows.
        runs.append((run_id, start, end))

matches = {}
seen_files = set()

with db_path.open(newline="", encoding="utf-8") as db_file:
    reader = csv.DictReader(db_file)
    for row in reader:
        filename = (row.get("filename") or "").strip()
        if not filename:
            continue

        try:
            parsed_time = datetime.strptime(filename, "dabc%y%j%H%M%S.hld")
            parsed_time = parsed_time.replace(year=2000 + int(filename[4:6]))
        except (ValueError, IndexError):
            continue  # Skip filenames that do not match the expected pattern.

        match_id = None
        for run_id, start, end in runs:
            if start <= parsed_time <= end:
                match_id = run_id
                break

        if match_id and filename not in seen_files:
            timestamp_str = parsed_time.strftime("%Y-%m-%d %H:%M:%S")
            run_entries = matches.setdefault(match_id, {})
            run_entries[filename] = timestamp_str
            seen_files.add(filename)

with out_path.open("w", newline="", encoding="utf-8") as out_file:
    writer = csv.writer(out_file)
    writer.writerow(["filename", "timestamp_utc", "run_id"])

    for run_id in sorted(matches):
        for filename in sorted(matches[run_id]):
            writer.writerow([
                filename,
                matches[run_id][filename],
                run_id,
            ])
