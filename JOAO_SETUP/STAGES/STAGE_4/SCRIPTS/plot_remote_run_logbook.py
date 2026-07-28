from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
import math


SCRIPT_DIR = Path(__file__).resolve().parent
STAGE4_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_LOGBOOK = STAGE4_ROOT / "DATA" / "DATA_LOGS" / "remote_run_logbook.csv"
DEFAULT_OUTPUT = STAGE4_ROOT / "DATA" / "DATA_LOGS" / "remote_run_logbook_plot.png"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot timestamp vs. run_id from the remote run logbook."
    )
    parser.add_argument(
        "--logbook",
        type=Path,
        default=DEFAULT_LOGBOOK,
        help=f"Path to remote run logbook CSV (default: {DEFAULT_LOGBOOK})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Destination image path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Silence informational logs.",
    )
    return parser.parse_args()


def load_logbook(path: Path) -> tuple[list[tuple[datetime | None, float]], int]:
    if not path.exists():
        raise FileNotFoundError(f"Logbook not found: {path}")
    entries: list[tuple[datetime | None, float]] = []
    missing_timestamps = 0
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            filename = (row.get("filename") or "").strip()
            if not filename:
                continue
            ts_raw = (row.get("timestamp_utc") or "").strip()
            run_raw = (row.get("run_id") or "").strip()

            timestamp: datetime | None = None
            if ts_raw:
                try:
                    timestamp = datetime.strptime(ts_raw, "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    missing_timestamps += 1
            else:
                missing_timestamps += 1

            run_value = 0.0
            if run_raw:
                try:
                    run_value = float(run_raw)
                except ValueError:
                    run_value = 0.0

            entries.append((timestamp, run_value))
    return entries, missing_timestamps


def plot_entries(entries: list[tuple[datetime | None, float]], destination: Path) -> None:
    points = [(ts, run) for ts, run in entries if ts is not None]

    fig, ax = plt.subplots(figsize=(10, 5))
    if points:
        xs, ys = zip(*points)
        ax.scatter(xs, ys, s=18, color="tab:blue", edgecolor="black", linewidths=0.4, alpha=0.75)
        run_min = math.floor(min(ys))
        run_max = math.ceil(max(ys))
        tick_min = min(0, run_min)
        tick_max = max(0, run_max)
        ax.set_ylim(bottom=tick_min - 0.5, top=tick_max + 0.5)
        ax.set_yticks(list(range(tick_min, tick_max + 1)))
    else:
        ax.text(
            0.5,
            0.5,
            "No timestamped entries to plot.",
            ha="center",
            va="center",
            transform=ax.transAxes,
        )
        ax.set_ylim(bottom=-0.5, top=0.5)
        ax.set_yticks([0])

    ax.set_xlabel("timestamp_utc")
    ax.set_ylabel("run_id (0 when missing)")
    ax.grid(True, linestyle="--", alpha=0.4)
    fig.autofmt_xdate()
    fig.tight_layout()

    destination.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(destination, dpi=150, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    args = parse_args()
    entries, missing_ts = load_logbook(args.logbook)
    plot_entries(entries, args.output)
    if not args.quiet:
        total = len(entries)
        print(f"[INFO] Loaded {total} entr{'y' if total == 1 else 'ies'} from {args.logbook}")
        if missing_ts:
            print(f"[WARN] {missing_ts} entr{'y has' if missing_ts == 1 else 'ies have'} no timestamp_utc value; those were skipped in the plot.")
        print(f"[INFO] Saved comprobation plot to {args.output}")


if __name__ == "__main__":
    main()
