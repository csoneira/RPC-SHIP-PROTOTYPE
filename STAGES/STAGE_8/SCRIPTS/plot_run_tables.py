from __future__ import annotations

import argparse
import re
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.figure import Figure
import numpy as np

TABLE_DIR = Path("STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/TABLES")
CHARGE_DIR = Path("STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/CHARGES")
OUTPUT_STAGE8_DIR = Path("STAGES/STAGE_8/DATA/DATA_FILES/OUTPUTS_8")
PNG_SUBDIR_NAME = "RUN_SUMMARY_PNG"
PNG_OUTPUT_DIRS = [OUTPUT_STAGE8_DIR / PNG_SUBDIR_NAME]
SUMMARY_CSV_PATH = OUTPUT_STAGE8_DIR / "thick_rpc_summary_data.csv"
NEW_FILENAME_PATTERN = re.compile(r"^RUN_(?P<run>\d+)_summary\.csv$")
LEGACY_FILENAME_PATTERN = re.compile(
    r"^RUN_(?P<run>\d+)_summary_.*_exec_(?P<exec>\d{4}_\d{2}_\d{2}-\d{2}\.\d{2}\.\d{2})\.csv$"
)
RUN_DICT_PATH = Path("STAGES/STAGE_3/DATA/DATA_FILES/file_run_dictionary.csv")

DEFAULT_RUN_TABLE_SIMPLE_PAGES = 7
SaveFigure = Callable[[Figure, str], None]


@dataclass(frozen=True)
class RunFile:
    run: int
    exec_time: datetime
    path: Path


class FigureSaver:
    def __init__(
        self,
        pdf: PdfPages | None = None,
        png_dirs: list[Path] | None = None,
    ) -> None:
        self._pdf = pdf
        self._png_dirs = [Path(path) for path in (png_dirs or [])]
        if self._pdf is None and not self._png_dirs:
            raise ValueError(
                "FigureSaver requires at least one output target (PDF or PNG directories)."
            )

    def for_run(self, run_id: int | None) -> SaveFigure:
        def _save(figure: Figure, label: str) -> None:
            self._save_figure(figure, label, run_id)

        return _save

    def _save_figure(self, figure: Figure, label: str, run_id: int | None) -> None:
        if self._pdf is not None:
            self._pdf.savefig(figure)
        if not self._png_dirs:
            return
        filename = self._format_filename(label, run_id)
        for directory in self._png_dirs:
            directory.mkdir(parents=True, exist_ok=True)
            target = directory / filename
            figure.savefig(target, dpi=150, bbox_inches="tight")

    @staticmethod
    def _format_filename(label: str, run_id: int | None) -> str:
        safe_label = re.sub(r"[^0-9A-Za-z_]+", "_", label).strip("_") or "figure"
        if run_id is not None:
            return f"run_{run_id:04d}_{safe_label}.png"
        return f"{safe_label}.png"


def _subset_frame_by_run(frame: pd.DataFrame, run_id: int) -> pd.DataFrame:
    if "run" not in frame.columns:
        return frame.copy()
    return frame.loc[frame["run"] == run_id].copy()


def _png_dirs_for_run(run_id: int) -> list[Path]:
    label = f"RUN_{run_id:04d}"
    return [base / label for base in PNG_OUTPUT_DIRS]


def _coerce_float(value: float | int | str | None) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        number = float(value)
        if not np.isfinite(number):
            return None
        return number
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            number = float(text)
            if not np.isfinite(number):
                return None
            return number
        except ValueError:
            return None
    return None


def _hv_for_run(
    run_value: float | int | str,
    hv_map: dict[int, float],
    vs_hv: bool,
    run_positions: dict[int, int] | None = None,
) -> float | None:
    try:
        run_int = int(float(run_value))
    except (TypeError, ValueError):
        return None
    if vs_hv:
        hv_value = hv_map.get(run_int)
        if hv_value is not None:
            return float(hv_value)
        if run_positions:
            pos = run_positions.get(run_int)
            if pos is not None:
                return float(pos)
        return float(run_int)
    if run_positions:
        pos = run_positions.get(run_int)
        if pos is not None:
            return float(pos)
    return float(run_int)


def _append_x_values(
    frame: pd.DataFrame,
    hv_map: dict[int, float],
    vs_hv: bool,
    run_positions: dict[int, int] | None = None,
) -> pd.DataFrame:
    if "run" not in frame.columns:
        return frame
    working = frame.copy()
    working["x_value"] = working["run"].apply(lambda r: _hv_for_run(r, hv_map, vs_hv, run_positions))
    return working


def _set_run_xticks(axis: plt.Axes, ticks: list[float], run_positions: dict[int, int] | None) -> None:
    if not ticks:
        return
    axis.set_xticks(ticks)
    if run_positions:
        pos_to_run = {float(pos): run for run, pos in run_positions.items()}
        labels = [str(int(pos_to_run.get(tick, tick))) for tick in ticks]
        axis.set_xticklabels(labels)


def _unique_xticks(values: pd.Series) -> list[float]:
    cleaned = values.dropna().astype(float).to_numpy()
    if cleaned.size == 0:
        return []
    return sorted(np.unique(cleaned))


def _load_hv_map(path: Path, runs: set[int] | None = None) -> dict[int, float]:
    if not path.exists():
        return {}
    try:
        df = pd.read_csv(path)
    except Exception:
        return {}
    run_col = None
    for candidate in ("run", "run_id"):
        if candidate in df.columns:
            run_col = candidate
            break
    if run_col is None:
        return {}
    hv_candidates = [
        "hv_ch1_start",
        "hv_ch1_end",
        "hv_ch2_start",
        "hv_ch2_end",
        "hv_start",
        "hv_end",
    ]
    hv_columns = [col for col in hv_candidates if col in df.columns]
    if not hv_columns:
        return {}
    hv_map: dict[int, float] = {}
    for _, row in df.iterrows():
        run_raw = row.get(run_col)
        try:
            run_int = int(float(run_raw))
        except (TypeError, ValueError):
            continue
        if runs is not None and run_int not in runs:
            continue
        hv_value: float | None = None
        for col in hv_columns:
            hv_value = _coerce_float(row.get(col))
            if hv_value is not None:
                break
        if hv_value is not None:
            hv_map[run_int] = hv_value
    return hv_map


def _load_run_times(path: Path, runs: set[int] | None = None) -> dict[int, tuple[str | None, str | None]]:
    """
    Load run start/end times from the run dictionary CSV.

    Returns a mapping run_id -> (start_str, end_str) where strings are formatted
    as "YYYY-MM-DD HH:MM:SS" when parsable, otherwise original string, or None.
    """
    if not path.exists():
        return {}
    try:
        df = pd.read_csv(path)
    except Exception:
        return {}
    run_col = None
    for candidate in ("run", "run_id"):
        if candidate in df.columns:
            run_col = candidate
            break
    if run_col is None:
        return {}

    # find candidate columns for start / end (case-insensitive)
    start_candidates = [c for c in df.columns if re.search(r"(?i)\bstart\b|start_time|start_date|run_start", c)]
    end_candidates = [c for c in df.columns if re.search(r"(?i)\bend\b|end_time|end_date|run_end", c)]

    if not start_candidates and not end_candidates:
        return {}

    start_col = start_candidates[0] if start_candidates else None
    end_col = end_candidates[0] if end_candidates else None

    run_times: dict[int, tuple[str | None, str | None]] = {}
    for _, row in df.iterrows():
        run_raw = row.get(run_col)
        try:
            run_int = int(float(run_raw))
        except (TypeError, ValueError):
            continue
        if runs is not None and run_int not in runs:
            continue

        def _fmt_datetime(val) -> str | None:
            if val is None or (isinstance(val, float) and np.isnan(val)):
                return None
            # try pandas parsing first
            try:
                parsed = pd.to_datetime(val, errors="coerce")
            except Exception:
                parsed = pd.NaT
            if pd.notna(parsed):
                return parsed.strftime("%Y-%m-%d %H:%M:%S")
            # fallback to string if not parsable
            s = str(val).strip()
            return s if s else None

        start_str = _fmt_datetime(row.get(start_col)) if start_col else None
        end_str = _fmt_datetime(row.get(end_col)) if end_col else None
        if start_str is None and end_str is None:
            continue
        run_times[run_int] = (start_str, end_str)

    return run_times


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
        "-r",
        "--runs",
        type=int,
        nargs="+",
        help="Only include the specified run ids when building plots.",
    )
    parser.add_argument(
        "--vs-hv",
        action="store_true",
        help=(
            "Use the HV setpoint from the Stage 3 run dictionary on the X axis instead of run ids. "
            "Falls back to run ids if HV metadata is unavailable."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("STAGES/STAGE_8/DATA/DATA_FILES/OUTPUTS_8/run_summary_plots.pdf"),
        help="Destination PDF path. Defaults to STAGES/STAGE_8/DATA/DATA_FILES/OUTPUTS_8/run_summary_plots.pdf.",
    )
    parser.add_argument(
        "--png-only",
        action="store_true",
        help=(
            "Skip PDF generation and instead export per-run PNG figures into both "
            "STAGE_7 and STAGE_8 run summary directories."
        ),
    )
    parser.add_argument(
        "--simple-pdf",
        action="store_true",
        help=(
            "Limit PDF export to a lightweight subset of figures. "
            f"Defaults to {DEFAULT_RUN_TABLE_SIMPLE_PAGES} pages."
        ),
    )
    parser.add_argument(
        "--full-pdf",
        action="store_true",
        help="Export every available figure (overrides --simple-pdf defaults).",
    )
    parser.add_argument(
        "--pdf-max-pages",
        type=int,
        help="Cap the number of figure pages written to the PDF.",
    )
    return parser.parse_args()


def _parse_exec_timestamp(value: str) -> datetime:
    return datetime.strptime(value, "%Y_%m_%d-%H.%M.%S")


def find_latest_run_files(directory: Path) -> list[RunFile]:
    latest: dict[int, RunFile] = {}
    for path in directory.glob("RUN_*_summary*.csv"):
        run: int | None = None
        exec_time: datetime | None = None
        match = NEW_FILENAME_PATTERN.match(path.name)
        if match:
            run = int(match.group("run"))
            exec_time = datetime.fromtimestamp(path.stat().st_mtime)
        else:
            legacy = LEGACY_FILENAME_PATTERN.match(path.name)
            if legacy:
                run = int(legacy.group("run"))
                exec_time = _parse_exec_timestamp(legacy.group("exec"))
        if run is None or exec_time is None:
            continue
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
    patterns = [
        ("thick", "thick_strip_charge_histogram_run_{run}.csv"),
        ("thin_top", "thin_top_charge_histogram_run_{run}.csv"),
        ("thin_bottom", "thin_bottom_charge_histogram_run_{run}.csv"),
    ]
    for strip_type, template in patterns:
        for run_file in run_files:
            file_path = charge_dir / template.format(run=run_file.run)
            if not file_path.exists():
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
            frame["strip_type"] = strip_type
            frames.append(frame)
    if not frames:
        return pd.DataFrame(columns=["Charge_bin_center", "Count", "run", "strip_type"])
    combined = (
        pd.concat(frames, ignore_index=True)
        .dropna(subset=["Charge_bin_center", "Count", "run"])
        .sort_values(["run", "strip_type", "Charge_bin_center"])
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
    save_figure: SaveFigure,
    hv_map: dict[int, float],
    vs_hv: bool,
    x_label: str,
    run_positions: dict[int, int] | None = None,
) -> bool:
    thick_detector = next(
        (det for det in detectors if "thick" in det.lower()), None
    )
    if thick_detector is None:
        print("No thick RPC detector found; skipping combined thick RPC plot.")
        return False
    required_columns = {"StreamerPct", "good", "time_res_RPC"}
    missing = [col for col in required_columns if col not in table_frame.columns]
    if missing:
        print(
            "Missing column(s) for thick RPC summary plot; "
            f"skipping: {', '.join(missing)}"
        )
        return False
    det_data = (
        table_frame.loc[table_frame["Detector"] == thick_detector]
        .dropna(subset=["run"])
        .pipe(lambda df: _append_x_values(df, hv_map, vs_hv, run_positions))
        .dropna(subset=["x_value"])
        .sort_values("x_value")
    )
    if det_data.empty:
        print(
            f"No data available for thick detector {thick_detector}; "
            "skipping combined thick RPC plot."
        )
        return False

    fig, axis_streamer = plt.subplots(figsize=(10, 5))

    def _extract_unc(values: pd.DataFrame, column: str) -> np.ndarray | None:
        if values.empty or column not in det_data.columns:
            return None
        available = det_data.loc[:, ["run", "x_value", column]].dropna(subset=[column])
        if available.empty:
            return None
        merged = values.merge(available, on="run", how="left")
        yerr = merged[column].astype(float).to_numpy()
        if np.isnan(yerr).all():
            return None
        return yerr

    error_capsize = 3

    stream_series = (
        det_data.loc[:, ["run", "x_value", "StreamerPct"]]
        .dropna(subset=["StreamerPct"])
        .sort_values("x_value")
    )
    stream_unc = _extract_unc(stream_series, "StreamerPct_unc")
    good_series = (
        det_data.loc[:, ["run", "x_value", "good"]]
        .dropna(subset=["good"])
        .sort_values("x_value")
    )
    good_unc = _extract_unc(good_series, "good_unc")
    sigma_series = (
        det_data.loc[:, ["run", "x_value", "time_res_RPC"]]
        .dropna(subset=["time_res_RPC"])
        .sort_values("x_value")
    )
    sigma_unc = _extract_unc(sigma_series, "time_res_RPC_unc")

    xticks = _unique_xticks(det_data["x_value"])
    _set_run_xticks(axis_streamer, xticks, run_positions)

    lines = []
    labels: list[str] = []

    if not stream_series.empty:
        stream_plot = axis_streamer.errorbar(
            stream_series["x_value"],
            stream_series["StreamerPct"],
            yerr=stream_unc,
            fmt="-o",
            color="C3",
            label="Streamer %",
            capsize=error_capsize,
        )
        line_streamer = stream_plot.lines[0]
        axis_streamer.set_ylabel("Streamer %")
        axis_streamer.spines["left"].set_color("C3")
        axis_streamer.tick_params(axis="y", colors="C3")
        lines.append(line_streamer)
        labels.append("Streamer %")
    else:
        axis_streamer.set_ylabel("Streamer %")

    axis_eff = axis_streamer.twinx()
    if not good_series.empty:
        good_plot = axis_eff.errorbar(
            good_series["x_value"],
            good_series["good"],
            yerr=good_unc,
            fmt="-s",
            color="C0",
            label="Eff good",
            capsize=error_capsize,
        )
        line_eff = good_plot.lines[0]
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
        if sigma_unc is not None:
            sigma_unc = sigma_unc * 1000.0
        sigma_plot = axis_sigma.errorbar(
            sigma_series["x_value"],
            sigma_ps,
            yerr=sigma_unc,
            fmt="-^",
            color="C1",
            label="σ_RPC",
            capsize=error_capsize,
        )
        line_sigma = sigma_plot.lines[0]
        axis_sigma.set_ylabel("σ_RPC (ps)", color="C1")
        axis_sigma.spines["right"].set_color("C1")
        axis_sigma.tick_params(axis="y", colors="C1")
        lines.append(line_sigma)
        labels.append("σ_RPC")
    else:
        axis_sigma.set_ylabel("σ_RPC (ps)", color="C1")

    axis_streamer.set_xlabel(x_label)
    axis_streamer.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
    axis_streamer.set_title(f"{thick_detector}: Streamer %, Eff good, σ_RPC vs {x_label}")

    if lines:
        axis_streamer.legend(lines, labels, loc="upper left")

    axis_streamer.set_ylim(0, 100)
    axis_eff.set_ylim(0, 100)
    axis_sigma.set_ylim(50, 200)

    fig.tight_layout()
    save_figure(fig, "thick_rpc_summary")
    plt.close(fig)
    return True


def plot_efficiency_grid(
    table_frame: pd.DataFrame,
    detectors: list[str],
    save_figure: SaveFigure,
    hv_map: dict[int, float],
    vs_hv: bool,
    x_label: str,
    run_positions: dict[int, int] | None = None,
) -> bool:
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
        return False

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
        det_data = (
            table_frame.loc[table_frame["Detector"] == detector]
            .pipe(lambda df: _append_x_values(df, hv_map, vs_hv, run_positions))
            .dropna(subset=["x_value"])
            .sort_values("x_value")
        )
        for col_idx, (metric, metric_unc) in enumerate(available_metrics):
            axis = axes_matrix[row_idx, col_idx]
            values = det_data[["run", "x_value", metric]].dropna(subset=[metric, "x_value"])
            if values.empty:
                axis.set_visible(False)
                continue
            runs = values["run"].to_numpy()
            x_points = values["x_value"].to_numpy()
            measurement = values[metric].to_numpy()
            yerr = None
            if metric_unc in det_data.columns:
                unc_values = det_data[["run", metric_unc]].dropna()
                if not unc_values.empty:
                    yerr = unc_values.set_index("run").reindex(runs)[metric_unc].to_numpy()
            axis.errorbar(
                x_points,
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
            xticks = _unique_xticks(values["x_value"])
            _set_run_xticks(axis, xticks, run_positions)
            axis.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
            if row_idx == nrows - 1:
                axis.set_xlabel(x_label)

    fig.suptitle(f"Detector efficiencies vs {x_label} with uncertainties", y=0.995)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    save_figure(fig, "efficiency_grid")
    plt.close(fig)
    return True


def plot_streamer_and_charges(
    table_frame: pd.DataFrame,
    detectors: list[str],
    save_figure: SaveFigure,
    hv_map: dict[int, float],
    vs_hv: bool,
    x_label: str,
    run_positions: dict[int, int] | None = None,
) -> bool:
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
            .pipe(lambda df: _append_x_values(df, hv_map, vs_hv, run_positions))
            .dropna(subset=["x_value"])
            .sort_values("x_value")
        )

        xticks = _unique_xticks(det_data["x_value"])

        stream_series = (
            det_data.loc[:, ["x_value", "StreamerPct"]]
            .dropna(subset=["StreamerPct"])
            .sort_values("x_value")
        )
        if not stream_series.empty:
            axis_stream.plot(stream_series["x_value"], stream_series["StreamerPct"], "-o", color="C3")
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
        _set_run_xticks(axis_stream, xticks, run_positions)
        axis_stream.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
        if row_idx == nrows - 1:
            axis_stream.set_xlabel(x_label)

        plotted = False
        for idx, metric in enumerate(charge_metrics):
            if metric not in det_data.columns:
                continue
            metric_series = (
                det_data.loc[:, ["x_value", metric]]
                .dropna(subset=[metric])
                .sort_values("x_value")
            )
            if metric_series.empty:
                continue
            axis_charge.plot(
                metric_series["x_value"],
                metric_series[metric],
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
        _set_run_xticks(axis_charge, xticks, run_positions)
        axis_charge.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)
        if row_idx == nrows - 1:
            axis_charge.set_xlabel(x_label)

    axes_matrix[0, 0].set_title(f"StreamerPct vs {x_label}")
    axes_matrix[0, 1].set_title(f"Charge metrics vs {x_label}")

    fig.suptitle(f"Additional run metrics per detector (vs {x_label})", y=0.995)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    save_figure(fig, "streamer_and_charges")
    plt.close(fig)
    return True


def plot_time_resolutions(
    table_frame: pd.DataFrame,
    save_figure: SaveFigure,
    hv_map: dict[int, float],
    vs_hv: bool,
    x_label: str,
    run_positions: dict[int, int] | None = None,
) -> bool:
    required = {"time_res_RPC", "time_res_SC"}
    missing = [col for col in required if col not in table_frame.columns]
    if missing:
        print(
            f"Time resolution column(s) missing; skipping time resolution plots: {', '.join(missing)}"
        )
        return False

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
        rpc_grouped["x_value"] = rpc_grouped["run"].apply(lambda r: _hv_for_run(r, hv_map, vs_hv, run_positions))
        rpc_grouped = rpc_grouped.dropna(subset=["x_value"]).sort_values("x_value")
        runs = rpc_grouped["x_value"].to_numpy()
        rpc_values_ps = rpc_grouped["time_res_RPC"].to_numpy() * 1000.0
        rpc_axis.plot(
            runs,
            rpc_values_ps,
            "-o",
            color="C4",
        )
        xticks = _unique_xticks(rpc_grouped["x_value"])
        _set_run_xticks(rpc_axis, xticks, run_positions)
    rpc_axis.set_xlabel(x_label)
    rpc_axis.set_ylabel("σ_RPC (ps)")
    rpc_axis.set_title(f"sigma_RPC vs {x_label}")
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
        sc_grouped["x_value"] = sc_grouped["run"].apply(lambda r: _hv_for_run(r, hv_map, vs_hv, run_positions))
        sc_grouped = sc_grouped.dropna(subset=["x_value"]).sort_values("x_value")
        runs = sc_grouped["x_value"].to_numpy()
        sc_values_ps = sc_grouped["time_res_SC"].to_numpy() * 1000.0
        sc_axis.plot(
            runs,
            sc_values_ps,
            "-o",
            color="C5",
        )
        xticks = _unique_xticks(sc_grouped["x_value"])
        _set_run_xticks(sc_axis, xticks, run_positions)
    sc_axis.set_xlabel(x_label)
    sc_axis.set_ylabel("σ_SC (ps)")
    sc_axis.set_title(f"sigma_SC vs {x_label}")
    sc_axis.grid(True, linestyle="--", linewidth=0.5, alpha=0.4)

    fig.suptitle(f"Time resolution vs {x_label}", y=0.995)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    save_figure(fig, "time_resolutions")
    plt.close(fig)
    return True


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
    save_figure: SaveFigure,
    hv_map: dict[int, float],
    vs_hv: bool,
    x_label: str,
    strip_type: str = "thick",
    run_positions: dict[int, int] | None = None,
) -> bool:
    if hist_frame.empty:
        print("No charge histogram data available; skipping charge heatmap.")
        return False

    working = hist_frame
    if "strip_type" in hist_frame.columns:
        working = hist_frame.loc[hist_frame["strip_type"] == strip_type]
    if working.empty:
        print(f"No charge histogram data for {strip_type}; skipping heatmap.")
        return False
    working = _append_x_values(working, hv_map, vs_hv, run_positions).dropna(subset=["x_value"])

    pivot = (
        working.pivot_table(
            index="Charge_bin_center",
            columns="x_value",
            values="Count",
            aggfunc="sum",
        )
        .sort_index()
        .sort_index(axis=1)
    )
    if pivot.empty:
        print("Charge histogram pivot is empty; skipping charge heatmap.")
        return False

    runs = pivot.columns.to_numpy(dtype=float)
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
        return False

    fig, ax = plt.subplots(figsize=(8, 6))
    mesh = ax.pcolormesh(
        runs,
        bin_centers,
        counts,
        shading="nearest",
        cmap="viridis",
        edgecolors="none",
        linewidth=0.0,
        antialiased=False,
        rasterized=True,
    )
    cbar = fig.colorbar(mesh, ax=ax, pad=0.02)
    cbar.set_label("Normalized bin occupancy")

    ax.set_xlabel(x_label)
    ax.set_ylabel("Charge bin center (ADC bins)")
    strip_title = {
        "thick": "Thick strip",
        "thin_top": "Thin strip (top)",
        "thin_bottom": "Thin strip (bottom)",
    }.get(strip_type, strip_type)
    ax.set_title(f"{strip_title} charge histogram across {x_label}")
    _set_run_xticks(ax, runs.tolist(), run_positions)
    ax.set_ylim(bin_edges[0], bin_edges[-1])
    ax.grid(False)

    fig.tight_layout()
    save_figure(fig, "charge_heatmap")
    plt.close(fig)
    return True


def export_thick_summary_data(
    table_frame: pd.DataFrame,
    detectors: list[str],
    hv_map: dict[int, float],
    vs_hv: bool,
    x_label: str,
    destination: Path = SUMMARY_CSV_PATH,
    run_times: dict[int, tuple[str | None, str | None]] | None = None,
    run_positions: dict[int, int] | None = None,
) -> pd.DataFrame | None:
    thick_detector = next((det for det in detectors if "thick" in det.lower()), None)
    if thick_detector is None:
        print("No thick RPC detector found; skipping summary CSV export.")
        return None
    required_columns = {"StreamerPct", "good", "time_res_RPC"}
    missing = [col for col in required_columns if col not in table_frame.columns]
    if missing:
        print(
            "Missing column(s) for thick RPC summary CSV; "
            f"skipping export: {', '.join(missing)}"
        )
        return None

    det_data = (
        table_frame.loc[table_frame["Detector"] == thick_detector]
        .dropna(subset=["run"])
        .pipe(lambda df: _append_x_values(df, hv_map, vs_hv, run_positions))
        .dropna(subset=["x_value"])
    )
    if det_data.empty:
        print("No data available for thick detector; skipping summary CSV export.")
        return None

    det_data = det_data.sort_values("x_value").copy()
    det_data["hv_value"] = det_data["run"].apply(
        lambda r: hv_map.get(int(r), None) if pd.notna(r) else None
    )

    # add run start/end columns from run_times mapping (if available)
    if run_times:
        det_data["run_start"] = det_data["run"].apply(
            lambda r: run_times.get(int(r), (None, None))[0] if pd.notna(r) else None
        )
        det_data["run_end"] = det_data["run"].apply(
            lambda r: run_times.get(int(r), (None, None))[1] if pd.notna(r) else None
        )
    else:
        det_data["run_start"] = None
        det_data["run_end"] = None

    # Pull thin strip charge metrics for top/bottom (Mean/Median/Max)
    def _charge_map(detector_name: str, column: str) -> dict[int, float]:
        if detector_name not in table_frame["Detector"].unique():
            return {}
        subset = table_frame.loc[
            (table_frame["Detector"] == detector_name) & table_frame["run"].notna(),
            ["run", column],
        ].dropna()
        if subset.empty:
            return {}
        return subset.set_index("run")[column].to_dict()

    thin_top = next((det for det in detectors if "thin" in det.lower() and "top" in det.lower()), None)
    thin_bot = next((det for det in detectors if "thin" in det.lower() and "bot" in det.lower()), None)
    thin_charge_cols = ["MeanCharge", "MedianCharge", "MaxCharge"]
    thin_maps: dict[str, dict[int, float]] = {}
    for det_name, label in ((thin_top, "top"), (thin_bot, "bot")):
        if det_name is None:
            continue
        for col in thin_charge_cols:
            map_key = f"{col}_thin_{label}"
            thin_maps[map_key] = _charge_map(det_name, col)

    for col in thin_charge_cols:
        col_top = f"{col}_thin_top"
        col_bot = f"{col}_thin_bot"
        det_data[col_top] = det_data["run"].apply(lambda r: thin_maps.get(col_top, {}).get(r))
        det_data[col_bot] = det_data["run"].apply(lambda r: thin_maps.get(col_bot, {}).get(r))

    columns_to_keep = [
        "run",
        "run_start",
        "run_end",
        "hv_value",
        "StreamerPct",
        "MeanCharge",
        "MedianCharge",
        "MaxCharge",
        "MeanCharge_thin_top",
        "MedianCharge_thin_top",
        "MaxCharge_thin_top",
        "MeanCharge_thin_bot",
        "MedianCharge_thin_bot",
        "MaxCharge_thin_bot",
        "good",
        "good_unc",
        "time_res_RPC",
    ]
    missing_cols = [col for col in columns_to_keep if col not in det_data.columns]
    for col in missing_cols:
        det_data[col] = None

    destination.parent.mkdir(parents=True, exist_ok=True)
    export_frame = det_data.loc[:, columns_to_keep].copy()
    export_frame.to_csv(destination, index=False)
    print(f"[INFO] Thick RPC summary data exported to {destination}")
    return export_frame


def _build_detector_summary(
    table_frame: pd.DataFrame,
    detector_name: str,
    hv_map: dict[int, float],
    vs_hv: bool,
    run_times: dict[int, tuple[str | None, str | None]] | None = None,
    run_positions: dict[int, int] | None = None,
) -> pd.DataFrame:
    if detector_name not in table_frame["Detector"].unique():
        return pd.DataFrame()
    det_data = (
        table_frame.loc[table_frame["Detector"] == detector_name]
        .dropna(subset=["run"])
        .pipe(lambda df: _append_x_values(df, hv_map, vs_hv, run_positions))
        .dropna(subset=["x_value"])
    )
    if det_data.empty:
        return pd.DataFrame()
    det_data = det_data.sort_values("x_value").copy()
    det_data["hv_value"] = det_data["run"].apply(
        lambda r: hv_map.get(int(r), None) if pd.notna(r) else None
    )
    if run_times:
        det_data["run_start"] = det_data["run"].apply(
            lambda r: run_times.get(int(r), (None, None))[0] if pd.notna(r) else None
        )
        det_data["run_end"] = det_data["run"].apply(
            lambda r: run_times.get(int(r), (None, None))[1] if pd.notna(r) else None
        )
    else:
        det_data["run_start"] = None
        det_data["run_end"] = None

    columns_to_keep = [
        "run",
        "run_start",
        "run_end",
        "hv_value",
        "StreamerPct",
        "MeanCharge",
        "MedianCharge",
        "MaxCharge",
        "good",
        "good_unc",
        "time_res_RPC",
    ]
    missing_cols = [col for col in columns_to_keep if col not in det_data.columns]
    for col in missing_cols:
        det_data[col] = None
    return det_data.loc[:, columns_to_keep].copy()


def plot_summary_table(
    summary_frame: pd.DataFrame,
    save_figure: SaveFigure,
    title: str,
    include_thin_charges: bool = True,
) -> bool:
    if summary_frame is None or summary_frame.empty:
        print(f"{title} table is empty; skipping table page.")
        return False

    display_cols = [
        "run",
        "hv_value",
        "StreamerPct",
        "MeanCharge",
        "MedianCharge",
        "MaxCharge",
        "good",
        "good_unc",
        "time_res_RPC",
        "run_start",
        "run_end",
    ]
    if include_thin_charges:
        display_cols = [
            *display_cols[:6],
            "MeanCharge_thin_top",
            "MedianCharge_thin_top",
            "MaxCharge_thin_top",
            "MeanCharge_thin_bot",
            "MedianCharge_thin_bot",
            "MaxCharge_thin_bot",
            *display_cols[6:],
        ]
    available_cols = [col for col in display_cols if col in summary_frame.columns]
    table_data = summary_frame.loc[:, available_cols].copy()

    fmt_cols = {
        "hv_value": "{:.0f}",
        "StreamerPct": "{:.1f}",
        "MeanCharge": "{:.1f}",
        "MedianCharge": "{:.1f}",
        "MaxCharge": "{:.1f}",
        "good": "{:.1f}",
        "good_unc": "{:.1f}",
        "time_res_RPC": "{:.1f}",
    }
    for col, fmt in fmt_cols.items():
        if col in table_data.columns:
            table_data[col] = table_data[col].apply(
                lambda v: fmt.format(v) if pd.notna(v) else ""
            )
    def _short_ts(value: str) -> str:
        text = str(value) if pd.notna(value) else ""
        if not text:
            return ""
        if " " in text:
            date_part, *rest = text.split(" ")
            time_part = rest[0] if rest else ""
            time_part = time_part[:5]  # HH:MM
            return f"{date_part}\n{time_part}"
        return text

    for col in ("run_start", "run_end"):
        if col in table_data.columns:
            table_data[col] = table_data[col].apply(_short_ts)

    cell_text = table_data.values.tolist()
    col_labels = [col.replace("_", " ") for col in table_data.columns]

    fig_height = max(3.5, 1.0 + 0.35 * len(cell_text))
    fig, ax = plt.subplots(figsize=(11, fig_height))
    ax.axis("off")
    col_widths = None
    if table_data.columns.tolist().count("run_start") == 1 and table_data.columns.tolist().count("run_end") == 1:
        col_widths = [0.08] * len(col_labels)
        for idx, label in enumerate(col_labels):
            if label in {"run start", "run end"}:
                col_widths[idx] = 0.12
    tbl = ax.table(
        cellText=cell_text,
        colLabels=col_labels,
        loc="center",
        cellLoc="center",
        colWidths=col_widths,
    )
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(7)
    for (row_idx, _col_idx), cell in tbl.get_celld().items():
        if row_idx == 0:
            cell.set_fontsize(6)
    tbl.scale(1.0, 1.3)

    ax.set_title(title, fontsize=14, pad=14)
    fig.tight_layout()
    save_figure(fig, title.lower().replace(" ", "_"))
    plt.close(fig)
    return True


def main() -> None:
    args = parse_args()
    run_files = find_latest_run_files(args.directory)
    if args.runs:
        requested = {int(run) for run in args.runs}
        available = {item.run for item in run_files}
        missing = sorted(requested - available)
        if missing:
            missing_str = ", ".join(str(run) for run in missing)
            raise FileNotFoundError(f"Requested run(s) not found: {missing_str}")
        run_files = [item for item in run_files if item.run in requested]
    if not run_files:
        raise FileNotFoundError("No run files available after applying filters.")
    print("Selected files:")
    for item in run_files:
        print(f"  Run {item.run}: {item.path.name} (exec {item.exec_time.isoformat(sep=' ')})")
    run_ids_set = {item.run for item in run_files}
    run_positions = {run: idx + 1 for idx, run in enumerate(sorted(run_ids_set))}
    hv_map: dict[int, float] = _load_hv_map(RUN_DICT_PATH, run_ids_set)
    # load run start/end times from run dictionary
    run_times = _load_run_times(RUN_DICT_PATH, run_ids_set)
    vs_hv = args.vs_hv and bool(hv_map)
    if args.vs_hv and not hv_map:
        print("[WARN] --vs-hv requested but no HV metadata found; using run ids instead.")
    if vs_hv:
        missing_hv = sorted(run_ids_set - set(hv_map))
        if missing_hv:
            missing_str = ", ".join(str(r) for r in missing_hv)
            print(f"[INFO] HV missing for run(s): {missing_str}. Using run id on X axis for those points.")
    x_label = "HV (V)" if vs_hv else "Run"
    table_frame, metadata_frame = load_run_tables(run_files)
    filtered_table, detectors = _filter_detectors(table_frame, args.detectors)
    charge_hist_frame = load_charge_histograms(run_files)
    summary_frame = export_thick_summary_data(
        filtered_table,
        detectors,
        hv_map,
        vs_hv,
        x_label,
        SUMMARY_CSV_PATH,
        run_times,
        run_positions,
    )
    if summary_frame is None:
        summary_frame = pd.DataFrame()
    thin_top_detector = next((d for d in detectors if "thin" in d.lower() and "top" in d.lower()), None)
    thin_bot_detector = next((d for d in detectors if "thin" in d.lower() and "bot" in d.lower()), None)
    thin_top_summary = _build_detector_summary(filtered_table, thin_top_detector, hv_map, vs_hv, run_times, run_positions) if thin_top_detector else pd.DataFrame()
    thin_bot_summary = _build_detector_summary(filtered_table, thin_bot_detector, hv_map, vs_hv, run_times, run_positions) if thin_bot_detector else pd.DataFrame()

    if not metadata_frame.empty:
        print("\nRun metadata:")
        meta_to_show = metadata_frame.copy()
        meta_to_show["exec_time"] = meta_to_show["exec_time"].dt.strftime("%Y-%m-%d %H:%M:%S")
        formatted = meta_to_show.set_index("run").apply(
            lambda col: col.map(lambda v: f"{v:.4g}" if isinstance(v, float) else v)
        )
        print(formatted.to_string())
    datasets = {
        "filtered": filtered_table,
        "full": table_frame,
        "charge": charge_hist_frame,
        "summary_table": summary_frame,
        "summary_top": thin_top_summary,
        "summary_bot": thin_bot_summary,
    }
    plot_specs: list[
        tuple[str, str, Callable[[pd.DataFrame, SaveFigure], bool]]
    ] = [
        (
            "thick RPC summary",
            "filtered",
            lambda frame, saver: plot_thick_rpc_summary(frame, detectors, saver, hv_map, vs_hv, x_label, run_positions),
        ),
        (
            "charge heatmap",
            "charge",
            lambda frame, saver: plot_charge_heatmap(frame, saver, hv_map, vs_hv, x_label, "thick", run_positions),
        ),
        (
            "thin top charge heatmap",
            "charge",
            lambda frame, saver: plot_charge_heatmap(frame, saver, hv_map, vs_hv, x_label, "thin_top", run_positions),
        ),
        (
            "thin bottom charge heatmap",
            "charge",
            lambda frame, saver: plot_charge_heatmap(frame, saver, hv_map, vs_hv, x_label, "thin_bottom", run_positions),
        ),
        (
            "thick summary table",
            "summary_table",
            lambda frame, saver: plot_summary_table(frame, saver, "Thick RPC summary table", include_thin_charges=False),
        ),
        (
            "thin top summary table",
            "summary_top",
            lambda frame, saver: plot_summary_table(frame, saver, "Thin top summary table"),
        ),
        (
            "thin bottom summary table",
            "summary_bot",
            lambda frame, saver: plot_summary_table(frame, saver, "Thin bottom summary table"),
        ),
        (
            "efficiency grid",
            "filtered",
            lambda frame, saver: plot_efficiency_grid(frame, detectors, saver, hv_map, vs_hv, x_label, run_positions),
        ),
        (
            "streamer and charges",
            "filtered",
            lambda frame, saver: plot_streamer_and_charges(frame, detectors, saver, hv_map, vs_hv, x_label, run_positions),
        ),
        (
            "time resolutions",
            "full",
            lambda frame, saver: plot_time_resolutions(frame, saver, hv_map, vs_hv, x_label, run_positions),
        ),
    ]

    if args.png_only:
        run_ids = sorted(
            table_frame["run"].dropna().astype(int).unique().tolist()
        )
        if not run_ids:
            print("No runs with data are available for PNG export.")
            return
        print(
            f"\nPNG-only mode: figures will be written per run to "
            f"{', '.join(str(path) for path in PNG_OUTPUT_DIRS)}"
        )
        total_figures = 0
        for run_id in run_ids:
            run_datasets = {
                key: _subset_frame_by_run(frame, run_id)
                for key, frame in datasets.items()
            }
            saver = FigureSaver(png_dirs=_png_dirs_for_run(run_id))
            save_fn = saver.for_run(run_id)
            saved_this_run = 0
            for name, dataset_key, plotter in plot_specs:
                saved = plotter(run_datasets[dataset_key], save_fn)
                if saved:
                    saved_this_run += 1
            if saved_this_run:
                total_figures += saved_this_run
                print(
                    f"  Run {run_id}: saved {saved_this_run} PNG figure(s)."
                )
            else:
                print(f"  Run {run_id}: no figures were saved (all sections skipped).")
        if total_figures:
            print(
                f"\nPNG export complete: {total_figures} figure(s) saved per output directory."
            )
        else:
            print("\nNo PNG figures were generated.")
        return

    if args.pdf_max_pages is not None:
        pdf_limit = max(0, int(args.pdf_max_pages))
    elif args.full_pdf:
        pdf_limit = None
    elif args.simple_pdf:
        pdf_limit = DEFAULT_RUN_TABLE_SIMPLE_PAGES
    else:
        pdf_limit = None
    if pdf_limit == 0:
        print("PDF max pages set to 0; skipping summary plot export.")
        return
    args.output.parent.mkdir(parents=True, exist_ok=True)
    pages_written = 0
    limit_hit = False
    with PdfPages(args.output) as pdf:
        saver = FigureSaver(pdf=pdf)
        save_fn = saver.for_run(None)
        for name, dataset_key, plotter in plot_specs:
            if pdf_limit is not None and pages_written >= pdf_limit:
                limit_hit = True
                break
            saved = plotter(datasets[dataset_key], save_fn)
            if saved:
                pages_written += 1
    if pages_written:
        print(f"\nSaved {pages_written} figure(s) to {args.output}")
    else:
        print("\nNo figures were written to the PDF (all sections skipped).")
    if limit_hit:
        limit_msg = (
            "--full-pdf"
            if args.pdf_max_pages is None
            else f"a larger --pdf-max-pages value (> {pdf_limit})"
        )
        print(
            f"PDF limited to {pdf_limit} page(s); rerun with {limit_msg} to include the remaining sections."
        )


if __name__ == "__main__":
    main()
