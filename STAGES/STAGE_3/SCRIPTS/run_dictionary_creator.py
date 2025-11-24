#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable, Optional


SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
STAGE3_ROOT = SCRIPT_DIR.parent
DATA_LOG_ROOT = STAGE3_ROOT / "DATA" / "DATA_LOGS"
DATA_FILE_ROOT = STAGE3_ROOT / "DATA" / "DATA_FILES"

DEFAULT_LOGBOOK = DATA_LOG_ROOT / "file_online_logbook.csv"
DEFAULT_OUTPUT = DATA_FILE_ROOT / "file_run_dictionary.csv"
TIMESTAMP_FMT = "%Y-%m-%d %H:%M:%S"
OBS_INDEX = 17  # column containing operator comments inside the online logbook

JOANA_RUNS: list[dict[str, str | None]] = [
    {
        "run": "1",
        "start": "2025-04-30 13:37:44",
        "end": "2025-05-06 12:14:23",
        "comment": "Joana run 1. HV was high in both RPCs",
        "hv_ch1_start": 8990,
        "hv_ch1_end": 8990,
        "hv_ch2_start": 8990,
        "hv_ch2_end": 8990,
    },
    # {
    #     "run": "2",
    #     "start": "2025-05-07 15:10:27",
    #     "end": "2025-05-27 01:11:39",
    #     "comment": "Joana run 2. HV was high only in bottom RPC",
    # },
    {
        "run": "2",
        "start": "2025-05-07 15:10:27",
        "end": "2025-06-09 09:24:00",
        "comment": "Joana run 2 (former Run 3, which was like the 2 but longer). HV was high only in bottom RPC",
        "hv_ch1_start": 8990,
        "hv_ch1_end": 8990,
        "hv_ch2_start": 8990,
        "hv_ch2_end": 8990,
    },
]


@dataclass
class PendingRun:
    start: datetime
    comment: str
    file_hint: str
    notes: list[str]
    hv_start_ch1: Optional[float]
    hv_start_ch2: Optional[float]
    hv_last_ch1: Optional[float]
    hv_last_ch2: Optional[float]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a compact run dictionary (including HV setpoints) by reading the Stage 3 online logbook."
    )
    parser.add_argument(
        "--logbook",
        type=Path,
        default=DEFAULT_LOGBOOK,
        help=f"CSV with the online operations log (default: {DEFAULT_LOGBOOK})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=(
            "Destination CSV containing run,start,end,HV columns,comment "
            f"(default: {DEFAULT_OUTPUT})"
        ),
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress informational logging.",
    )
    return parser.parse_args()


def normalize_timestamp(raw: str | None) -> datetime | None:
    if not raw:
        return None
    compact = " ".join(raw.strip().split())
    if not compact:
        return None
    for fmt in ("%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M"):
        try:
            return datetime.strptime(compact, fmt)
        except ValueError:
            continue
    return None


def parse_number(raw: str | None) -> float | None:
    if raw is None:
        return None
    cleaned = raw.strip().replace(",", ".")
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def clean_cell(row: list[str], index: int) -> str:
    if index >= len(row):
        return ""
    return row[index].strip()


def build_comment(pending: PendingRun, observation: str, file_hint: str) -> str:
    candidates: list[str] = []
    for value in (pending.comment, observation, pending.file_hint, file_hint):
        value = (value or "").strip()
        if value:
            candidates.append(value)
    for note in pending.notes:
        clean = note.strip()
        if clean:
            candidates.append(clean)
    merged: list[str] = []
    for entry in candidates:
        if entry not in merged:
            merged.append(entry)
    if merged:
        return " | ".join(merged)
    return f"DAQ run starting {pending.start.strftime(TIMESTAMP_FMT)}"


def extract_runs_from_logbook(path: Path) -> list[dict[str, datetime | str | None]]:
    runs: list[dict[str, datetime | str | None]] = []
    pending: PendingRun | None = None
    current_hv_ch1: Optional[float] = None
    current_hv_ch2: Optional[float] = None

    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle)
        for row in reader:
            if len(row) < 3:
                continue
            row = [cell.strip() for cell in row]
            observation = clean_cell(row, OBS_INDEX) if len(row) > OBS_INDEX else ""
            file_hint = clean_cell(row, 6)

            row_type = (row[2] or "").lower()
            if row_type == "hv":
                hv_ch1 = parse_number(clean_cell(row, 3))
                hv_ch2 = parse_number(clean_cell(row, 4))
                if hv_ch1 is not None:
                    current_hv_ch1 = hv_ch1
                if hv_ch2 is not None:
                    current_hv_ch2 = hv_ch2
                if pending:
                    if hv_ch1 is not None:
                        pending.hv_last_ch1 = hv_ch1
                    if hv_ch2 is not None:
                        pending.hv_last_ch2 = hv_ch2
                continue

            if row_type != "daq":
                if pending and observation:
                    pending.notes.append(observation)
                continue

            action = clean_cell(row, 3).upper()
            timestamp = normalize_timestamp(row[1])
            if action not in {"START", "STOP"} or timestamp is None:
                continue

            if action == "START":
                if pending is not None:
                    runs.append(
                        {
                            "start": pending.start,
                            "end": timestamp,
                            "comment": build_comment(pending, "", ""),
                            "hv_ch1_start": pending.hv_start_ch1,
                            "hv_ch1_end": pending.hv_last_ch1,
                            "hv_ch2_start": pending.hv_start_ch2,
                            "hv_ch2_end": pending.hv_last_ch2,
                        }
                    )
                pending = PendingRun(
                    start=timestamp,
                    comment=observation,
                    file_hint=file_hint,
                    notes=[],
                    hv_start_ch1=current_hv_ch1,
                    hv_start_ch2=current_hv_ch2,
                    hv_last_ch1=current_hv_ch1,
                    hv_last_ch2=current_hv_ch2,
                )
            elif action == "STOP" and pending:
                comment = build_comment(pending, observation, file_hint)
                hv_end_ch1 = pending.hv_last_ch1 if pending.hv_last_ch1 is not None else pending.hv_start_ch1
                hv_end_ch2 = pending.hv_last_ch2 if pending.hv_last_ch2 is not None else pending.hv_start_ch2
                runs.append(
                    {
                        "start": pending.start,
                        "end": timestamp,
                        "comment": comment or f"DAQ run starting {pending.start.strftime(TIMESTAMP_FMT)}",
                        "hv_ch1_start": pending.hv_start_ch1,
                        "hv_ch1_end": hv_end_ch1,
                        "hv_ch2_start": pending.hv_start_ch2,
                        "hv_ch2_end": hv_end_ch2,
                    }
                )
                pending = None

    if pending:
        hv_end_ch1 = pending.hv_last_ch1 if pending.hv_last_ch1 is not None else pending.hv_start_ch1
        hv_end_ch2 = pending.hv_last_ch2 if pending.hv_last_ch2 is not None else pending.hv_start_ch2
        runs.append(
            {
                "start": pending.start,
                "end": None,
                "comment": build_comment(pending, "", ""),
                "hv_ch1_start": pending.hv_start_ch1,
                "hv_ch1_end": hv_end_ch1,
                "hv_ch2_start": pending.hv_start_ch2,
                "hv_ch2_end": hv_end_ch2,
            }
        )
    return sorted(runs, key=lambda entry: entry["start"] or datetime.max)


def format_hv(value: Optional[float]) -> str:
    if value is None:
        return ""
    if abs(value - round(value)) < 1e-6:
        return str(int(round(value)))
    return f"{value:.3f}".rstrip("0").rstrip(".")


def write_runs(rows: Iterable[dict[str, str]], destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "run",
                "start",
                "end",
                "hv_ch1_start",
                "hv_ch1_end",
                "hv_ch2_start",
                "hv_ch2_end",
                "comment",
            ],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def log(message: str, quiet: bool = False) -> None:
    if not quiet:
        print(message)


def main() -> None:
    args = parse_args()
    if not args.logbook.exists():
        raise FileNotFoundError(f"Logbook not found: {args.logbook}")

    log(f"[INFO] Reading logbook: {args.logbook}", args.quiet)
    computed_runs = extract_runs_from_logbook(args.logbook)

    output_rows: list[dict[str, str]] = []
    for entry in JOANA_RUNS:
        output_rows.append(
            {
                "run": str(entry.get("run", "")),
                "start": str(entry.get("start", "")),
                "end": str(entry.get("end", "")),
                "hv_ch1_start": format_hv(entry.get("hv_ch1_start")),  # type: ignore[arg-type]
                "hv_ch1_end": format_hv(entry.get("hv_ch1_end")),      # type: ignore[arg-type]
                "hv_ch2_start": format_hv(entry.get("hv_ch2_start")),  # type: ignore[arg-type]
                "hv_ch2_end": format_hv(entry.get("hv_ch2_end")),      # type: ignore[arg-type]
                "comment": (entry.get("comment") or "").strip(),       # type: ignore[arg-type]
            }
        )

    next_run_id = len(output_rows) + 1
    for entry in computed_runs:
        start_dt = entry.get("start")
        end_dt = entry.get("end")
        if not isinstance(start_dt, datetime):
            continue
        row = {
            "run": str(next_run_id),
            "start": start_dt.strftime(TIMESTAMP_FMT),
            "end": end_dt.strftime(TIMESTAMP_FMT) if isinstance(end_dt, datetime) else "",
            "hv_ch1_start": format_hv(entry.get("hv_ch1_start")),
            "hv_ch1_end": format_hv(entry.get("hv_ch1_end")),
            "hv_ch2_start": format_hv(entry.get("hv_ch2_start")),
            "hv_ch2_end": format_hv(entry.get("hv_ch2_end")),
            "comment": (entry.get("comment") or "").strip(),
        }
        output_rows.append(row)
        next_run_id += 1

    write_runs(output_rows, args.output)
    log(f"[INFO] Wrote {len(output_rows)} run entries to {args.output}", args.quiet)


if __name__ == "__main__":
    main()
