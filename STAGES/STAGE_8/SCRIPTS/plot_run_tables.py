from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np

TABLE_DIR = Path("DATA_FILES/DATA/OUTPUTS_7/TABLES")
CHARGE_DIR = Path("DATA_FILES/DATA/OUTPUTS_7/CHARGES")
FILENAME_PATTERN = re.compile(
    r"^RUN_(?P<run>\d+)_summary_.*_exec_(?P<exec>\d{4}_\d{2}_\d{2}-\d{2}\.\d{2}\.\d{2})\.csv$"
)


@dataclass(frozen=True)
class RunFile:
    run: int
    exec_time: datetime
    path: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Plot summary metrics from RUN_* CSV files, selecting the most recent "
            "execution for each run."
        )
    )
    parser.add_argument(
        "-d",
        "--directory",
        type=Path,
        default=TABLE_DIR,
        help="Directory containing RUN_* summary CSV files.",
    )
    parser.add_argument(
        "--detectors",
        nargs="+",
        help="Explicit list of detectors to plot. Defaults to detectors starting with 'RPC_'.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("DATA_FILES/DATA/OUTPUTS_8/run_summary_plots.pdf"),
        help="Destination PDF path. Defaults to DATA_FILES/DATA/OUTPUTS_8/run_summary_plots.pdf.",
    )
    return parser.parse_args()


def _parse_exec_timestamp(value: str) -> datetime:
    return datetime.strptime(value, "%Y_%m_%d-%H.%M.%S")


def find_latest_run_files(directory: Path) -> list[RunFile]:
    latest: dict[int, RunFile] = {}
    for path in directory.glob("RUN_*_exec_*.csv"):
        match = FILENAME_PATTERN.match(path.name)
        if not match:
            continue
        run = int(match.group("run"))
        exec_time = _parse_exec_timestamp(match.group("exec"))
        current = latest.get(run)
        if current is None or exec_time > current.exec_time:
            latest[run] = RunFile(run=run, exec_time=exec_time, path=path)
    if not latest:
        raise FileNotFoundError(f"No RUN_* CSV files found in {directory}.")
    return [latest[run] for run in sorted(latest)]


def _convert_value(raw: str) -> float | int | str | None:
    raw = raw.strip()
    if not raw:
        return None
    if raw.lower() == "nan":
        return float("nan")
    try:
        number = float(raw)
        if number.is_integer():
            return int(number)
        return number
    except ValueError:
        return raw


def _read_metadata(path: Path) -> dict[str, float | int | str | None]:
    metadata: dict[str, float | int | str | None] = {}
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if not line.startswith("#"):
                break
            content = line[1:].strip()
            if ":" not in content:
                continue
            key, value = content.split(":", maxsplit=1)
            converted = _convert_value(value)
            metadata[key.strip()] = converted
    return metadata


def load_run_tables(run_files: list[RunFile]) -> tuple[pd.DataFrame, pd.DataFrame]:
    table_frames: list[pd.DataFrame] = []
    metadata_records: list[dict[str, float | int | str | None]] = []

    for run_file in run_files:
        metadata = _read_metadata(run_file.path)
        metadata["run"] = run_file.run
        metadata["exec_time"] = run_file.exec_time
        metadata_records.append(metadata)

        data = pd.read_csv(run_file.path, comment="#")
        data.columns = data.columns.str.strip()
        if "Detector" not in data.columns:
            raise ValueError(f"'Detector' column not found in {run_file.path.name}")

        data["run"] = run_file.run
        data["exec_time"] = run_file.exec_time

        for column in data.columns:
            if column in {"Detector"}:
                continue
            data[column] = pd.to_numeric(data[column], errors="coerce")

        table_frames.append(data)

    table_frame = (
        pd.concat(table_frames, ignore_index=True)
        .sort_values(["run", "Detector"])
        .reset_index(drop=True)
    )
    table_frame["exec_time"] = pd.to_datetime(table_frame["exec_time"])

    metadata_frame = (
        pd.DataFrame(metadata_records)
        .sort_values("run")
        .reset_index(drop=True)
    )
    metadata_frame["exec_time"] = pd.to_datetime(metadata_frame["exec_time"])

    return table_frame, metadata_frame


def load_charge_histograms(
    run_files: list[RunFile], charge_dir: Path = CHARGE_DIR
) -> pd.DataFrame:
    frames: list[pd.DataFrame] = []
    for run_file in run_files:
        file_path = charge_dir / f"thick_strip_charge_histogram_run_{run_file.run}.csv"
        if not file_path.exists():
            print(
                f"Charge histogram missing for run {run_file.run}: {file_path.name} not found."
            )
            continue
        try:
            data = pd.read_csv(file_path)
        except Exception as exc:  # pragma: no cover - just in case
            print(f"Failed to read {file_path.name}: {exc}")
            continue
        required_cols = {"Charge_bin_center", "Count"}
        if not required_cols.issubset(data.columns):
            print(
                f"Skipping {file_path.name}: expected columns {sorted(required_cols)}."
            )
            continue
        frame = data.loc[:, ["Charge_bin_center", "Count"]].copy()
        frame["run"] = run_file.run
        frames.append(frame)
    if not frames:
        return pd.DataFrame(columns=["Charge_bin_center", "Count", "run"])
    combined = (
        pd.concat(frames, ignore_index=True)
        .dropna(subset=["Charge_bin_center", "Count", "run"])
        .sort_values(["run", "Charge_bin_center"])
        .reset_index(drop=True)
    )
    return combined


def _filter_detectors(
    table_frame: pd.DataFrame, detectors: list[str] | None
) -> tuple[pd.DataFrame, list[str]]:
    all_detectors = sorted(table_frame["Detector"].dropna().unique())
    if detectors:
        missing = sorted(set(detectors) - set(all_detectors))
        if missing:
            raise ValueError(f"Requested detectors not found: {', '.join(missing)}")
        selected = detectors
    else:
        selected = [det for det in all_detectors if det.startswith("RPC_")]
        if not selected:
            selected = all_detectors
    filtered = table_frame[table_frame["Detector"].isin(selected)].copy()
    if filtered.empty:
        raise ValueError("No data remaining after filtering detectors.")
    return filtered, selected


def plot_thick_rpc_summary(
    table_frame: pd.DataFrame,
    detectors: list[str],
    pdf: PdfPages,
) -> None:
    thick_detector = next(
        (det for det in detectors if "thick" in det.lower()), None
    )
    if thick_detector is None:
        print("No thick RPC detector found; skipping combined thick RPC plot.")
        return
    required_columns = {"StreamerPct", "good", "time_res_RPC"}
    missing = [col for col in required_columns if col not in table_frame.columns]
    if missing:
        print(
            "Missing column(s) for thick RPC summary plot; "
            f"skipping: {', '.join(missing)}"
        )
        return
    det_data = (
        table_frame.loc[table_frame["Detector"] == thick_detector]
        .dropna(subset=["run"])
        .sort_values("run")
    )
    if det_data.empty:
        print(
            f"No data available for thick detector {thick_detector}; "
            "skipping combined thick RPC plot."
        )
        return

    fig, axis_streamer = plt.subplots(figsize=(10, 5))

    stream_series = (
        det_data.loc[:, ["run", "StreamerPct"]].dropna(subset=["StreamerPct"])
    )
    good_series = det_data.loc[:, ["run", "good"]].dropna(subset=["good"])
    sigma_series = det_data.loc[:, ["run", "time_res_RPC"]].dropna(
        subset=["time_res_RPC"]
    )

    runs = det_data["run"].astype(int).to_numpy()
    if runs.size:
        axis_streamer.set_xticks(sorted(np.unique(runs)))

    lines = []
    labels: list[str] = []

    if not stream_series.empty:
        line_streamer, = axis_streamer.plot(
            stream_series["run"],
            stream_series["StreamerPct"],
            "-o",
            color="C3",
            label="Streamer %",
        )
        axis_streamer.set_ylabel("Streamer %")
        axis_streamer.spines["left"].set_color("C3")
        axis_streamer.tick_params(axis="y", colors="C3")
        lines.append(line_streamer)
        labels.append("Streamer %")
    else:
        axis_streamer.set_ylabel("Streamer %")

    axis_eff = axis_streamer.twinx()
    if not good_series.empty:
        line_eff, = axis_eff.plot(
            good_series["run"],
            good_series["good"],
            "-s",
            color="C0",
            label="Eff good",
        )
        axis_eff.set_ylabel("Efficiency good (%)", color="C0")
        axis_eff.spines["right"].set_color("C0")
        axis_eff.tick_params(axis="y", colors="C0")
        lines.append(line_eff)
        labels.append("Eff good")
    else:
        axis_eff.set_ylabel("Efficiency good (%)", color="C0")

    axis_sigma = axis_streamer.twinx()
    axis_sigma.spines["right"].set_position(("axes", 1.1))
    axis_sigma.spines["right"].set_visible(True)

    if not sigma_series.empty:
        sigma_ps = sigma_series["time_res_RPC"] * 1000.0
        line_sigma, = axis_sigma.plot(
            sigma_series["run"],
            sigma_ps,
            "-^",
            color="C1",
            label="σ_RPC",
        )
        axis_sigma.set_ylabel("σ_RPC (ps)", color="C1")
        axis_sigma.spines["right"].set_color("C1")
        axis_sigma.tick_params(axis="y", colors="C1")
        lines.append(line_sigma)
        labels.append("σ_RPC")
    else:
        axis_sigma.set_ylabel("σ_RPC (ps)", color="C1")

    axis_streamer.set_xlabel("Run")
    axis_streamer.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
    axis_streamer.set_title(f"{thick_detector}: Streamer %, Eff good, σ_RPC")

    if lines:
        axis_streamer.legend(lines, labels, loc="upper left")

    axis_streamer.set_ylim(0, 100)
    axis_eff.set_ylim(0, 100)
    axis_sigma.set_ylim(50, 200)

    fig.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)


def plot_efficiency_grid(
    table_frame: pd.DataFrame,
    detectors: list[str],
    pdf: PdfPages,
) -> None:
    metrics = [
        ("signal", "signal_unc"),
        ("coin", "coin_unc"),
        ("good", "good_unc"),
        ("range", "range_unc"),
        ("no_crosstalk", "no_crosstalk_unc"),
    ]
    available_metrics = [m for m in metrics if m[0] in table_frame.columns]
    if not available_metrics:
        print("No efficiency metrics found; skipping efficiency grid.")
        return

    nrows = len(detectors)
    ncols = len(available_metrics)
    fig, axes = plt.subplots(
        nrows,
        ncols,
        figsize=(4 * ncols, 3 * nrows),
        sharex=True,
    )
    axes_matrix: np.ndarray
    if nrows == 1 and ncols == 1:
        axes_matrix = np.array([[axes]])  # type: ignore[assignment]
    elif nrows == 1 or ncols == 1:
        axes_matrix = np.atleast_2d(axes)
    else:
        axes_matrix = axes

    for row_idx, detector in enumerate(detectors):
        det_data = table_frame.loc[table_frame["Detector"] == detector]
        det_data = det_data.sort_values("run")
        for col_idx, (metric, metric_unc) in enumerate(available_metrics):
            axis = axes_matrix[row_idx, col_idx]
            values = det_data[["run", metric]].dropna()
            if values.empty:
                axis.set_visible(False)
                continue
            runs = values["run"].to_numpy()
            measurement = values[metric].to_numpy()
            yerr = None
            if metric_unc in det_data.columns:
                unc_values = det_data[["run", metric_unc]].dropna()
                if not unc_values.empty:
                    yerr = unc_values.set_index("run").reindex(runs)[metric_unc].to_numpy()
            axis.errorbar(
                runs,
                measurement,
                yerr=yerr,
                fmt="-o",
                color="C0",
                capsize=3,
            )
            if row_idx == 0:
                axis.set_title(metric.replace("_", " ").title())
            if col_idx == 0:
                axis.set_ylabel(detector)
            axis.set_ylim(0, 100)
            if runs.size > 0:
                xticks = sorted(np.unique(runs.astype(int)))
                axis.set_xticks(xticks)
            axis.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
            if row_idx == nrows - 1:
                axis.set_xlabel("Run")

    fig.suptitle("Detector efficiencies with uncertainties", y=0.995)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    pdf.savefig(fig)
    plt.close(fig)


def plot_streamer_and_charges(
    table_frame: pd.DataFrame,
    detectors: list[str],
    pdf: PdfPages,
) -> None:
    nrows = len(detectors)
    fig, axes = plt.subplots(
        nrows,
        2,
        figsize=(10, 3 * nrows),
        sharex="col",
    )
    axes_matrix: np.ndarray
    if nrows == 1:
        axes_matrix = np.array([axes])
    else:
        axes_matrix = axes

    charge_metrics = ["MeanCharge", "MedianCharge", "MaxCharge"]

    for row_idx, detector in enumerate(detectors):
        axis_stream = axes_matrix[row_idx, 0]
        axis_charge = axes_matrix[row_idx, 1]

        det_data = (
            table_frame.loc[table_frame["Detector"] == detector]
            .sort_values("run")
        )

        run_values = det_data["run"].dropna().astype(int)
        xticks = sorted(np.unique(run_values))

        stream_series = det_data.set_index("run")["StreamerPct"].dropna().sort_index()
        if not stream_series.empty:
            stream_series.index = stream_series.index.astype(int)
            axis_stream.plot(stream_series.index, stream_series.values, "-o", color="C3")
        else:
            axis_stream.text(
                0.5,
                0.5,
                "StreamerPct not available",
                transform=axis_stream.transAxes,
                ha="center",
                va="center",
            )
        axis_stream.set_ylabel(detector)
        if xticks:
            axis_stream.set_xticks(xticks)
        axis_stream.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
        if row_idx == nrows - 1:
            axis_stream.set_xlabel("Run")

        plotted = False
        for idx, metric in enumerate(charge_metrics):
            if metric not in det_data.columns:
                continue
            metric_series = det_data.set_index("run")[metric].dropna().sort_index()
            if metric_series.empty:
                continue
            metric_series.index = metric_series.index.astype(int)
            axis_charge.plot(
                metric_series.index,
                metric_series.values,
                "-o",
                label=metric,
                color=f"C{idx}",
            )
            plotted = True
        if plotted:
            axis_charge.legend()
            if row_idx == 0:
                axis_charge.set_ylabel("Charge (a.u.)")
        else:
            axis_charge.text(
                0.5,
                0.5,
                "Charge metrics not available",
                transform=axis_charge.transAxes,
                ha="center",
                va="center",
            )
        if xticks:
            axis_charge.set_xticks(xticks)
        axis_charge.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
        if row_idx == nrows - 1:
            axis_charge.set_xlabel("Run")

    axes_matrix[0, 0].set_title("StreamerPct vs Run")
    axes_matrix[0, 1].set_title("Charge metrics vs Run")

    fig.suptitle("Additional run metrics per detector", y=0.995)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    pdf.savefig(fig)
    plt.close(fig)


def plot_time_resolutions(
    table_frame: pd.DataFrame,
    pdf: PdfPages,
) -> None:
    required = {"time_res_RPC", "time_res_SC"}
    missing = [col for col in required if col not in table_frame.columns]
    if missing:
        print(
            f"Time resolution column(s) missing; skipping time resolution plots: {', '.join(missing)}"
        )
        return

    fig, axes = plt.subplots(1, 2, figsize=(10, 4), sharex=True)
    axes = np.atleast_1d(axes)
    rpc_axis = axes[0]
    sc_axis = axes[1]

    rpc_series = (
        table_frame.loc[table_frame["Detector"] == "RPC_thick_center", ["run", "time_res_RPC"]]
        .dropna(subset=["time_res_RPC"])
    )
    if rpc_series.empty:
        rpc_axis.text(
            0.5,
            0.5,
            "time_res_RPC not available",
            transform=rpc_axis.transAxes,
            ha="center",
            va="center",
        )
    else:
        rpc_grouped = (
            rpc_series.groupby("run", as_index=False)["time_res_RPC"]
            .mean()
            .sort_values("run")
        )
        runs = rpc_grouped["run"].astype(int).to_numpy()
        rpc_values_ps = rpc_grouped["time_res_RPC"].to_numpy() * 1000.0
        rpc_axis.plot(
            runs,
            rpc_values_ps,
            "-o",
            color="C4",
        )
        rpc_axis.set_xticks(runs)
    rpc_axis.set_xlabel("Run")
    rpc_axis.set_ylabel("σ_RPC (ps)")
    rpc_axis.set_title("sigma_RPC vs Run")
    rpc_axis.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)

    sc_series = (
        table_frame.loc[
            table_frame["Detector"].isin(["PMT_top", "PMT_bottom"]),
            ["run", "time_res_SC"],
        ]
        .dropna(subset=["time_res_SC"])
    )
    if sc_series.empty:
        sc_axis.text(
            0.5,
            0.5,
            "time_res_SC not available",
            transform=sc_axis.transAxes,
            ha="center",
            va="center",
        )
    else:
        sc_grouped = (
            sc_series.groupby("run", as_index=False)["time_res_SC"]
            .mean()
            .sort_values("run")
        )
        runs = sc_grouped["run"].astype(int).to_numpy()
        sc_values_ps = sc_grouped["time_res_SC"].to_numpy() * 1000.0
        sc_axis.plot(
            runs,
            sc_values_ps,
            "-o",
            color="C5",
        )
        sc_axis.set_xticks(runs)
    sc_axis.set_xlabel("Run")
    sc_axis.set_ylabel("σ_SC (ps)")
    sc_axis.set_title("sigma_SC vs Run")
    sc_axis.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)

    fig.suptitle("Time resolution vs Run", y=0.995)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    pdf.savefig(fig)
    plt.close(fig)


def _edges_from_sorted(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=float)
    if values.size == 0:
        return np.array([])
    if values.size == 1:
        step = 1.0
        return np.array([values[0] - step / 2, values[0] + step / 2])
    deltas = np.diff(values)
    start = values[0] - deltas[0] / 2
    end = values[-1] + deltas[-1] / 2
    mids = (values[:-1] + values[1:]) / 2
    return np.concatenate(([start], mids, [end]))


def plot_charge_heatmap(
    hist_frame: pd.DataFrame,
    pdf: PdfPages,
) -> None:
    if hist_frame.empty:
        print("No charge histogram data available; skipping charge heatmap.")
        return

    pivot = (
        hist_frame.pivot_table(
            index="Charge_bin_center",
            columns="run",
            values="Count",
            aggfunc="sum",
        )
        .sort_index()
        .sort_index(axis=1)
    )
    if pivot.empty:
        print("Charge histogram pivot is empty; skipping charge heatmap.")
        return

    runs = pivot.columns.to_numpy()
    bin_centers = pivot.index.to_numpy()
    counts = pivot.to_numpy(dtype=float)
    counts = np.nan_to_num(counts, nan=0.0)
    column_sums = counts.sum(axis=0, keepdims=True)
    column_sums[column_sums == 0] = 1.0
    counts = counts / column_sums

    run_edges = _edges_from_sorted(runs)
    bin_edges = _edges_from_sorted(bin_centers)
    if run_edges.size == 0 or bin_edges.size == 0:
        print("Unable to derive edges for charge heatmap; skipping.")
        return

    fig, ax = plt.subplots(figsize=(8, 6))
    mesh = ax.pcolormesh(run_edges, bin_edges, counts, shading="auto", cmap="viridis")
    cbar = fig.colorbar(mesh, ax=ax, pad=0.02)
    cbar.set_label("Normalized bin occupancy")

    ax.set_xlabel("Run")
    ax.set_ylabel("Charge bin center (ADC bins)")
    ax.set_title("Thick strip charge histogram across runs")
    ax.set_xticks(runs)
    ax.set_xticklabels([str(r) for r in runs])
    ax.set_ylim(bin_edges[0], bin_edges[-1])
    ax.grid(False)

    fig.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)


def main() -> None:
    args = parse_args()
    run_files = find_latest_run_files(args.directory)
    print("Selected files:")
    for item in run_files:
        print(f"  Run {item.run}: {item.path.name} (exec {item.exec_time.isoformat(sep=' ')})")
    table_frame, metadata_frame = load_run_tables(run_files)
    filtered_table, detectors = _filter_detectors(table_frame, args.detectors)
    charge_hist_frame = load_charge_histograms(run_files)

    if not metadata_frame.empty:
        print("\nRun metadata:")
        meta_to_show = metadata_frame.copy()
        meta_to_show["exec_time"] = meta_to_show["exec_time"].dt.strftime("%Y-%m-%d %H:%M:%S")
        formatted = meta_to_show.set_index("run").apply(
            lambda col: col.map(lambda v: f"{v:.4g}" if isinstance(v, float) else v)
        )
        print(formatted.to_string())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with PdfPages(args.output) as pdf:
        plot_thick_rpc_summary(filtered_table, detectors, pdf)
        plot_efficiency_grid(filtered_table, detectors, pdf)
        plot_streamer_and_charges(filtered_table, detectors, pdf)
        plot_time_resolutions(table_frame, pdf)
        plot_charge_heatmap(charge_hist_frame, pdf)
    print(f"\nSaved figures to {args.output}")


if __name__ == "__main__":
    main()
