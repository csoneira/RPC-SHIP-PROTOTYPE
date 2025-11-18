from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
STAGES_ROOT = REPO_ROOT / "STAGES"
STAGE3_ROOT = STAGES_ROOT / "STAGE_3"
STAGE4_ROOT = STAGES_ROOT / "STAGE_4"
STAGE5_ROOT = STAGES_ROOT / "STAGE_5"

DEFAULT_RUN_PATH = STAGE3_ROOT / "DATA" / "DATA_FILES" / "file_run_dictionary.csv"
DEFAULT_DB_PATH = STAGE4_ROOT / "DATA" / "DATA_LOGS" / "file_database.csv"
DEFAULT_OUTPUT_PATH = STAGE5_ROOT / "DATA" / "DATA_LOGS" / "file_logbook.csv"


@dataclass(frozen=True)
class RunWindow:
    run_id: str
    start: datetime
    end: datetime


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Tag HLD filenames with run identifiers using time windows."
    )
    parser.add_argument(
        "-r",
        "--runs-file",
        type=Path,
        default=DEFAULT_RUN_PATH,
        help=f"CSV describing runs (default: {DEFAULT_RUN_PATH})",
    )
    parser.add_argument(
        "-b",
        "--database",
        type=Path,
        default=DEFAULT_DB_PATH,
        help=f"CSV containing filenames to tag (default: {DEFAULT_DB_PATH})",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help=f"Destination CSV for filename → run mappings (default: {DEFAULT_OUTPUT_PATH})",
    )
    parser.add_argument(
        "--allow-missing-database",
        action="store_true",
        help="Do not fail if the database CSV is missing; emit an empty mapping instead.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress informational logging.",
    )
    return parser.parse_args()


def log(message: str, quiet: bool = False) -> None:
    if not quiet:
        print(message)


def load_run_windows(path: Path) -> list[RunWindow]:
    if not path.exists():
        raise FileNotFoundError(f"Run dictionary not found: {path}")
    windows: list[RunWindow] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            run_id = (row.get("run_id") or row.get("run") or "").strip()
            start_raw = (row.get("start") or "").strip()
            end_raw = (row.get("end") or "").strip()
            if not run_id or not start_raw:
                continue
            try:
                start_dt = datetime.strptime(start_raw, "%Y-%m-%d %H:%M:%S")
                if end_raw:
                    end_dt = datetime.strptime(end_raw, "%Y-%m-%d %H:%M:%S")
                else:
                    end_dt = datetime.max
            except ValueError:
                continue
            if start_dt > end_dt:
                continue
            windows.append(RunWindow(run_id=run_id, start=start_dt, end=end_dt))
    return sorted(windows, key=lambda item: (item.start, item.run_id))


def load_filenames(path: Path) -> list[str]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        filenames: list[str] = []
        for row in reader:
            name = (row.get("filename") or "").strip()
            if name:
                filenames.append(name)
    return filenames


def parse_hld_timestamp(filename: str) -> datetime | None:
    stem = Path(filename).name
    if not stem.startswith("dabc") or len(stem) < 4 + 11:
        return None
    payload = stem[4:]
    digits = payload[:11]
    if not digits.isdigit():
        return None
    year = 2000 + int(digits[:2])
    day_of_year = int(digits[2:5])
    hours = int(digits[5:7])
    minutes = int(digits[7:9])
    seconds = int(digits[9:11])
    try:
        base = datetime(year, 1, 1)
        timestamp = base + timedelta(days=day_of_year - 1, hours=hours, minutes=minutes, seconds=seconds)
    except ValueError:
        return None
    return timestamp


def tag_files(filenames: Iterable[str], runs: list[RunWindow]) -> list[tuple[str, datetime, str]]:
    seen: set[str] = set()
    tagged: list[tuple[str, datetime, str]] = []
    for name in sorted(filenames):
        if name in seen:
            continue
        timestamp = parse_hld_timestamp(name)
        if timestamp is None:
            continue
        for window in runs:
            if window.start <= timestamp <= window.end:
                tagged.append((name, timestamp, window.run_id))
                seen.add(name)
                break
    return tagged


def write_log(entries: list[tuple[str, datetime, str]], destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["filename", "timestamp_utc", "run_id"])
        for filename, timestamp, run_id in sorted(entries, key=lambda item: (int(item[2]) if item[2].isdigit() else item[2], item[1], item[0])):
            writer.writerow([filename, timestamp.strftime("%Y-%m-%d %H:%M:%S"), run_id])


def main() -> None:
    args = parse_args()

    runs = load_run_windows(args.runs_file)
    if not runs:
        raise SystemExit(f"No valid runs found in {args.runs_file}")

    if not args.database.exists():
        if args.allow_missing_database:
            log(f"[WARN] Database {args.database} not found; writing empty log.", args.quiet)
            write_log([], args.output)
            return
        raise FileNotFoundError(f"Database not found: {args.database}")

    filenames = load_filenames(args.database)
    if not filenames:
        log(f"[INFO] No filenames found in {args.database}; output will be empty.", args.quiet)

    entries = tag_files(filenames, runs)
    write_log(entries, args.output)
    log(f"[INFO] Wrote {len(entries)} tagged entries to {args.output}", args.quiet)


if __name__ == "__main__":
    main()
