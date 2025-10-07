#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Aggregate and join log files stored in LOG_FILES/DATA.

The script expects cleaned log files under LOG_FILES/DATA/CLEAN (as produced by
``log_bring_and_clear.sh``) and will:
  • move cleaned files to an UNPROCESSED staging area
  • aggregate each prefix into a single CSV in ACCUMULATED
  • merge all aggregated CSVs into ``big_log_lab_data.csv``

If available, LOG_FILES/config.yaml can provide:
  outlier_limits:
    <column_name>: [min_value, max_value]
  create_new_csv: true
All keys are optional. ``outlier_limits`` defaults to an empty mapping.
"""

from __future__ import annotations

import string
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional

import numpy as np
import pandas as pd

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover - yaml is optional
    yaml = None

from status_csv import append_status_row, mark_status_complete

SCRIPTS_DIR = Path(__file__).resolve().parent
LOG_ROOT = SCRIPTS_DIR.parent
DATA_ROOT = LOG_ROOT / "DATA"
STATUS_DIR = DATA_ROOT / "STATUS"
CONFIG_PATH = LOG_ROOT / "config.yaml"


@dataclass(frozen=True)
class FileSchema:
    prefix: str
    output: str
    label: str
    columns: List[str]


FILE_SCHEMAS: List[FileSchema] = [
    FileSchema(
        prefix="hv4_",
        output="hv4_aggregated.csv",
        label="hv4",
        columns=[
            "Date",
            "Hour",
            "unknown_header_word0",
            "unknown_header_word1",
            "unknown_header_word2",
            "unknown_header_word3",
            "unknown_header_word4",
            "unknown_header_word5",
            "unknown_current_ch_a",
            "unknown_current_ch_b",
            "unknown_voltage_ch_a",
            "unknown_voltage_ch_b",
            "unknown_current_error_ch_a",
            "unknown_current_error_ch_b",
            "unknown_voltage_setpoint_ch_a",
            "unknown_voltage_setpoint_ch_b",
            "unknown_voltage_reference",
            "unknown_gain_factor",
            "unknown_status_flag1",
            "unknown_status_flag2",
            "unknown_status_flag3",
            "unknown_status_flag4",
            "unknown_status_flag5",
            "unknown_status_flag6",
            "unknown_status_flag7",
        ],
    ),
    FileSchema(
        prefix="hv5_",
        output="hv5_aggregated.csv",
        label="hv5",
        columns=[
            "Date",
            "Hour",
            "unknown_header_word0",
            "unknown_header_word1",
            "unknown_header_word2",
            "unknown_header_word3",
            "unknown_header_word4",
            "unknown_header_word5",
            "unknown_current_readback_1",
            "unknown_current_readback_2",
            "unknown_current_readback_3",
            "unknown_current_readback_4",
            "unknown_current_readback_5",
            "unknown_current_readback_6",
            "unknown_voltage_readback_1",
            "unknown_voltage_readback_2",
            "unknown_voltage_setpoint_1",
            "unknown_voltage_setpoint_2",
            "unknown_status_flag1",
            "unknown_status_flag2",
            "unknown_status_flag3",
            "unknown_status_flag4",
            "unknown_status_flag5",
            "unknown_status_flag6",
        ],
    ),
    FileSchema(
        prefix="rates_",
        output="rates_aggregated.csv",
        label="rates",
        columns=[
            "Date",
            "Hour",
        ]
        + [f"unknown_rate_counter{i:02d}" for i in range(1, 28)],
    ),
    FileSchema(
        prefix="sensors_bus0_",
        output="sensors_bus0_aggregated.csv",
        label="sensors",
        columns=[
            "Date",
            "Hour",
            "unknown_bus0_field1",
            "unknown_bus0_field2",
            "temperature_c",
            "humidity_percent",
            "pressure_hpa",
        ],
    ),
]


def load_config() -> Dict[str, object]:
    """Load optional configuration from LOG_FILES/config.yaml."""
    if not CONFIG_PATH.exists() or yaml is None:
        if CONFIG_PATH.exists() and yaml is None:
            print(f"Warning: PyYAML not available; ignoring {CONFIG_PATH}")
        return {}

    with CONFIG_PATH.open("r", encoding="utf-8") as config_file:
        loaded = yaml.safe_load(config_file) or {}
        if isinstance(loaded, dict):
            return loaded
        print(f"Warning: config at {CONFIG_PATH} is not a mapping; ignoring.")
        return {}


def ensure_directories(paths: Iterable[Path]) -> None:
    for path in paths:
        path.mkdir(parents=True, exist_ok=True)


def _looks_like_hex(value: str) -> bool:
    stripped = value.strip().lower()
    if not stripped:
        return False
    if stripped.startswith("0x"):
        stripped = stripped[2:]
    return bool(stripped) and all(ch in set(string.hexdigits.lower()) for ch in stripped)


def _normalize_value(value):
    if isinstance(value, (int, float)):
        return value
    if value is None:
        return np.nan
    text = str(value).strip()
    if not text:
        return np.nan
    lowered = text.lower()
    if lowered in {"nan", "none"}:
        return np.nan
    if lowered.startswith("0x") or (_looks_like_hex(text) and any(c.isalpha() for c in text)):
        try:
            return int(lowered, 16)
        except ValueError:
            return np.nan
    try:
        return float(text)
    except ValueError:
        return text


def process_files(schema: FileSchema, output_path: Path, source_dir: Path) -> bool:
    """Aggregate all files with ``schema.prefix`` from ``source_dir`` into ``output_path``."""
    candidate_files = sorted(
        p
        for p in source_dir.glob(f"{schema.prefix}*")
        if p.is_file() and not p.name.startswith(".")
    )

    if not candidate_files:
        return False

    dataframes: List[pd.DataFrame] = []

    for file_path in candidate_files:
        try:
            df = pd.read_csv(file_path, sep=r"\s+", header=None, on_bad_lines="skip")
        except Exception as exc:
            print(f"Error reading {file_path}: {exc}")
            continue

        expected_columns = schema.columns

        if len(df.columns) > len(expected_columns):
            df = df.iloc[:, : len(expected_columns)]
        elif len(df.columns) < len(expected_columns):
            for _ in range(len(expected_columns) - len(df.columns)):
                df[len(df.columns)] = None

        df.columns = expected_columns

        if "Date" in df.columns and "Hour" in df.columns:
            df["Time"] = pd.to_datetime(df["Date"] + "T" + df["Hour"], errors="coerce")
            df.drop(columns=["Hour", "Date"], inplace=True)
            df = df.dropna(subset=["Time"])

        for column in df.columns:
            if column == "Time":
                continue
            df[column] = df[column].apply(_normalize_value)

        dataframes.append(df)

    if not dataframes:
        return False

    combined_df = pd.concat(dataframes, ignore_index=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    combined_df.to_csv(output_path, index=False)
    print(f"Aggregated CSV saved: {output_path}")
    return True


def process_csv(file_path: Path) -> pd.DataFrame:
    """Load a previously aggregated CSV and return it indexed by Time."""
    if not file_path.exists():
        print(f"Skipping missing aggregated file: {file_path}")
        return pd.DataFrame()

    try:
        df = pd.read_csv(file_path)
    except Exception as exc:
        print(f"Could not read {file_path}: {exc}")
        return pd.DataFrame()

    if "Time" not in df.columns:
        print(f"Column 'Time' missing in {file_path}; skipping.")
        return pd.DataFrame()

    df["Time"] = pd.to_datetime(df["Time"], errors="coerce")
    df = df.dropna(subset=["Time"])
    if df.empty:
        return pd.DataFrame()

    df.set_index("Time", inplace=True)
    numeric_columns = df.select_dtypes(include=["number"]).columns
    df = df[numeric_columns].sort_index()
    if not df.index.is_unique:
        df = df.groupby(level=0).mean()
    return df


def merge_dataframes(
    file_mappings: Dict[str, Path],
    outlier_limits: Dict[str, Iterable[float]],
    start_time: Optional[pd.Timestamp] = None,
) -> pd.DataFrame:
    dataframes: List[pd.DataFrame] = []

    for name, path in file_mappings.items():
        df = process_csv(path)
        if df.empty:
            continue

        if start_time is not None:
            df = df[df.index > start_time]

        df.columns = [f"{name}_{col}" for col in df.columns]

        for column, limits in outlier_limits.items():
            if column not in df.columns:
                continue
            if isinstance(limits, (list, tuple)) and len(limits) == 2:
                lower, upper = limits
                df[column] = df[column].where(
                    (df[column] >= lower) & (df[column] <= upper), np.nan
                )

        dataframes.append(df)

    if not dataframes:
        return pd.DataFrame()

    merged_df = pd.concat(dataframes, axis=1)
    merged_df = merged_df.sort_index()

    if not merged_df.index.is_unique:
        merged_df = merged_df.groupby(level=0).mean()

    return merged_df


def main(argv: List[str]) -> int:
    if len(argv) > 1:
        print("Info: station argument ignored; single-host layout in use.")

    clean_logs_directory = DATA_ROOT / "CLEAN"
    unprocessed_logs_directory = DATA_ROOT / "UNPROCESSED"
    accumulated_directory = DATA_ROOT / "ACCUMULATED"
    final_output_path = accumulated_directory / "big_log_lab_data.csv"
    status_csv_path = STATUS_DIR / "log_aggregate_and_join.csv"

    ensure_directories(
        [clean_logs_directory, unprocessed_logs_directory, accumulated_directory, status_csv_path.parent]
    )

    status_timestamp = append_status_row(status_csv_path)
    success = False

    try:
        files_to_move = [
            p for p in clean_logs_directory.glob("*") if p.is_file() and not p.name.startswith(".")
        ]
        print(f"Files to move: {len(files_to_move)}")

        for src_path in files_to_move:
            dest_path = unprocessed_logs_directory / src_path.name
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                dest_path.unlink(missing_ok=True)
            except AttributeError:
                if dest_path.exists():
                    dest_path.unlink()
            try:
                src_path.replace(dest_path)
            except Exception as exc:
                print(f"Failed to move {src_path.name}: {exc}")

        config = load_config()
        outlier_limits = config.get("outlier_limits", {}) if isinstance(config, dict) else {}
        create_new_csv = bool(config.get("create_new_csv", True)) if isinstance(config, dict) else True

        print("Processing files...")

        produced_paths: Dict[str, Path] = {}
        for schema in FILE_SCHEMAS:
            output_path = accumulated_directory / schema.output
            produced = process_files(schema, output_path, unprocessed_logs_directory)
            if produced:
                produced_paths[schema.label] = output_path

        print("All files processed...")

        if not produced_paths:
            print("No aggregated files were generated. Skipping merge.")
            success = True
            return 0

        merged_df = merge_dataframes(produced_paths, outlier_limits)

        if merged_df.empty:
            print("No data available after aggregation. Skipping final CSV generation.")
            success = True
            return 0

        merged_df = merged_df.resample("1min").mean()
        merged_df.reset_index(inplace=True)

        if final_output_path.exists() and create_new_csv:
            final_output_path.unlink()
            print(f"Removed existing {final_output_path}")

        merged_df.to_csv(final_output_path, index=False, float_format="%.5g")
        print(f"Updated merged data saved to {final_output_path}")

        success = True
        return 0

    except Exception as exc:
        print(f"Unexpected error while aggregating logs: {exc}")
        return 1

    finally:
        if success:
            mark_status_complete(status_csv_path, status_timestamp)


if __name__ == "__main__":
    import sys

    sys.exit(main(sys.argv))
