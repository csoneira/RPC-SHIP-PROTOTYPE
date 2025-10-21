from __future__ import annotations

import argparse
from pathlib import Path
from itertools import cycle
from dataclasses import dataclass

import matplotlib.pyplot as plt
from matplotlib.axes import Axes
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
from matplotlib import colors as mcolors

LOG_PATH = Path("LOG_FILES/DATA/big_log_lab_data.csv")
RUN_DICT_PATH = Path("file_run_dictionary.csv")
OUTLIER_ABS_LIMIT = 2000  # values above this (in absolute terms) are considered spurious


@dataclass(frozen=True)
class RunSegment:
    run: int
    start: pd.Timestamp
    end: pd.Timestamp
    color: tuple[float, float, float]
    display_start: pd.Timestamp
    display_end: pd.Timestamp


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Plot time series from lab logs.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-r",
        "--run",
        type=int,
        help="Run number defined in file_run_dictionary.csv. "
        "When provided, data are clipped to the run window and charts are saved to a PDF.",
    )
    group.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="Plot and export all runs defined in file_run_dictionary.csv.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Optional PDF output path. Used when --run/-r or --all/-a is supplied.",
    )
    return parser.parse_args()


def load_data() -> pd.DataFrame:
    data = pd.read_csv(LOG_PATH, parse_dates=["Time"])
    data.dropna(how="all", inplace=True)
    numeric_cols = data.select_dtypes(include=["number"]).columns
    if len(numeric_cols) > 0:
        numeric = data[numeric_cols]
        cleaned = numeric.mask(~np.isfinite(numeric))
        cleaned = cleaned.mask(cleaned.abs() > OUTLIER_ABS_LIMIT)
        data[numeric_cols] = cleaned
    return data.sort_values("Time")


def load_run_window(run_number: int) -> tuple[pd.Timestamp, pd.Timestamp | None]:
    runs = pd.read_csv(RUN_DICT_PATH, parse_dates=["start", "end"])
    if "run" not in runs.columns:
        raise ValueError(f"Column 'run' not found in {RUN_DICT_PATH}.")

    match = runs.loc[runs["run"] == run_number]
    if match.empty:
        raise ValueError(f"Run {run_number} not found in {RUN_DICT_PATH}.")

    start = match.iloc[0]["start"]
    end = match.iloc[0]["end"]
    if pd.isna(start):
        raise ValueError(f"Run {run_number} is missing a start timestamp.")

    return start, None if pd.isna(end) else end


def load_all_runs() -> pd.DataFrame:
    runs = pd.read_csv(RUN_DICT_PATH, parse_dates=["start", "end"])
    if "run" not in runs.columns:
        raise ValueError(f"Column 'run' not found in {RUN_DICT_PATH}.")
    filtered = runs.dropna(subset=["run", "start"]).copy()
    if filtered.empty:
        raise ValueError(f"No runs with a defined start found in {RUN_DICT_PATH}.")
    filtered["run"] = filtered["run"].astype(int)
    return filtered.sort_values("start")


def filter_for_run(
    data: pd.DataFrame, run_number: int
) -> tuple[pd.DataFrame, pd.Timestamp, pd.Timestamp]:
    start, end = load_run_window(run_number)
    if end is None:
        end = data["Time"].max()
    filtered = data[(data["Time"] >= start) & (data["Time"] <= end)]
    if filtered.empty:
        raise ValueError(
            f"No log records found between {start} and {end} for run {run_number}."
        )
    return filtered, start, end


def _compute_midnight_boundaries(times: pd.Series) -> pd.DatetimeIndex:
    if times.empty:
        return pd.DatetimeIndex([])
    start = times.min().normalize()
    end = (times.max() + pd.Timedelta(days=1)).normalize()
    boundaries = pd.date_range(start=start, end=end, freq="D")
    return boundaries[(boundaries >= times.min()) & (boundaries <= times.max())]


def _background_rgba(
    color: str | tuple[float, float, float], alpha: float = 0.5
) -> tuple[float, float, float, float]:
    return mcolors.to_rgba(color, alpha=alpha)


def _apply_background(fig: plt.Figure, color: tuple[float, float, float, float]) -> None:
    for axis in fig.get_axes():
        axis.set_facecolor(color)
    fig.patch.set_facecolor("white")


def create_figures(
    data: pd.DataFrame,
    title_suffix: str | None = None,
    background_color: str | tuple[float, float, float] | None = None,
    run_segments: list[RunSegment] | None = None,
    ellipsis_positions: list[pd.Timestamp] | None = None,
    time_column: str = "Time",
) -> list[plt.Figure]:
    figures: list[plt.Figure] = []
    suffix = f" — {title_suffix}" if title_suffix else ""
    day_boundaries = _compute_midnight_boundaries(data[time_column])
    background_rgba = (
        _background_rgba(background_color) if background_color is not None else None
    )
    run_segment_rgba = []
    if run_segments:
        for segment in run_segments:
            run_segment_rgba.append(
                (segment, _background_rgba(segment.color, alpha=0.3))
            )
    ellipsis_positions = ellipsis_positions or []
    xlabel = "Time (compressed)" if ellipsis_positions else "Time"

    def add_midnight_lines(axis: Axes) -> None:
        for boundary in day_boundaries:
            axis.axvline(boundary, color="0.6", linestyle="--", linewidth=0.8)

    def add_run_spans(axis: Axes) -> None:
        for segment, rgba in run_segment_rgba:
            axis.axvspan(
                segment.display_start,
                segment.display_end,
                color=rgba,
                zorder=0,
            )
        for position in ellipsis_positions:
            axis.axvline(
                position,
                color="0.35",
                linestyle="-",
                linewidth=2.0,
                alpha=0.8,
            )
            axis.annotate(
                "⋯",
                xy=(position, 0),
                xycoords=("data", "axes fraction"),
                xytext=(0, -12),
                textcoords="offset points",
                ha="center",
                va="top",
                fontsize=12,
                color="0.35",
                clip_on=False,
            )

    # HVs and Currents in stacked subplots
    fig, (ax_hv, ax_curr) = plt.subplots(
        2, 1, figsize=(10, 8), sharex=True, gridspec_kw={"hspace": 0.1}
    )
    currents = ["hv4_CurrentNeg", "hv4_CurrentPos", "hv5_CurrentNeg", "hv5_CurrentPos"]
    hvs = ["hv4_HVneg", "hv4_HVpos", "hv5_HVneg", "hv5_HVpos"]
    add_run_spans(ax_hv)
    add_run_spans(ax_curr)
    for col in currents:
        if col in data:
            ax_curr.plot(data[time_column], data[col], label=col)
    for col in hvs:
        if col in data:
            ax_hv.plot(data[time_column], data[col], label=col)

    ax_hv.set_ylabel("HVs")
    ax_hv.set_ylim(0, 10)
    ax_hv.legend(loc="upper left")
    ax_curr.set_ylabel("Currents")
    ax_curr.set_xlabel(xlabel)
    ax_curr.legend(loc="upper left")
    add_midnight_lines(ax_hv)
    add_midnight_lines(ax_curr)
    fig.suptitle(f"Currents and HVs{suffix}")
    figures.append(fig)

    # Rates (Asserted, Edge, Accepted)
    fig, ax = plt.subplots(figsize=(10, 6))
    rates = ["rates_Asserted", "rates_Edge", "rates_Accepted"]
    add_run_spans(ax)
    for col in rates:
        if col in data:
            ax.plot(data[time_column], data[col], label=col)
    ax.set_ylabel("Rates")
    ax.set_xlabel(xlabel)
    ax.legend()
    add_midnight_lines(ax)
    fig.suptitle(f"Rates (Asserted, Edge, Accepted){suffix}")
    figures.append(fig)

    # Rates Multiplexer and CM separated
    fig, (ax_mux, ax_cm) = plt.subplots(
        2, 1, figsize=(10, 8), sharex=True, gridspec_kw={"hspace": 0.1}
    )
    multiplexer = [f"rates_Multiplexer{i}" for i in range(1, 13)]
    cm = [f"rates_CM{i}" for i in range(1, 13)]
    add_run_spans(ax_mux)
    add_run_spans(ax_cm)
    for col in multiplexer:
        if col in data:
            ax_mux.plot(data[time_column], data[col], label=col)
    for col in cm:
        if col in data:
            ax_cm.plot(data[time_column], data[col], label=col)
    ax_mux.set_ylabel("Rates Multiplexer")
    ax_cm.set_ylabel("Rates CM")
    ax_cm.set_xlabel(xlabel)
    ax_mux.legend(loc="upper right", ncol=2)
    ax_cm.legend(loc="upper right", ncol=2)
    add_midnight_lines(ax_mux)
    add_midnight_lines(ax_cm)
    fig.suptitle(f"Rates Multiplexer and CM{suffix}")
    figures.append(fig)

    # Sensors
    fig, axes = plt.subplots(3, 1, figsize=(10, 12), sharex=True)
    sensors = [
        "sensors_Temperature_ext",
        "sensors_RH_ext",
        "sensors_Pressure_ext",
    ]
    sensor_limits = {
        "sensors_Temperature_ext": (20, 28),
        "sensors_RH_ext": (35, 65),
        "sensors_Pressure_ext": (980, 1020),
    }
    for axis, col in zip(axes, sensors):
        add_run_spans(axis)
        if col in data:
            axis.plot(data[time_column], data[col], label=col)
            axis.set_ylabel(col)
            axis.legend()
            limits = sensor_limits.get(col)
            if limits:
                axis.set_ylim(*limits)
        add_midnight_lines(axis)
    axes[-1].set_xlabel(xlabel)
    fig.suptitle(f"Sensors{suffix}")
    figures.append(fig)

    if background_rgba is not None:
        for fig in figures:
            _apply_background(fig, background_rgba)

    return figures


def save_figures_to_pdf(figures: list[plt.Figure], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with PdfPages(output_path) as pdf:
        for fig in figures:
            pdf.savefig(fig)
            plt.close(fig)
    print(f"Saved plots to {output_path}")


def main() -> None:
    args = parse_args()
    data = load_data()

    if args.all:
        run_rows = load_all_runs()
        data_segments: list[pd.DataFrame] = []
        run_segments: list[RunSegment] = []
        ellipsis_positions: list[pd.Timestamp] = []
        color_cycle = cycle(plt.cm.get_cmap("tab20").colors)
        cumulative_gap = pd.Timedelta(0)
        previous_end: pd.Timestamp | None = None
        for _, row in run_rows.iterrows():
            run_number = int(row["run"])
            try:
                run_data, start, end = filter_for_run(data, run_number)
            except ValueError as exc:
                print(f"Skipping run {run_number}: {exc}")
                continue
            start_str = start.strftime("%Y-%m-%d %H:%M:%S")
            end_str = end.strftime("%Y-%m-%d %H:%M:%S")
            print(f"Plotting run {run_number} window: {start_str} -> {end_str}")
            color = next(color_cycle)
            rgb = color[:3] if len(color) == 4 else color
            if previous_end is not None:
                gap = start - previous_end
                if gap > pd.Timedelta(0):
                    cumulative_gap += gap
            adjusted = run_data.copy()
            adjusted["TimeDisplay"] = adjusted["Time"] - cumulative_gap
            display_start = start - cumulative_gap
            display_end = end - cumulative_gap
            if previous_end is not None and start > previous_end:
                ellipsis_positions.append(display_start)
            run_segments.append(
                RunSegment(
                    run=run_number,
                    start=start,
                    end=end,
                    color=rgb,
                    display_start=display_start,
                    display_end=display_end,
                )
            )
            data_segments.append(adjusted)
            previous_end = end
        if not data_segments:
            raise ValueError("No plots created for any runs.")
        combined = (
            pd.concat(data_segments, axis=0, ignore_index=True)
            .sort_values("TimeDisplay")
            .reset_index(drop=True)
        )
        title_runs = ", ".join(str(segment.run) for segment in run_segments)
        figures = create_figures(
            combined,
            title_suffix=f"Runs {title_runs}",
            run_segments=run_segments,
            ellipsis_positions=ellipsis_positions,
            time_column="TimeDisplay",
        )
        output_path = (
            args.output if args.output else Path("time_series_all_runs.pdf")
        )
        save_figures_to_pdf(figures, output_path)
        return

    if args.run is not None:
        data, start, end = filter_for_run(data, args.run)
        end_str = end.strftime("%Y-%m-%d %H:%M:%S")
        start_str = start.strftime("%Y-%m-%d %H:%M:%S")
        print(f"Plotting run {args.run} window: {start_str} -> {end_str}")
        output_path = (
            args.output
            if args.output
            else Path(f"time_series_run_{args.run}.pdf")
        )
        figures = create_figures(
            data, title_suffix=f"Run {args.run} ({start_str} -> {end_str})"
        )
        save_figures_to_pdf(figures, output_path)
    else:
        # Maintain previous behaviour: show figures interactively.
        figures = create_figures(data)
        plt.show(block=False)
        # Leave figures open for interactive inspection.
        plt.show()


if __name__ == "__main__":
    main()
