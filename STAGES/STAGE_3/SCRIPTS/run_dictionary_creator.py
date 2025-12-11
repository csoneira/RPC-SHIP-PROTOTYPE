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
DEFAULT_OBS_INDEX = 18  # fallback column containing operator comments inside the online logbook

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
    daq_details: list[str]


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


def coerce_number(value: float | int | str | None) -> float | None:
    """
    Convert assorted numeric-like values into floats; return None when unparsable.
    """
    if value is None:
        return None
    if isinstance(value, (float, int)):
        return float(value)
    return parse_number(value)


def clean_cell(row: list[str], index: int) -> str:
    if index >= len(row):
        return ""
    return row[index].strip()


def extract_file_hint(row: list[str]) -> str:
    """
    Retrieve any file hint present in the DAQ row. Columns may shift between File/StartFile/StopFile,
    so pick the first non-empty entry among them.
    """
    for idx in (6, 7, 8):
        hint = clean_cell(row, idx)
        if hint:
            return hint
    return ""


def detect_observation_index(rows: list[list[str]], fallback: int = DEFAULT_OBS_INDEX) -> int:
    """
    Locate the column index labelled 'Observations' (case-insensitive) near the top of the file.
    """
    scan_window = rows[:30] if len(rows) > 30 else rows
    for row in scan_window:
        for idx, cell in enumerate(row):
            if cell.strip().lower() == "observations":
                return idx
    return fallback


def collect_daq_details(row: list[str], obs_index: int) -> list[str]:
    """
    Pull human-meaningful details from DAQ rows (e.g. repurposed DOY/Run# fields).
    Numeric-only values are ignored to avoid cluttering the comments.
    """
    details: list[str] = []
    for idx in range(4, min(len(row), obs_index)):
        if idx in {6, 7, 8}:  # file-related fields handled separately
            continue
        value = clean_cell(row, idx)
        if not value:
            continue
        normalized = value.replace(",", "").replace(".", "").strip()
        if normalized.isdigit():
            continue
        details.append(value)
    return details


def build_comment(
    pending: PendingRun, observation: str, file_hint: str, extra_details: Iterable[str] = ()
) -> str:
    candidates: list[str] = []
    has_descriptive_text = False
    for value in (pending.comment, observation):
        value = (value or "").strip()
        if value:
            has_descriptive_text = True
            candidates.append(value)
    for value in (pending.file_hint, file_hint):
        value = (value or "").strip()
        if value:
            candidates.append(value)
    for detail in extra_details:
        clean_detail = detail.strip()
        if clean_detail:
            has_descriptive_text = True
            candidates.append(clean_detail)
    for note in pending.notes:
        clean = note.strip()
        if clean:
            has_descriptive_text = True
            candidates.append(clean)
    merged: list[str] = []
    for entry in candidates:
        if entry not in merged:
            merged.append(entry)
    fallback = f"DAQ run starting {pending.start.strftime(TIMESTAMP_FMT)}"
    if merged:
        if not has_descriptive_text:
            merged.append(fallback)
        return " | ".join(merged)
    return fallback


def extract_runs_from_logbook(path: Path) -> list[dict[str, datetime | str | None]]:
    runs: list[dict[str, datetime | str | None]] = []
    pending: PendingRun | None = None
    current_hv_ch1: Optional[float] = None
    current_hv_ch2: Optional[float] = None
    notes_for_next_run: list[str] = []
    after_stop = False

    with path.open(newline="", encoding="utf-8") as handle:
        rows = [[cell.strip() for cell in row] for row in csv.reader(handle)]

    obs_index = detect_observation_index(rows)

    for row in rows:
        if len(row) < 3:
            continue
        observation = clean_cell(row, obs_index) if len(row) > obs_index else ""
        file_hint = extract_file_hint(row)

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
            if observation:
                if pending:
                    pending.notes.append(observation)
                elif after_stop:
                    notes_for_next_run.append(observation)
            continue

        action = clean_cell(row, 3).upper()
        timestamp = normalize_timestamp(row[1])
        daq_details = collect_daq_details(row, obs_index)
        if action not in {"START", "STOP"} or timestamp is None:
            continue

        if action == "START":
            if pending is not None:
                runs.append(
                    {
                        "start": pending.start,
                        "end": timestamp,
                        "comment": build_comment(pending, "", "", pending.daq_details),
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
                notes=list(notes_for_next_run),
                hv_start_ch1=current_hv_ch1,
                hv_start_ch2=current_hv_ch2,
                hv_last_ch1=current_hv_ch1,
                hv_last_ch2=current_hv_ch2,
                daq_details=daq_details,
            )
            notes_for_next_run.clear()
            after_stop = False
        elif action == "STOP" and pending:
            combined_details = [*pending.daq_details, *daq_details]
            comment = build_comment(pending, observation, file_hint, combined_details)
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
            notes_for_next_run.clear()
            after_stop = True
        elif action == "STOP":
            notes_for_next_run.clear()
            after_stop = True

    if pending:
        hv_end_ch1 = pending.hv_last_ch1 if pending.hv_last_ch1 is not None else pending.hv_start_ch1
        hv_end_ch2 = pending.hv_last_ch2 if pending.hv_last_ch2 is not None else pending.hv_start_ch2
        runs.append(
            {
                "start": pending.start,
                "end": None,
                "comment": build_comment(pending, "", "", pending.daq_details),
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


def collapse_hv_pair(
    start_raw: float | int | str | None, end_raw: float | int | str | None
) -> tuple[str, str]:
    """
    Render HV start/end fields while avoiding duplicated values.
    """
    start = coerce_number(start_raw)
    end = coerce_number(end_raw)
    if start is not None and end is not None and abs(start - end) < 1e-6:
        return format_hv(start), ""
    if start is None and end is not None:
        return "", format_hv(end)
    return format_hv(start), format_hv(end)


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
        hv1_start, hv1_end = collapse_hv_pair(entry.get("hv_ch1_start"), entry.get("hv_ch1_end"))
        hv2_start, hv2_end = collapse_hv_pair(entry.get("hv_ch2_start"), entry.get("hv_ch2_end"))
        output_rows.append(
            {
                "run": str(entry.get("run", "")),
                "start": str(entry.get("start", "")),
                "end": str(entry.get("end", "")),
                "hv_ch1_start": hv1_start,
                "hv_ch1_end": hv1_end,
                "hv_ch2_start": hv2_start,
                "hv_ch2_end": hv2_end,
                "comment": (entry.get("comment") or "").strip(),       # type: ignore[arg-type]
            }
        )

    next_run_id = len(output_rows) + 1
    for entry in computed_runs:
        start_dt = entry.get("start")
        end_dt = entry.get("end")
        if not isinstance(start_dt, datetime):
            continue
        hv1_start, hv1_end = collapse_hv_pair(entry.get("hv_ch1_start"), entry.get("hv_ch1_end"))
        hv2_start, hv2_end = collapse_hv_pair(entry.get("hv_ch2_start"), entry.get("hv_ch2_end"))
        row = {
            "run": str(next_run_id),
            "start": start_dt.strftime(TIMESTAMP_FMT),
            "end": end_dt.strftime(TIMESTAMP_FMT) if isinstance(end_dt, datetime) else "",
            "hv_ch1_start": hv1_start,
            "hv_ch1_end": hv1_end,
            "hv_ch2_start": hv2_start,
            "hv_ch2_end": hv2_end,
            "comment": (entry.get("comment") or "").strip(),
        }
        output_rows.append(row)
        next_run_id += 1

    write_runs(output_rows, args.output)
    log(f"[INFO] Wrote {len(output_rows)} run entries to {args.output}", args.quiet)


if __name__ == "__main__":
    main()
