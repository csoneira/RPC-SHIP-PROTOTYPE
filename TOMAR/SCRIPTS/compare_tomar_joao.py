#!/usr/bin/env python3
"""Create first-pass TOMAR vs JOAO thick-RPC comparisons from CSV results."""

from __future__ import annotations

import csv
import math
import os
import re
from datetime import datetime
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/tomar_joao_matplotlib")

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap


REPO_ROOT = Path(__file__).resolve().parents[2]
TOMAR_ROOT = REPO_ROOT / "TOMAR"
JOAO_ROOT = REPO_ROOT
COMPARISON_ROOT = TOMAR_ROOT / "COMPARISON_JOAO"
OUTPUT_DIR = COMPARISON_ROOT / "OUTPUTS"
TOMAR_SUMMARY = TOMAR_ROOT / "OUTPUTS_SCAN" / "result_scan_summary.csv"
JOAO_RUNS = JOAO_ROOT / "STAGES" / "STAGE_3" / "DATA" / "DATA_FILES" / "file_run_dictionary.csv"
JOAO_TABLES = JOAO_ROOT / "STAGES" / "STAGE_7" / "DATA" / "DATA_FILES" / "OUTPUTS_7" / "TABLES"
JOAO_CHARGES = JOAO_ROOT / "STAGES" / "STAGE_7" / "DATA" / "DATA_FILES" / "OUTPUTS_7" / "CHARGES"
JOAO_LOGS = JOAO_ROOT / "STAGES" / "STAGE_2" / "DATA" / "DATA_FILES" / "ACCUMULATED"
LIMITS_CONFIG = COMPARISON_ROOT / "comparison_limits.csv"
JOAO_SELECTION_CONFIG = COMPARISON_ROOT / "joao_run_selection.csv"


def green_viridis() -> LinearSegmentedColormap:
    """Viridis without its pale yellow endpoint, for legible light backgrounds."""
    base = plt.get_cmap("viridis")
    return LinearSegmentedColormap.from_list("viridis_green_top", base(np.linspace(0, 0.70, 256)))


def number(value: str | None) -> float:
    try:
        result = float(value or "nan")
    except ValueError:
        return math.nan
    return result if math.isfinite(result) else math.nan


def read_csv(path: Path, *, skip_comments: bool = False) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        lines = (line for line in handle if not skip_comments or not line.startswith("#"))
        return list(csv.DictReader(lines, skipinitialspace=True))


def read_limits() -> dict[str, float]:
    required = {"charge_min", "charge_max", "hv_min_kv", "hv_max_kv"}
    if not LIMITS_CONFIG.is_file():
        raise FileNotFoundError(f"Comparison limits configuration not found: {LIMITS_CONFIG}")
    values = {row.get("parameter", "").strip(): number(row.get("value")) for row in read_csv(LIMITS_CONFIG)}
    missing = [key for key in required if key not in values or not math.isfinite(values[key])]
    if missing:
        raise ValueError(f"{LIMITS_CONFIG} needs finite values for: {', '.join(sorted(missing))}")
    if values["charge_min"] >= values["charge_max"] or values["hv_min_kv"] >= values["hv_max_kv"]:
        raise ValueError("Comparison maximum limits must be greater than their minimum limits.")
    return values


def read_date_ranges() -> dict[str, tuple[datetime, datetime]]:
    names = ("tomar", "joao")
    rows = {row.get("parameter", "").strip(): row.get("value", "").strip() for row in read_csv(LIMITS_CONFIG)}
    ranges: dict[str, tuple[datetime, datetime]] = {}
    for name in names:
        try:
            start = datetime.fromisoformat(rows[f"{name}_date_start"])
            end = datetime.fromisoformat(rows[f"{name}_date_end"])
        except (KeyError, ValueError) as error:
            raise ValueError(f"{LIMITS_CONFIG} needs ISO dates for {name}_date_start and {name}_date_end.") from error
        if start >= end:
            raise ValueError(f"{name} date end must be later than its start.")
        ranges[name] = (start, end)
    return ranges


def read_joao_selection() -> dict[int, dict[str, str]]:
    """Read the explicit, condition-based JOAO run selection.

    The logbook contains acquisitions made with different HV supplies,
    pressure regimes and trigger configurations.  Only rows explicitly marked
    ``include`` are allowed into the TOMAR comparison.
    """
    if not JOAO_SELECTION_CONFIG.is_file():
        raise FileNotFoundError(
            f"JOAO run-selection configuration not found: {JOAO_SELECTION_CONFIG}"
        )
    selection: dict[int, dict[str, str]] = {}
    for row in read_csv(JOAO_SELECTION_CONFIG):
        try:
            run = int(row.get("run", ""))
        except ValueError as error:
            raise ValueError(f"Invalid run number in {JOAO_SELECTION_CONFIG}: {row!r}") from error
        decision = row.get("selection", "").strip().lower()
        if decision not in {"include", "exclude"}:
            raise ValueError(
                f"Run {run} in {JOAO_SELECTION_CONFIG} must have selection include or exclude."
            )
        selection[run] = {key: value.strip() for key, value in row.items() if key != "run"}
    return selection


def read_tomar() -> list[dict[str, object]]:
    if not TOMAR_SUMMARY.is_file():
        raise FileNotFoundError(f"TOMAR scan summary not found: {TOMAR_SUMMARY}")
    result: list[dict[str, object]] = []
    for row in read_csv(TOMAR_SUMMARY):
        result.append({
            "run": row["run_name"], "label": row.get("label") or row["run_name"],
            "hv_kv": number(row.get("hv_mean_abs_kv")),
            "efficiency_percent": number(row.get("efficiency_percent")),
            "efficiency_uncertainty_percent": number(row.get("efficiency_uncertainty_percent")),
            "scintillator_efficiency_percent": number(row.get("scintillator_conditioned_efficiency_percent")),
            "scintillator_efficiency_uncertainty_percent": number(row.get("scintillator_conditioned_efficiency_uncertainty_percent")),
            "streamer_percent": number(row.get("streamer_percent")),
            "source_output_dir": row["source_output_dir"],
            "acquisition_time": row.get("acquisition_time", ""),
        })
    return result


def read_joao(selection: dict[int, dict[str, str]]) -> list[dict[str, object]]:
    if not JOAO_RUNS.is_file() or not JOAO_TABLES.is_dir() or not JOAO_CHARGES.is_dir():
        raise FileNotFoundError("JOAO CSV inputs are missing. Sync the Stage 3 and Stage 7 CSV results first.")
    run_metadata: dict[int, tuple[float, str, str]] = {}
    for row in read_csv(JOAO_RUNS):
        try:
            run = int(row["run"])
        except (KeyError, ValueError):
            continue
        hv_v = number(row.get("hv_ch1_start"))
        if math.isfinite(hv_v):
            run_metadata[run] = (hv_v / 1000.0, row.get("start", ""), row.get("end", ""))

    result: list[dict[str, object]] = []
    for table_path in sorted(JOAO_TABLES.glob("RUN_*_summary.csv")):
        match = re.fullmatch(r"RUN_(\d+)_summary", table_path.stem)
        if not match:
            continue
        run = int(match.group(1))
        run_selection = selection.get(run)
        if not run_selection or run_selection["selection"].lower() != "include":
            continue
        hv_kv, run_start, run_end = run_metadata.get(run, (math.nan, "", ""))
        charge_path = JOAO_CHARGES / f"thick_strip_charge_histogram_run_{run}.csv"
        if not math.isfinite(hv_kv) or not charge_path.is_file():
            continue
        thick_rows = [row for row in read_csv(table_path, skip_comments=True) if "thick" in (row.get("Detector") or "").lower()]
        if not thick_rows:
            continue
        thick = thick_rows[0]
        # Stage 7's ``range`` metric uses four-PMT coincidence and requires
        # every PMT charge to be within its per-run 20th--80th percentile
        # interval.  Its denominator is that qualified scintillator sample.
        # This matches the TOMAR comparison principle: particle candidates
        # selected by scintillator coincidence and valid scintillator charge,
        # rather than all acquisition triggers.
        efficiency = number(thick.get("range"))
        streamer = number(thick.get("StreamerPct"))
        if not math.isfinite(efficiency) or not math.isfinite(streamer):
            continue
        result.append({
            "run": run, "label": f"R{run}", "hv_kv": hv_kv,
            "efficiency_percent": efficiency, "efficiency_uncertainty_percent": number(thick.get("range_unc")),
            "streamer_percent": streamer, "charge_path": str(charge_path), "run_start": run_start, "run_end": run_end,
            "efficiency_definition": "4-PMT coincidence + PMT charge window (20th-80th percentile)",
            "conditions": run_selection.get("conditions", ""), "selection_reason": run_selection.get("reason", ""),
        })
    return sorted(result, key=lambda row: (float(row["hv_kv"]), int(row["run"])))


def write_table(rows: list[dict[str, object]], path: Path) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def error_values(rows: list[dict[str, object]], key: str) -> list[float] | None:
    values = [float(row.get(key, math.nan)) for row in rows]
    return values if any(math.isfinite(value) for value in values) else None


def plot_performance(tomar: list[dict[str, object]], joao: list[dict[str, object]], limits: dict[str, float], path: Path) -> None:
    figure, (eff_axis, streamer_axis) = plt.subplots(2, 1, figsize=(10, 8), sharex=True, constrained_layout=True)
    tom_x = [float(row["hv_kv"]) for row in tomar]
    eff_axis.errorbar(tom_x, [float(row["efficiency_percent"]) for row in tomar], yerr=error_values(tomar, "efficiency_uncertainty_percent"),
                      marker="o", linewidth=2, capsize=3, color="tab:blue", label="TOMAR: all events")
    eff_axis.errorbar(tom_x, [float(row["scintillator_efficiency_percent"]) for row in tomar], yerr=error_values(tomar, "scintillator_efficiency_uncertainty_percent"),
                      marker="s", linewidth=2, capsize=3, color="tab:green", label="TOMAR: scintillator selected")
    joao_x = [float(row["hv_kv"]) for row in joao]
    eff_axis.errorbar(joao_x, [float(row["efficiency_percent"]) for row in joao], yerr=error_values(joao, "efficiency_uncertainty_percent"),
                      marker="^", linestyle="none", capsize=2, color="tab:purple", label="JOAO: thick RPC, scintillator qualified")
    for row in joao:
        eff_axis.annotate(str(row["label"]), (float(row["hv_kv"]), float(row["efficiency_percent"])), xytext=(2, 4), textcoords="offset points", fontsize=7, color="tab:purple")
    eff_axis.set_ylabel("Efficiency [%]")
    eff_axis.set_ylim(top=100)
    eff_axis.grid(True, alpha=0.3)
    eff_axis.legend(loc="best")

    streamer_axis.plot(tom_x, [float(row["streamer_percent"]) for row in tomar], marker="o", linewidth=2, color="tab:red", label="TOMAR")
    streamer_axis.scatter(joao_x, [float(row["streamer_percent"]) for row in joao], marker="^", color="tab:purple", label="JOAO: thick RPC")
    streamer_axis.set_xlabel("HV [kV]")
    streamer_axis.set_ylabel("Streamer fraction [%]")
    streamer_axis.grid(True, alpha=0.3)
    streamer_axis.legend(loc="best")
    streamer_axis.set_xlim(limits["hv_min_kv"], limits["hv_max_kv"])
    figure.suptitle("TOMAR vs JOAO thick-RPC performance versus HV")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def load_spectrum(path: Path) -> tuple[np.ndarray, np.ndarray]:
    rows = read_csv(path)
    centers = np.array([number(row.get("Charge_bin_center")) for row in rows])
    counts = np.array([number(row.get("Count")) for row in rows])
    valid = np.isfinite(centers) & np.isfinite(counts)
    return centers[valid], counts[valid]


def plot_heatmap(axis: plt.Axes, entries: list[dict[str, object]], source_key: str, y_label: str, title: str, limits: dict[str, float]) -> None:
    spectra = [load_spectrum(Path(str(row[source_key]))) for row in entries]
    centers = np.array(sorted(set(np.concatenate([spectrum[0] for spectrum in spectra]))))
    matrix = np.zeros((len(centers), len(spectra)))
    for column, (x_values, counts) in enumerate(spectra):
        lookup = dict(zip(x_values, counts))
        matrix[:, column] = [lookup.get(center, 0.0) for center in centers]
    totals = matrix.sum(axis=0, keepdims=True)
    totals[totals == 0] = 1
    matrix /= totals
    y_step = np.median(np.diff(centers)) if len(centers) > 1 else 1.0
    y_edges = np.concatenate(([centers[0] - y_step / 2], (centers[:-1] + centers[1:]) / 2, [centers[-1] + y_step / 2]))
    x_edges = np.arange(0.5, len(entries) + 1.5)
    mesh = axis.pcolormesh(x_edges, y_edges, matrix, cmap=green_viridis(), shading="flat")
    axis.figure.colorbar(mesh, ax=axis, pad=0.02, label="Normalized bin occupancy")
    axis.set_xticks(np.arange(1, len(entries) + 1), [str(row["label"]) for row in entries], rotation=90)
    axis.set_ylabel(y_label)
    axis.set_ylim(limits["charge_min"], limits["charge_max"])
    axis.set_title(title)


def plot_spectra(tomar: list[dict[str, object]], joao: list[dict[str, object]], limits: dict[str, float], path: Path) -> None:
    for row in tomar:
        row["charge_path"] = str(Path(str(row["source_output_dir"])) / f"{row['run']}_q_sum_charge_histogram.csv")
    figure, axes = plt.subplots(1, 2, figsize=(15, 6), constrained_layout=True)
    plot_heatmap(axes[0], tomar, "charge_path", "TOMAR q_sum [ns]", "TOMAR scan spectra", limits)
    plot_heatmap(axes[1], joao, "charge_path", "JOAO thick charge [ADC bins]", "JOAO thick-RPC spectra", limits)
    figure.suptitle("Native-unit charge-spectrum comparison")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def plot_overlay_spectra(tomar: list[dict[str, object]], joao: list[dict[str, object]], limits: dict[str, float], path: Path) -> None:
    """Overlay normalized charge histograms, with colour encoding measured HV."""
    for row in tomar:
        row["charge_path"] = str(Path(str(row["source_output_dir"])) / f"{row['run']}_q_sum_charge_histogram.csv")
    figure, axes = plt.subplots(1, 2, figsize=(15, 6), constrained_layout=True)
    colour_map = green_viridis()
    normalizer = plt.Normalize(limits["hv_min_kv"], limits["hv_max_kv"])
    for axis, entries, title, y_label in (
        (axes[0], tomar, "TOMAR scan spectra", "Normalized bin occupancy"),
        (axes[1], joao, "JOAO thick-RPC spectra", "Normalized bin occupancy"),
    ):
        for row in entries:
            centers, counts = load_spectrum(Path(str(row["charge_path"])))
            selected = (centers >= limits["charge_min"]) & (centers <= limits["charge_max"])
            centers, counts = centers[selected], counts[selected]
            total = counts.sum()
            if total <= 0:
                continue
            axis.step(centers, counts / total, where="mid", linewidth=1.5,
                      color=colour_map(normalizer(float(row["hv_kv"]))),
                      label=f"{row['label']} ({float(row['hv_kv']):.3g} kV)")
        axis.set_xlim(limits["charge_min"], limits["charge_max"])
        axis.set_xlabel("Charge [ns]" if axis is axes[0] else "Charge [ADC bins]")
        axis.set_ylabel(y_label)
        axis.set_title(title)
        axis.grid(True, alpha=0.3)
        axis.legend(loc="best", fontsize=7, ncol=2)
    scalar_map = plt.cm.ScalarMappable(norm=normalizer, cmap=colour_map)
    scalar_map.set_array([])
    figure.colorbar(scalar_map, ax=axes, pad=0.02, label="HV [kV]")
    figure.suptitle("Native-unit charge spectra: normalized histograms overlaid by HV")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def parse_time(value: str) -> datetime | None:
    try:
        return datetime.fromisoformat(value.strip())
    except ValueError:
        return None


def filter_by_dates(tomar: list[dict[str, object]], joao: list[dict[str, object]], ranges: dict[str, tuple[datetime, datetime]]) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    tomar_start, tomar_end = ranges["tomar"]
    selected_tomar = [row for row in tomar if (stamp := parse_time(str(row["acquisition_time"]))) and tomar_start <= stamp <= tomar_end]
    joao_start, joao_end = ranges["joao"]
    selected_joao = []
    for row in joao:
        start = parse_time(str(row["run_start"]))
        # Select by acquisition start date. This makes the configuration a
        # predictable run selector even when a JOAO acquisition spans days.
        if start and joao_start <= start <= joao_end:
            selected_joao.append(row)
    return selected_tomar, selected_joao


def log_rows(path: Path, start: datetime, end: datetime) -> list[dict[str, object]]:
    if not path.is_file():
        return []
    result: list[dict[str, object]] = []
    for row in read_csv(path):
        timestamp = parse_time(row.get("Time", ""))
        if timestamp and start <= timestamp <= end:
            result.append({"time": timestamp, **{key: number(value) for key, value in row.items() if key != "Time"}})
    return result


def plot_joao_conditions(joao: list[dict[str, object]], date_range: tuple[datetime, datetime], path: Path) -> None:
    start, end = date_range
    hv4 = log_rows(JOAO_LOGS / "hv4_aggregated.csv", start, end)
    hv5 = log_rows(JOAO_LOGS / "hv5_aggregated.csv", start, end)
    sensors = log_rows(JOAO_LOGS / "sensors_bus0_aggregated.csv", start, end)
    figure, axes = plt.subplots(5, 1, figsize=(12, 12), sharex=True, constrained_layout=True)
    hv_axis, current_axis, temperature_axis, pressure_axis, rh_axis = axes
    for rows, label, color in ((hv4, "HV4", "tab:blue"), (hv5, "HV5", "tab:orange")):
        if not rows:
            continue
        times = [row["time"] for row in rows]
        hv_axis.plot(times, [float(row.get("HVneg", math.nan)) for row in rows], color=color, linewidth=0.7, label=f"{label} HV−")
        hv_axis.plot(times, [float(row.get("HVpos", math.nan)) for row in rows], color=color, linewidth=0.7, linestyle="--", label=f"{label} HV+")
        current_axis.plot(times, [float(row.get("CurrentNeg", math.nan)) for row in rows], color=color, linewidth=0.7, label=f"{label} I−")
        current_axis.plot(times, [float(row.get("CurrentPos", math.nan)) for row in rows], color=color, linewidth=0.7, linestyle="--", label=f"{label} I+")
    hv_axis.set_ylabel("HV [kV]")
    current_axis.set_ylabel("Current")
    if hv4 or hv5:
        hv_axis.legend(loc="best", ncol=2, fontsize=8)
        current_axis.legend(loc="best", ncol=2, fontsize=8)
    for axis, column, ylabel in ((temperature_axis, "Temperature_ext", "Temperature [°C]"), (pressure_axis, "Pressure_ext", "Pressure [mbar]"), (rh_axis, "RH_ext", "RH [%]")):
        axis.set_ylabel(ylabel)
        if sensors:
            axis.plot([row["time"] for row in sensors], [float(row.get(column, math.nan)) for row in sensors], color="tab:green", linewidth=0.7)
        else:
            axis.text(0.5, 0.5, "No JOAO sensor samples in selected date range", transform=axis.transAxes, ha="center", va="center", color="0.35")
    colors = plt.get_cmap("tab20")
    for index, row in enumerate(joao):
        run_start = parse_time(str(row["run_start"]))
        run_end = parse_time(str(row["run_end"])) or end
        if not run_start:
            continue
        left, right = max(run_start, start), min(run_end, end)
        if left >= right:
            continue
        color = colors(index % 20)
        for axis in axes:
            axis.axvspan(left, right, color=color, alpha=0.13, zorder=0)
        hv_axis.annotate(str(row["label"]), (left + (right - left) / 2, 0.98), xycoords=("data", "axes fraction"), ha="center", va="top", fontsize=7, color=color)
    for axis in axes:
        axis.set_xlim(start, end)
        axis.grid(True, alpha=0.3)
    rh_axis.set_xlabel("Time")
    figure.suptitle("JOAO setup conditions: coloured regions are selected thick-RPC run windows")
    figure.savefig(path, dpi=180)
    plt.close(figure)


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    limits = read_limits()
    date_ranges = read_date_ranges()
    tomar, joao = filter_by_dates(read_tomar(), read_joao(read_joao_selection()), date_ranges)
    tomar = [row for row in tomar if limits["hv_min_kv"] <= float(row["hv_kv"]) <= limits["hv_max_kv"]]
    joao = [row for row in joao if limits["hv_min_kv"] <= float(row["hv_kv"]) <= limits["hv_max_kv"]]
    if not tomar or not joao:
        raise RuntimeError("Both TOMAR scan points and JOAO thick-RPC CSV rows are required.")
    write_table(tomar, OUTPUT_DIR / "tomar_scan_points.csv")
    write_table(joao, OUTPUT_DIR / "joao_thick_rpc_points.csv")
    plot_performance(tomar, joao, limits, OUTPUT_DIR / "tomar_joao_hv_performance.png")
    plot_spectra(tomar, joao, limits, OUTPUT_DIR / "tomar_joao_thick_charge_spectra.png")
    plot_overlay_spectra(tomar, joao, limits, OUTPUT_DIR / "tomar_joao_thick_charge_spectra_overlay.png")
    plot_joao_conditions(joao, date_ranges["joao"], OUTPUT_DIR / "joao_run_conditions.png")
    print(f"Saved comparison results in {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
