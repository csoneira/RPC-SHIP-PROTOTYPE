#!/usr/bin/env python3
"""Plot the two q_sum efficiencies and streamer fraction against measured HV.

The scan configuration is a CSV with a required ``run_name`` column.  Each row
is one point in the plot. An optional ``label`` column replaces the displayed
run name; the point's horizontal position is its measured mean absolute HV.

By default the script reads TOMAR/CONFIGS/result_scan_runs.csv and writes:
  TOMAR/OUTPUTS_SCAN/result_scan.png
  TOMAR/OUTPUTS_SCAN/result_scan_summary.csv
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/result_scan_matplotlib")

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap
from scipy.io import loadmat


TOMAR_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = TOMAR_ROOT / "CONFIGS" / "result_scan_runs.csv"
DEFAULT_PLOT_LIMITS = TOMAR_ROOT / "CONFIGS" / "result_scan_plot_limits.csv"
DEFAULT_OUTPUT_DIR = TOMAR_ROOT / "OUTPUTS_SCAN"
OUTPUTS_DIR = TOMAR_ROOT / "OUTPUTS"
RUNS_CONFIG = TOMAR_ROOT / "CONFIGS" / "runs.csv"
LOGS_DIR = TOMAR_ROOT / "LOGS"
MAT_NAME_PATTERN = re.compile(r"^dabc(?P<year>\d{2})(?P<day_of_year>\d{3})(?P<time>\d{6})\.mat$")


@dataclass(frozen=True)
class ScanPoint:
    run_name: str
    label: str
    output_dir: Path
    efficiency_percent: float
    efficiency_uncertainty_percent: float
    scintillator_efficiency_percent: float
    scintillator_efficiency_uncertainty_percent: float
    streamer_percent: float
    acquisition_time: datetime
    acquisition_end_time: datetime | None
    event_time_source: str
    hv_log_time: datetime
    hv_negative_kv: float
    hv_positive_kv: float
    hv_mean_abs_kv: float


def read_scan_config(path: Path) -> list[tuple[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(line for line in handle if not line.lstrip().startswith("#"))
        if not reader.fieldnames or "run_name" not in reader.fieldnames:
            raise ValueError(f"{path} must contain a 'run_name' CSV column.")
        runs = []
        for row_number, row in enumerate(reader, start=2):
            run_name = (row.get("run_name") or "").strip()
            if not run_name:
                raise ValueError(f"{path}:{row_number} has an empty run_name.")
            label = (row.get("label") or run_name).strip()
            runs.append((run_name, label))
    if not runs:
        raise ValueError(f"{path} contains no scan runs.")
    return runs


def read_plot_limits(path: Path) -> tuple[float, float]:
    """Read the adjustable charge interval for the TOMAR spectrum overlay."""
    with path.open(newline="", encoding="utf-8") as handle:
        rows = csv.DictReader(line for line in handle if not line.lstrip().startswith("#"))
        values = {row.get("parameter", "").strip(): row.get("value", "").strip() for row in rows}
    try:
        lower = float(values["charge_overlay_min"])
        upper = float(values["charge_overlay_max"])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f"{path} needs numeric charge_overlay_min and charge_overlay_max values.") from error
    if not math.isfinite(lower) or not math.isfinite(upper) or lower >= upper:
        raise ValueError(f"{path} requires charge_overlay_min < charge_overlay_max.")
    return lower, upper


def output_directory_for_run(run_name: str) -> Path:
    matches = sorted(path for path in OUTPUTS_DIR.glob(f"*_{run_name}") if path.is_dir())
    if len(matches) != 1:
        description = "none" if not matches else ", ".join(str(path) for path in matches)
        raise FileNotFoundError(f"Expected one output directory for run '{run_name}', found: {description}")
    return matches[0]


def run_file_names() -> tuple[dict[str, str], dict[int, str]]:
    with RUNS_CONFIG.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        by_name: dict[str, str] = {}
        by_order: dict[int, str] = {}
        for order, row in enumerate(reader, start=1):
            if not row.get("run_name") or not row.get("file_name"):
                continue
            by_name[row["run_name"].strip()] = row["file_name"].strip()
            by_order[order] = row["file_name"].strip()
    return by_name, by_order


def acquisition_time_from_file_name(file_name: str) -> datetime:
    match = MAT_NAME_PATTERN.fullmatch(file_name)
    if not match:
        raise ValueError(f"Cannot infer acquisition time from MAT filename '{file_name}'.")
    return datetime.strptime(
        f"20{match['year']} {match['day_of_year']} {match['time']}", "%Y %j %H%M%S"
    )


def nearest_hv(acquisition_time: datetime) -> tuple[datetime, float, float, float]:
    samples: list[tuple[datetime, float, float]] = []
    for log_file in LOGS_DIR.rglob("hv0_*.log"):
        with log_file.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                fields = line.split()
                if len(fields) < 11:
                    continue
                try:
                    timestamp = datetime.fromisoformat(fields[0])
                    # hv0 has six status words after timestamp, then I-, I+, HV-, HV+.
                    hv_negative = float(fields[9])
                    hv_positive = float(fields[10])
                except ValueError:
                    continue
                samples.append((timestamp, hv_negative, hv_positive))
    if not samples:
        raise FileNotFoundError(f"No hv0_*.log files found below {LOGS_DIR}. Run bring_logs.sh first.")
    timestamp, negative, positive = min(samples, key=lambda sample: abs(sample[0] - acquisition_time))
    if abs(timestamp - acquisition_time).total_seconds() > 12 * 3600:
        raise ValueError(f"Nearest HV sample ({timestamp.isoformat(sep=' ')}) is more than 12 hours from acquisition {acquisition_time.isoformat(sep=' ')}.")
    return timestamp, negative, positive, (abs(negative) + abs(positive)) / 2


def matlab_datenum_to_datetime(value: float) -> datetime:
    return datetime.fromordinal(int(value)) - timedelta(days=366) + timedelta(days=value % 1)


def event_window(output_dir: Path, run_name: str, file_name: str) -> tuple[datetime, datetime | None, str]:
    """Return exact event bounds from the analysis sidecar, when available."""
    start_from_name = acquisition_time_from_file_name(file_name)
    sidecar = output_dir / f"{run_name}_event_time_window.csv"
    if sidecar.is_file():
        with sidecar.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        if len(rows) == 1 and (rows[0].get("event_time_available") or "").strip().lower() == "true":
            try:
                first = matlab_datenum_to_datetime(float(rows[0]["first_event_datenum"]))
                last = matlab_datenum_to_datetime(float(rows[0]["last_event_datenum"]))
            except (KeyError, TypeError, ValueError):
                pass
            else:
                return first, last, "EBtime sidecar"
    data_file = TOMAR_ROOT / "DATA" / file_name
    if not data_file.is_file():
        raise FileNotFoundError(f"MAT file not found: {data_file}")
    data = loadmat(data_file, variable_names=["EBtime"], squeeze_me=True)
    ebtime = np.asarray(data.get("EBtime", [])).reshape(-1)
    finite = ebtime[np.isfinite(ebtime)]
    if finite.size == 0:
        return start_from_name, None, "MAT filename start (no EBtime)"
    return matlab_datenum_to_datetime(float(finite.min())), matlab_datenum_to_datetime(float(finite.max())), "EBtime MAT fallback"


def read_hv_log_samples() -> list[tuple[datetime, float, float, float, float]]:
    samples: list[tuple[datetime, float, float, float, float]] = []
    for log_file in LOGS_DIR.rglob("hv0_*.log"):
        with log_file.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                fields = line.split()
                if len(fields) < 11:
                    continue
                try:
                    samples.append((datetime.fromisoformat(fields[0]), float(fields[7]), float(fields[8]), float(fields[9]), float(fields[10])))
                except ValueError:
                    continue
    return sorted(samples, key=lambda sample: sample[0])


def read_environment_samples() -> list[tuple[datetime, float, float, float]]:
    """Read optional sensor logs as timestamp, temperature [C], RH [%], pressure [mbar]."""
    samples: list[tuple[datetime, float, float, float]] = []
    for log_file in LOGS_DIR.rglob("sensors_bus0_*.log"):
        with log_file.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                fields = line.replace(";", " ").split()
                if len(fields) < 6:
                    continue
                try:
                    values = [float(value) for value in fields[1:]]
                    samples.append((datetime.fromisoformat(fields[0]), values[-3], values[-2], values[-1]))
                except ValueError:
                    continue
    return sorted(samples, key=lambda sample: sample[0])


def read_efficiencies(path: Path) -> tuple[float, float, float, float]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise ValueError(f"Expected exactly one data row in {path}.")
    row = rows[0]
    try:
        efficiency = float(row["efficiency_percent"])
        efficiency_error = float(row["efficiency_uncertainty_percent"])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f"Could not read all-events efficiency columns from {path}: {error}") from error
    try:
        scintillator_efficiency = float(row["scintillator_conditioned_efficiency_percent"])
        scintillator_efficiency_error = float(row["scintillator_conditioned_efficiency_uncertainty_percent"])
    except (KeyError, TypeError, ValueError):
        # Older analyses did not write the scintillator-conditioned metric.
        # Keep their all-events point and make the missing series explicit.
        print(f"warning: scintillator-conditioned efficiency is absent in {path}; plotting it as missing.", file=sys.stderr)
        scintillator_efficiency = math.nan
        scintillator_efficiency_error = math.nan
    return efficiency, efficiency_error, scintillator_efficiency, scintillator_efficiency_error


def read_streamer_percent(path: Path) -> float:
    try:
        data = loadmat(path, variable_names=["streamer_fraction"], squeeze_me=True)
        return 100.0 * float(data["streamer_fraction"])
    except KeyError:
        print(f"warning: streamer_fraction is absent in {path}; plotting it as missing.", file=sys.stderr)
        return math.nan
    except (OSError, ValueError, NotImplementedError) as error:
        raise ValueError(f"Could not read streamer_fraction from {path}: {error}") from error


def load_point(run_name: str, label: str, file_names: dict[str, str], file_names_by_order: dict[int, str]) -> ScanPoint:
    output_dir = output_directory_for_run(run_name)
    efficiency_file = output_dir / f"{run_name}_q_sum_efficiency.csv"
    results_file = output_dir / f"{run_name}_fast_6x6_results.mat"
    if not efficiency_file.is_file():
        raise FileNotFoundError(f"Efficiency file not found: {efficiency_file}")
    if not results_file.is_file():
        raise FileNotFoundError(f"Results file not found: {results_file}")
    file_name = file_names.get(run_name)
    if file_name is None:
        # The output directory encodes the run order that was used at analysis
        # time. This preserves the association if runs.csv has since been renamed.
        try:
            output_order = int(output_dir.name.split("_", maxsplit=1)[0])
            file_name = file_names_by_order[output_order]
        except (KeyError, ValueError) as error:
            raise ValueError(f"Run '{run_name}' is absent from {RUNS_CONFIG} and cannot be resolved by output order.") from error
        print(f"warning: resolving '{run_name}' through output order {output_order} because its current runs.csv name differs.", file=sys.stderr)
    acquisition_time, acquisition_end_time, event_time_source = event_window(output_dir, run_name, file_name)
    hv_log_time, hv_negative, hv_positive, hv_mean_abs = nearest_hv(acquisition_time)
    efficiency, efficiency_error, scint_efficiency, scint_efficiency_error = read_efficiencies(efficiency_file)
    return ScanPoint(
        run_name, label, output_dir, efficiency, efficiency_error,
        scint_efficiency, scint_efficiency_error, read_streamer_percent(results_file),
        acquisition_time, acquisition_end_time, event_time_source,
        hv_log_time, hv_negative, hv_positive, hv_mean_abs,
    )


def write_summary(points: list[ScanPoint], path: Path) -> None:
    fields = [
        "scan_order", "run_name", "label", "source_output_dir", "efficiency_percent",
        "efficiency_uncertainty_percent", "scintillator_conditioned_efficiency_percent",
        "scintillator_conditioned_efficiency_uncertainty_percent", "streamer_percent",
        "acquisition_time", "acquisition_end_time", "event_time_source", "hv_log_time", "hv_negative_kv", "hv_positive_kv", "hv_mean_abs_kv",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for order, point in enumerate(points, start=1):
            writer.writerow({
                "scan_order": order, "run_name": point.run_name, "label": point.label,
                "source_output_dir": point.output_dir, "efficiency_percent": point.efficiency_percent,
                "efficiency_uncertainty_percent": point.efficiency_uncertainty_percent,
                "scintillator_conditioned_efficiency_percent": point.scintillator_efficiency_percent,
                "scintillator_conditioned_efficiency_uncertainty_percent": point.scintillator_efficiency_uncertainty_percent,
                "streamer_percent": point.streamer_percent,
                "acquisition_time": point.acquisition_time.isoformat(sep=" "),
                "acquisition_end_time": point.acquisition_end_time.isoformat(sep=" ") if point.acquisition_end_time else "",
                "event_time_source": point.event_time_source,
                "hv_log_time": point.hv_log_time.isoformat(sep=" "),
                "hv_negative_kv": point.hv_negative_kv, "hv_positive_kv": point.hv_positive_kv,
                "hv_mean_abs_kv": point.hv_mean_abs_kv,
            })


def plot_points(points: list[ScanPoint], path: Path) -> None:
    # Connect the curves in physical HV order, irrespective of configuration order.
    points = sorted(points, key=lambda point: point.hv_mean_abs_kv)
    x_values = [point.hv_mean_abs_kv for point in points]
    figure, efficiency_axis = plt.subplots(figsize=(8.5, 5.5), constrained_layout=True)
    streamer_axis = efficiency_axis.twinx()

    all_efficiency = efficiency_axis.errorbar(
        x_values, [point.efficiency_percent for point in points],
        yerr=[point.efficiency_uncertainty_percent for point in points],
        marker="o", linewidth=2, capsize=4, color="tab:blue", label="Efficiency (all events)",
    )
    scint_efficiency = efficiency_axis.errorbar(
        x_values, [point.scintillator_efficiency_percent for point in points],
        yerr=[point.scintillator_efficiency_uncertainty_percent for point in points],
        marker="s", linewidth=2, capsize=4, color="tab:green", label="Efficiency (scintillator selected)",
    )
    streamers = streamer_axis.plot(
        x_values, [point.streamer_percent for point in points], marker="^", linewidth=2,
        color="tab:red", label="Streamer fraction",
    )[0]

    efficiency_axis.set_xlabel("Mean absolute HV [kV]")
    efficiency_axis.set_ylabel("Efficiency [%]", color="tab:blue")
    streamer_axis.set_ylabel("Streamer fraction [%]", color="tab:red")
    x_min, x_max = min(x_values), max(x_values)
    x_padding = max(0.02, (x_max - x_min) * 0.08)
    efficiency_axis.set_xlim(x_min - x_padding, x_max + x_padding)
    efficiency_axis.set_ylim(top=100)
    efficiency_axis.grid(True, axis="both", alpha=0.3)
    efficiency_axis.set_title("Efficiency and streamer fraction versus HV")
    for point in points:
        efficiency_axis.annotate(
            point.label,
            (point.hv_mean_abs_kv, point.efficiency_percent),
            xytext=(0, 11), textcoords="offset points", ha="center", fontsize=9, color="tab:blue",
        )
    efficiency_axis.legend(
        [all_efficiency, scint_efficiency, streamers],
        ["Efficiency (all events)", "Efficiency (scintillator selected)", "Streamer fraction"],
        loc="best",
    )
    figure.savefig(path, dpi=180)
    plt.close(figure)


def plot_charge_heatmap(points: list[ScanPoint], path: Path) -> None:
    """Plot normalized q_sum charge spectra with runs as categorical X bins."""
    spectra: list[dict[float, float]] = []
    bin_centers: set[float] = set()
    for point in points:
        histogram_file = point.output_dir / f"{point.run_name}_q_sum_charge_histogram.csv"
        if not histogram_file.is_file():
            raise FileNotFoundError(f"Charge histogram not found: {histogram_file}. Re-run the TOMAR analysis for this run.")
        with histogram_file.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        try:
            spectrum = {float(row["Charge_bin_center"]): float(row["Count"]) for row in rows}
        except (KeyError, TypeError, ValueError) as error:
            raise ValueError(f"Could not read Charge_bin_center and Count from {histogram_file}: {error}") from error
        if not spectrum:
            raise ValueError(f"Charge histogram is empty: {histogram_file}")
        spectra.append(spectrum)
        bin_centers.update(spectrum)

    y_values = np.array(sorted(bin_centers), dtype=float)
    counts = np.array([[spectrum.get(center, 0.0) for spectrum in spectra] for center in y_values])
    totals = counts.sum(axis=0, keepdims=True)
    totals[totals == 0] = 1.0
    occupancy = counts / totals
    x_values = np.arange(1, len(points) + 1, dtype=float)
    y_edges = np.concatenate(([y_values[0] - (y_values[1] - y_values[0]) / 2], (y_values[:-1] + y_values[1:]) / 2, [y_values[-1] + (y_values[-1] - y_values[-2]) / 2]))
    x_edges = np.arange(0.5, len(points) + 1.5, 1.0)

    figure, axis = plt.subplots(figsize=(max(8, len(points) * 1.25), 6), constrained_layout=True)
    mesh = axis.pcolormesh(x_edges, y_edges, occupancy, shading="flat", cmap="viridis", rasterized=True)
    colorbar = figure.colorbar(mesh, ax=axis, pad=0.02)
    colorbar.set_label("Normalized bin occupancy")
    axis.set_xticks(x_values, [point.label for point in points], rotation=35, ha="right")
    axis.set_xlabel("Run")
    axis.set_ylabel("Total calibrated event charge q_sum [ns]")
    axis.set_title("TOMAR charge spectra across scan runs")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def green_viridis() -> LinearSegmentedColormap:
    """Viridis truncated before yellow, keeping the high end clearly green."""
    base = plt.get_cmap("viridis")
    return LinearSegmentedColormap.from_list("viridis_green_top", base(np.linspace(0, 0.70, 256)))


def read_charge_spectrum(point: ScanPoint) -> tuple[np.ndarray, np.ndarray]:
    histogram_file = point.output_dir / f"{point.run_name}_q_sum_charge_histogram.csv"
    if not histogram_file.is_file():
        raise FileNotFoundError(f"Charge histogram not found: {histogram_file}. Re-run the TOMAR analysis for this run.")
    with histogram_file.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    try:
        centers = np.array([float(row["Charge_bin_center"]) for row in rows])
        counts = np.array([float(row["Count"]) for row in rows])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f"Could not read Charge_bin_center and Count from {histogram_file}: {error}") from error
    valid = np.isfinite(centers) & np.isfinite(counts)
    return centers[valid], counts[valid]


def plot_charge_spectra_overlay(points: list[ScanPoint], path: Path, charge_limits: tuple[float, float]) -> None:
    """Overlay normalized TOMAR q_sum spectra, colouring each run by measured HV."""
    points = sorted(points, key=lambda point: point.hv_mean_abs_kv)
    hv_values = np.array([point.hv_mean_abs_kv for point in points])
    hv_min, hv_max = float(hv_values.min()), float(hv_values.max())
    if hv_min == hv_max:
        hv_min -= 0.01
        hv_max += 0.01
    colour_map = green_viridis()
    normalizer = plt.Normalize(hv_min, hv_max)
    figure, axis = plt.subplots(figsize=(10, 6), constrained_layout=True)
    charge_min, charge_max = charge_limits
    for point in points:
        centers, counts = read_charge_spectrum(point)
        selected = (centers >= charge_min) & (centers <= charge_max)
        centers, counts = centers[selected], counts[selected]
        total = counts.sum()
        if total <= 0:
            continue
        axis.step(
            centers, counts / total, where="mid", linewidth=1.8,
            color=colour_map(normalizer(point.hv_mean_abs_kv)),
            label=f"{point.label} ({point.hv_mean_abs_kv:.3g} kV)",
        )
    if not axis.lines:
        raise ValueError("No non-empty TOMAR charge histograms were available for the overlay.")
    axis.set_xlim(charge_min, charge_max)
    axis.set_xlabel("Total calibrated event charge q_sum [ns]")
    axis.set_ylabel("Normalized bin occupancy")
    axis.set_title("TOMAR scan spectra: normalized histograms overlaid by HV")
    axis.grid(True, alpha=0.3)
    axis.legend(loc="best", fontsize=8, ncol=2)
    scalar_map = plt.cm.ScalarMappable(norm=normalizer, cmap=colour_map)
    scalar_map.set_array([])
    figure.colorbar(scalar_map, ax=axis, pad=0.02, label="Mean absolute HV [kV]")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def auto_zoom_y(axis: plt.Axes, values: list[float], *, lower_limit: float | None = None) -> None:
    finite = np.asarray(values, dtype=float)
    finite = finite[np.isfinite(finite)]
    if finite.size == 0:
        return
    lower, upper = float(finite.min()), float(finite.max())
    if lower_limit is not None:
        lower = lower_limit
        finite = finite[finite >= lower_limit]
        if finite.size == 0:
            return
        upper = float(finite.max())
        if upper > lower:
            axis.set_ylim(lower, upper * 1.05)
        else:
            axis.set_ylim(lower, lower + 0.02)
        return
    padding = (upper - lower) * 0.08
    if padding == 0:
        padding = max(abs(upper) * 0.02, 0.02)
    axis.set_ylim(lower - padding, upper + padding)


def plot_run_conditions(points: list[ScanPoint], path: Path) -> None:
    """Plot available conditions with event-window shading and time tolerance."""
    windows = [(point, point.acquisition_time, point.acquisition_end_time) for point in points]

    hv_samples = read_hv_log_samples()
    if not hv_samples:
        raise FileNotFoundError(f"No HV samples found below {LOGS_DIR}. Run bring_logs.sh first.")
    environment_samples = read_environment_samples()
    panel_count = 5 if environment_samples else 2
    figure, axes = plt.subplots(panel_count, 1, sharex=True, figsize=(12, 2.45 * panel_count), constrained_layout=True)
    axes = np.atleast_1d(axes)
    hv_axis, current_axis = axes[:2]
    timestamps = [sample[0] for sample in hv_samples]
    
    hv_negative_abs = [abs(sample[3]) for sample in hv_samples]
    hv_positive_abs = [abs(sample[4]) for sample in hv_samples]

    hv_axis.plot(
        timestamps,
        hv_negative_abs,
        color="tab:blue",
        linewidth=0.8,
        label="|HV−|",
    )
    hv_axis.plot(
        timestamps,
        hv_positive_abs,
        color="tab:orange",
        linewidth=0.8,
        label="|HV+|",
    )

    current_axis.plot(
        timestamps,
        [sample[1] for sample in hv_samples],
        color="tab:blue",
        linewidth=0.8,
        label="I−",
    )
    current_axis.plot(
        timestamps,
        [sample[2] for sample in hv_samples],
        color="tab:orange",
        linewidth=0.8,
        label="I+",
    )

    hv_axis.set_ylabel("Absolute HV [kV]")
    auto_zoom_y(hv_axis, hv_negative_abs + hv_positive_abs, lower_limit=8.0)
    current_axis.set_ylabel("Current")
    auto_zoom_y(current_axis, [sample[1] for sample in hv_samples] + [sample[2] for sample in hv_samples])
    hv_axis.legend(loc="best", ncol=2)
    current_axis.legend(loc="best", ncol=2)

    if environment_samples:
        temperature_axis, pressure_axis, rh_axis = axes[2:]
        environment_axes = (
            (temperature_axis, 1, "Temperature [°C]"),
            (pressure_axis, 3, "Pressure [mbar]"),
            (rh_axis, 2, "RH [%]"),
        )
        environment_times = [sample[0] for sample in environment_samples]
        for axis, index, ylabel in environment_axes:
            values = [sample[index] for sample in environment_samples]
            axis.plot(environment_times, values, color="tab:green", linewidth=0.8)
            axis.set_ylabel(ylabel)
            auto_zoom_y(axis, values)

    colors = plt.get_cmap("tab10")
    for index, (point, start, end) in enumerate(windows):
        color = colors(index % 10)
        if end is not None and end > start:
            for axis in axes:
                axis.axvspan(start, end, color=color, alpha=0.16, zorder=0)
            hv_axis.annotate(point.label, (start + (end - start) / 2, 0.98), xycoords=("data", "axes fraction"),
                             ha="center", va="top", fontsize=8, color=color)
        else:
            for axis in axes:
                axis.axvline(start, color=color, linestyle="--", linewidth=1.2, alpha=0.9)
            hv_axis.annotate(f"{point.label}\nstart only (no EBtime)", (start, 0.98), xycoords=("data", "axes fraction"),
                             xytext=(3, 0), textcoords="offset points", ha="left", va="top", fontsize=8, color=color)

    window_start = min(start for _, start, _ in windows)
    window_end = max(end or start for _, start, end in windows)
    tolerance = (window_end - window_start) * 0.10
    if tolerance <= timedelta(0):
        tolerance = timedelta(minutes=30)
    range_start = window_start - tolerance
    range_end = window_end + tolerance
    for axis in axes:
        axis.grid(True, alpha=0.3)
        axis.set_xlim(range_start, range_end)
    axes[-1].set_xlabel("Time")
    if environment_samples:
        figure.suptitle("Run conditions: shaded regions are event windows; time axis includes ±10% tolerance")
    else:
        figure.suptitle("No temperature, pressure or RH data available — showing HV and current only; time axis includes ±10% tolerance")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help=f"Scan CSV (default: {DEFAULT_CONFIG})")
    parser.add_argument("--plot-limits", type=Path, default=DEFAULT_PLOT_LIMITS, help=f"Spectrum-overlay limits CSV (default: {DEFAULT_PLOT_LIMITS})")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})")
    args = parser.parse_args()

    try:
        configured_runs = read_scan_config(args.config)
        charge_overlay_limits = read_plot_limits(args.plot_limits)
        file_names, file_names_by_order = run_file_names()
        points = [load_point(run_name, label, file_names, file_names_by_order) for run_name, label in configured_runs]
    except (FileNotFoundError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    args.output_dir.mkdir(parents=True, exist_ok=True)
    png_path = args.output_dir / "result_scan.png"
    charge_heatmap_path = args.output_dir / "result_scan_charge_heatmap.png"
    charge_overlay_path = args.output_dir / "result_scan_charge_spectra_overlay.png"
    conditions_path = args.output_dir / "result_scan_conditions.png"
    summary_path = args.output_dir / "result_scan_summary.csv"
    plot_points(points, png_path)
    try:
        plot_charge_heatmap(points, charge_heatmap_path)
        print(f"Saved charge heatmap: {charge_heatmap_path}")
    except (FileNotFoundError, ValueError) as error:
        print(f"warning: could not create charge heatmap: {error}", file=sys.stderr)
    try:
        plot_charge_spectra_overlay(points, charge_overlay_path, charge_overlay_limits)
        print(f"Saved charge-spectrum overlay: {charge_overlay_path}")
    except (FileNotFoundError, ValueError) as error:
        print(f"warning: could not create charge-spectrum overlay: {error}", file=sys.stderr)
    try:
        plot_run_conditions(points, conditions_path)
    except (FileNotFoundError, ValueError, KeyError) as error:
        print(f"error: could not create run-conditions plot: {error}", file=sys.stderr)
        return 1
    write_summary(points, summary_path)
    print(f"Saved plot: {png_path}")
    print(f"Saved run-conditions plot: {conditions_path}")
    print(f"Saved summary: {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
