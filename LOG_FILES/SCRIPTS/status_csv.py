#!/usr/bin/env python3
"""Utility helpers to track script execution status in CSV files.

This script provides both reusable functions and a small CLI so shell
scripts can mark when a task started and when it finished.
"""

from __future__ import annotations

import csv
import sys
from datetime import datetime
from pathlib import Path
from typing import Iterable, List

DEFAULT_HEADER: List[str] = ["timestamp", "status", "message"]


def _ensure_header(path: Path, header: Iterable[str]) -> None:
    """Make sure the CSV file exists with the expected header."""
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(list(header))


def append_status_row(csv_path: str | Path, message: str = "") -> str:
    """Append a new "running" status entry and return the timestamp used."""
    path = Path(csv_path)
    _ensure_header(path, DEFAULT_HEADER)
    timestamp = datetime.now().isoformat(timespec="seconds")
    with path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([timestamp, "running", message])
    return timestamp


def mark_status_complete(
    csv_path: str | Path,
    timestamp: str,
    status: str = "completed",
    message: str | None = None,
) -> bool:
    """Mark the row with ``timestamp`` as finished. Returns ``True`` on success."""
    path = Path(csv_path)
    if not path.exists():
        return False

    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames or DEFAULT_HEADER
        rows = list(reader)

    updated = False
    for row in rows:
        if row.get("timestamp") == timestamp and not updated:
            row["status"] = status
            if message is not None:
                row["message"] = message
            updated = True

    if not updated:
        return False

    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    return True


def _usage() -> str:
    return (
        "Usage: status_csv.py <append|complete> <csv_path> [timestamp] [status] [message]\n"
        "\n"
        "append:  creates/updates CSV and prints the timestamp used.\n"
        "          Optional message can be provided as a fourth argument.\n"
        "complete: marks an existing timestamp as completed. Provide timestamp,\n"
        "          optional status (default 'completed'), and optional message.\n"
    )


def _main(argv: list[str]) -> int:
    if len(argv) < 3:
        sys.stderr.write(_usage())
        return 1

    command = argv[1]
    csv_path = argv[2]

    if command == "append":
        message = argv[3] if len(argv) > 3 else ""
        timestamp = append_status_row(csv_path, message)
        print(timestamp)
        return 0

    if command == "complete":
        if len(argv) < 4:
            sys.stderr.write("complete requires a timestamp.\n")
            sys.stderr.write(_usage())
            return 1
        timestamp = argv[3]
        status = argv[4] if len(argv) > 4 else "completed"
        message = argv[5] if len(argv) > 5 else None
        success = mark_status_complete(csv_path, timestamp, status=status, message=message)
        if not success:
            sys.stderr.write(
                f"Warning: no matching timestamp '{timestamp}' found in {csv_path}.\n"
            )
            return 1
        return 0

    sys.stderr.write(f"Unknown command '{command}'.\n")
    sys.stderr.write(_usage())
    return 1


if __name__ == "__main__":  # pragma: no cover - small CLI wrapper only
    sys.exit(_main(sys.argv))
