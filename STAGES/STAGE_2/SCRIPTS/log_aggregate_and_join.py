#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Aggregate and join log files stored in STAGES/STAGE_2/DATA.

The script expects cleaned log files under STAGES/STAGE_2/DATA/DATA_FILES/CLEAN (as produced by
``log_bring_and_clean.sh``) and will:
  • move cleaned files to an UNPROCESSED staging area
  • aggregate each prefix into a single CSV in ACCUMULATED
  • merge all aggregated CSVs into ``big_log_lab_data.csv``

If available, STAGES/STAGE_2/CONFIGS/config.yaml can provide:
  outlier_limits:
    <column_name>: [min_value, max_value]
  create_new_csv: true
All keys are optional. ``outlier_limits`` defaults to an empty mapping.
"""

from __future__ import annotations

import csv
import os
import string
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set

import numpy as np
import pandas as pd

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover - yaml is optional
    yaml = None

from status_csv import append_status_row, mark_status_complete

SCRIPTS_DIR = Path(__file__).resolve().parent
STAGE_ROOT = SCRIPTS_DIR.parent
DATA_ROOT = STAGE_ROOT / "DATA"
DATA_FILES_ROOT = DATA_ROOT / "DATA_FILES"
STATUS_DIR = DATA_FILES_ROOT / "STATUS"
CONFIG_PATH = STAGE_ROOT / "CONFIGS" / "config.yaml"


@dataclass(frozen=True)
class FileSchema:
    prefix: str
    output: str
    label: str
    columns: List[str]


# Pre cleaning, example lines:
# mingo 2025-08-17T00:00:03 80 1F 12 59 F5 21 0.140 0.132 5.440 5.410 0.000 1.250 5.422 1.008 5.420 1.000 1 1 0 0 1 1 1 
# joaos 2025-06-29T00:00:01 80 1F 12 5A 12 DA 0.002 0.000 0.000 0.000 0.000 0.366 0.000 0.000 0.000 0.000 0 0 0 0 0 0 1 
# Post cleaning, example lines:
# mingo 
# joaos     
# Columns in the mingo scripts:
# ["Date", "Hour", "Unused1", "Unused2", "Unused3", "Unused4", "Unused5", "Unused6",
#    "CurrentNeg", "CurrentPos", "HVneg", "HVpos", "Unused7", "Unused8", "Unused9",
#    "Unused10", "Unused11", "Unused12", "Unused13", "Unused14", "Unused15"]
# Columns in the joaos scripts:
# The same, literally.

FILE_SCHEMAS: List[FileSchema] = [
    FileSchema(
        prefix="hv4_",
        output="hv4_aggregated.csv",
        label="hv4",
        columns=["Date", "Hour", "Unused1", "Unused2", "Unused3", "Unused4", "Unused5", "Unused6",
                    "CurrentNeg", "CurrentPos", "HVneg", "HVpos", "Unused7", "Unused8", "Unused9",
                    "Unused10", "Unused11", "Unused12", "Unused13", "Unused14", "Unused15"],
    ),


    # Pre cleaning, example lines:
    # mingo 2025-08-17T00:00:03 80 1F 12 59 F5 21 0.140 0.132 5.440 5.410 0.000 1.250 5.422 1.008 5.420 1.000 1 1 0 0 1 1 1 
    # joaos 2025-06-29T00:00:01 80 1F 12 5A 12 DA 0.002 0.000 0.000 0.000 0.000 0.366 0.000 0.000 0.000 0.000 0 0 0 0 0 0 1 
    # Post cleaning, example lines:
    # mingo 
    # joaos     
    # Columns in the mingo scripts:
    # ["Date", "Hour", "Unused1", "Unused2", "Unused3", "Unused4", "Unused5", "Unused6",
    #    "CurrentNeg", "CurrentPos", "HVneg", "HVpos", "Unused7", "Unused8", "Unused9",
    #    "Unused10", "Unused11", "Unused12", "Unused13", "Unused14", "Unused15"]
    # Columns in the joaos scripts:
    # The same, literally.

    FileSchema(
        prefix="hv5_",
        output="hv5_aggregated.csv",
        label="hv5",
        columns=["Date", "Hour", "Unused1", "Unused2", "Unused3", "Unused4", "Unused5", "Unused6",
                    "CurrentNeg", "CurrentPos", "HVneg", "HVpos", "Unused7", "Unused8", "Unused9",
                    "Unused10", "Unused11", "Unused12", "Unused13", "Unused14", "Unused15"],
    ),
    # Pre cleaning, example lines:
    # mingo 2024-09-06T00:00:52; 21.1 17.7 17.7 66.3 81.5 65.3 68.9 11.2 7.4 10.5 7.8
    # joaos 2025-10-02T00:00:35; 0.3 0.3 0.3 0.3 0.4 0.0 0.0 0.0 198.7 0.1 0.4 0.4 0.0 0.0 0.0 0.0 0.3 0.3 0.4 0.3 0.5 -40558880.1 9792302.6 7564219.9 0.0 0.0 0.0
    # Post cleaning, example lines:
    
    # Columns in the mingo scripts:
    # ["Date", "Hour", "Asserted", "Edge", "Accepted", "Multiplexer1", "M2", "M3", "M4", "CM1", "CM2", "CM3", "CM4"]
    # Columns in the joaos scripts:
    # ["Date", "Hour", "Asserted", "Edge", "Accepted", 
    # "Multiplexer1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12", 
    # "CM1", "CM2", "CM3", "CM4", "CM5", "CM6", "CM7", "CM8", "CM9", "CM10", "CM11", "CM12"]

    FileSchema(
        prefix="rates_",
        output="rates_aggregated.csv",
        label="rates",
        columns=[
            "Date",
            "Hour",
            "Asserted",
            "Edge",
            "Accepted",
            "Multiplexer1",
            "M2",
            "M3",
            "M4",
            "M5",
            "M6",
            "M7",
            "M8",
            "M9",
            "M10",
            "M11",
            "M12",
            "CM1",
            "CM2",
            "CM3",
            "CM4",
            "CM5", "CM6",
            "CM7", "CM8",
            "CM9", "CM10",
            "CM11", "CM12",
        ],
    ),


    # Pre cleaning, example lines:
    # mingo 2025-10-08T00:00:05; nan nan nan nan 26.3 31.7 945.6
    # joaos 2025-10-08T00:00:04; nan nan 23.5 51.1 1010.4
    # Post cleaning, example lines:
    # mingo 
    # joaos 
    # Columns in the mingo scripts:
    # ["Date", "Hour", "Unused1", "Unused2", "Unused3", "Unused4", "Temperature_ext", "RH_ext", "Pressure_ext"]
    # Columns in the joaos scripts:
    # ["Date", "Hour", "Unused1", "Unused2", "Temperature_ext", "RH_ext", "Pressure_ext"]

    FileSchema(
        prefix="sensors_bus0_",
        output="sensors_bus0_aggregated.csv",
        label="sensors",
        columns=[
            "Date",
            "Hour",
            "Unused1",
            "Unused2",
            "Temperature_ext",
            "RH_ext",
            "Pressure_ext",
        ],
    ),
]


def get_last_timestamp(path: Path) -> Optional[pd.Timestamp]:
    """Return the last valid timestamp stored in a CSV file, scanning from the end."""
    if not path.exists():
        return None
    try:
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.reader(handle)
            header = next(reader, None)
    except Exception:
        return None

    if not header or "Time" not in header:
        return None

    time_idx = header.index("Time")

    def _tail_nonempty_line(file_path: Path, chunk_size: int = 8192) -> Optional[str]:
        try:
            with file_path.open("rb") as handle:
                file_size = handle.seek(0, os.SEEK_END)
                if file_size == 0:
                    return None

                buffer = b""
                position = file_size
                while position > 0:
                    read_size = min(chunk_size, position)
                    position -= read_size
                    handle.seek(position)
                    chunk = handle.read(read_size)
                    buffer = chunk + buffer
                    lines = buffer.split(b"\n")
                    buffer = lines[0]
                    for line in reversed(lines[1:]):
                        if line.strip():
                            return line.decode("utf-8", errors="ignore")

                if buffer.strip():
                    return buffer.decode("utf-8", errors="ignore")
        except Exception:
            return None
        return None

    last_line = _tail_nonempty_line(path)
    if not last_line:
        return None

    try:
        row = next(csv.reader([last_line]))
    except Exception:
        return None

    if len(row) <= time_idx:
        return None

    value = pd.to_datetime(row[time_idx], errors="coerce")
    if pd.isna(value):
        return None
    return value


def append_dataframe_to_csv(df: pd.DataFrame, path: Path) -> None:
    """Append DataFrame rows to CSV, writing header only when creating the file."""
    if df.empty:
        return
    mode = "a" if path.exists() else "w"
    header = not path.exists()
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, mode=mode, header=header, index=False, float_format="%.5g")


def load_config() -> Dict[str, object]:
    """Load optional configuration from STAGES/STAGE_2/CONFIGS/config.yaml."""
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


def process_files(
    schema: FileSchema,
    source_dir: Path,
    last_timestamp: Optional[pd.Timestamp] = None,
    archive_dir: Optional[Path] = None,
    allowed_files: Optional[Set[str]] = None,
) -> pd.DataFrame:
    """Aggregate new rows for ``schema`` from ``source_dir``.

    When ``allowed_files`` is provided, only those files are processed; any other
    file that already has an archived copy is moved aside without reprocessing.
    """
    candidate_files = sorted(
        p
        for p in source_dir.glob(f"{schema.prefix}*")
        if p.is_file() and not p.name.startswith(".")
    )

    if not candidate_files:
        print(f"[{schema.label}] No unprocessed files found in {source_dir}.")
        return pd.DataFrame()

    print(f"[{schema.label}] Processing {len(candidate_files)} file(s) from {source_dir} ...")

    if archive_dir is None:
        archive_dir = source_dir / "processed"
    archive_dir.mkdir(parents=True, exist_ok=True)

    dataframes: List[pd.DataFrame] = []
    processed_files: List[Path] = []
    skipped_existing: List[str] = []

    filtered_candidates: List[Path] = []
    for file_path in candidate_files:
        archive_path = archive_dir / file_path.name
        if allowed_files is not None and file_path.name not in allowed_files and archive_path.exists():
            try:
                archive_path.unlink()
            except FileNotFoundError:
                pass
            try:
                file_path.replace(archive_path)
                skipped_existing.append(file_path.name)
                continue
            except Exception as exc:
                print(f"[{schema.label}] Warning: failed to archive {file_path.name} without reprocessing: {exc}")
        filtered_candidates.append(file_path)

    candidate_files = filtered_candidates

    if skipped_existing:
        print(f"[{schema.label}] Skipped {len(skipped_existing)} already-processed file(s).")

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
        
        # Drop the "Unused" columns right away
        cols_to_drop = [col for col in df.columns 
                        if col.lower().startswith(('unused'))]
        if cols_to_drop:
            df.drop(columns=cols_to_drop, inplace=True)
            print(f"[{schema.label}] Dropped {len(cols_to_drop)} unused column(s): {cols_to_drop}")

        dataframes.append(df)
        processed_files.append(file_path)

    for processed in processed_files:
        try:
            destination = archive_dir / processed.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            processed.replace(destination)
        except Exception as exc:
            print(f"Warning: failed to archive {processed}: {exc}")

    if not dataframes:
        return pd.DataFrame()

    combined_df = pd.concat(dataframes, ignore_index=True)
    if "Time" in combined_df.columns and last_timestamp is not None:
        combined_df = combined_df[combined_df["Time"] > last_timestamp]
    if combined_df.empty:
        print(f"[{schema.label}] No new rows after filtering by timestamp.")
        return pd.DataFrame()

    combined_df = combined_df.sort_values("Time")
    
    # Drop columns that start with "Unused" or "unknown" (case-insensitive)
    cols_to_drop = [col for col in combined_df.columns if col.lower().startswith(('unused', 'unknown'))]
    if cols_to_drop:
        combined_df.drop(columns=cols_to_drop, inplace=True)
        print(f"[{schema.label}] Dropped {len(cols_to_drop)} unused column(s) after merge: {cols_to_drop}")

    print(f"[{schema.label}] Aggregated {len(combined_df)} new row(s).")
    return combined_df


def process_csv(file_path: Path, start_time: Optional[pd.Timestamp] = None) -> pd.DataFrame:
    """Load a previously aggregated CSV and return it indexed by Time."""
    if not file_path.exists():
        print(f"Skipping missing aggregated file: {file_path}")
        return pd.DataFrame()

    try:
        iterator = pd.read_csv(file_path, chunksize=100_000)
    except Exception as exc:
        print(f"Could not read {file_path}: {exc}")
        return pd.DataFrame()

    frames: List[pd.DataFrame] = []
    for chunk in iterator:
        if "Time" not in chunk.columns:
            print(f"Column 'Time' missing in {file_path}; skipping chunk.")
            continue

        cols_to_drop = [col for col in chunk.columns if col.lower().startswith(("unused", "unknown"))]
        if cols_to_drop:
            chunk = chunk.drop(columns=cols_to_drop)

        chunk["Time"] = pd.to_datetime(chunk["Time"], errors="coerce")
        chunk = chunk.dropna(subset=["Time"])
        if start_time is not None:
            chunk = chunk[chunk["Time"] > start_time]
        if chunk.empty:
            continue

        chunk.set_index("Time", inplace=True)
        for column in chunk.columns:
            chunk[column] = pd.to_numeric(chunk[column], errors="coerce")
        frames.append(chunk)

    if not frames:
        return pd.DataFrame()

    df = pd.concat(frames, axis=0)
    df = df.sort_index()
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
        df = process_csv(path, start_time=start_time)
        if df.empty:
            continue

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


def merge_incremental_frames(
    schema_frames: Dict[str, pd.DataFrame],
    outlier_limits: Dict[str, Iterable[float]],
) -> pd.DataFrame:
    frames: List[pd.DataFrame] = []
    for name, df in schema_frames.items():
        if df is None or df.empty:
            continue
        if "Time" not in df.columns:
            continue
        chunk = df.copy()
        chunk["Time"] = pd.to_datetime(chunk["Time"], errors="coerce")
        chunk = chunk.dropna(subset=["Time"])
        if chunk.empty:
            continue
        chunk.set_index("Time", inplace=True)
        for column in chunk.columns:
            chunk[column] = pd.to_numeric(chunk[column], errors="coerce")
        chunk.columns = [f"{name}_{col}" for col in chunk.columns]

        for column, limits in outlier_limits.items():
            if column not in chunk.columns:
                continue
            if isinstance(limits, (list, tuple)) and len(limits) == 2:
                lower, upper = limits
                chunk[column] = chunk[column].where(
                    (chunk[column] >= lower) & (chunk[column] <= upper), np.nan
                )
        frames.append(chunk)

    if not frames:
        return pd.DataFrame()

    merged = pd.concat(frames, axis=1)
    merged = merged.sort_index()
    if not merged.index.is_unique:
        merged = merged.groupby(level=0).mean()
    return merged


def main(argv: List[str]) -> int:
    if len(argv) > 1:
        print("Info: station argument ignored; single-host layout in use.")

    clean_logs_directory = DATA_FILES_ROOT / "CLEAN"
    unprocessed_logs_directory = DATA_FILES_ROOT / "UNPROCESSED"
    accumulated_directory = DATA_FILES_ROOT / "ACCUMULATED"
    final_output_path = DATA_FILES_ROOT / "big_log_lab_data.csv"
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
        moved_file_names: Set[str] = {p.name for p in files_to_move}

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
        create_new_csv = bool(config.get("create_new_csv", False)) if isinstance(config, dict) else False

        final_last_timestamp = None
        if create_new_csv:
            if final_output_path.exists():
                final_output_path.unlink()
                print(f"Removed existing {final_output_path}")
        else:
            final_last_timestamp = get_last_timestamp(final_output_path)

        print("Processing files...")

        if files_to_move:
            print(f"Moved {len(files_to_move)} file(s) into {unprocessed_logs_directory}.")
        else:
            print("No cleaned files were pending move; using existing UNPROCESSED data.")

        produced_paths: Dict[str, Path] = {}
        aggregated_last_cache: Dict[str, Optional[pd.Timestamp]] = {}
        schema_new_frames: Dict[str, pd.DataFrame] = {}

        print("Aggregating per-prefix log files ...")
        for schema in FILE_SCHEMAS:
            output_path = accumulated_directory / schema.output
            last_timestamp = get_last_timestamp(output_path)
            archive_dir = unprocessed_logs_directory / "processed" / schema.prefix
            incremental_rows: Optional[pd.DataFrame] = None
            new_rows = process_files(
                schema,
                unprocessed_logs_directory,
                last_timestamp=last_timestamp,
                archive_dir=archive_dir,
                allowed_files=moved_file_names,
            )
            if not new_rows.empty:
                incremental_rows = new_rows.copy()
                latest_time = new_rows["Time"].max() if "Time" in new_rows.columns else None
                if "Time" in new_rows.columns:
                    new_rows = new_rows.copy()
                    new_rows["Time"] = new_rows["Time"].dt.strftime("%Y-%m-%d %H:%M:%S")
                append_dataframe_to_csv(new_rows, output_path)
                if latest_time is not None:
                    last_timestamp = latest_time
                print(f"Aggregated CSV updated: {output_path}")
            aggregated_last_cache[schema.label] = last_timestamp
            if output_path.exists():
                produced_paths[schema.label] = output_path
            if incremental_rows is not None and not incremental_rows.empty:
                schema_new_frames[schema.label] = incremental_rows

        print("All files processed...")

        if not produced_paths:
            print("No aggregated files were generated. Skipping merge.")
            success = True
            return 0

        if not create_new_csv and final_last_timestamp is not None:
            produced_paths = {
                label: path
                for label, path in produced_paths.items()
                if aggregated_last_cache.get(label) is not None
                and aggregated_last_cache[label] > final_last_timestamp
            }

        if not produced_paths:
            print("No new data detected for merged CSV. Skipping final update.")
            success = True
            return 0

        incremental_candidates: Dict[str, pd.DataFrame] = {
            label: schema_new_frames[label]
            for label in produced_paths.keys()
            if label in schema_new_frames and not schema_new_frames[label].empty
        }

        use_incremental_merge = (
            not create_new_csv
            and final_last_timestamp is not None
            and bool(incremental_candidates)
        )

        if use_incremental_merge:
            print("Merging incremental new rows (skipping full aggregated CSV read).")
            merged_df = merge_incremental_frames(incremental_candidates, outlier_limits)
        else:
            print("Merging aggregated CSV files (full read) ...")
            merged_df = merge_dataframes(
                produced_paths,
                outlier_limits,
                start_time=None if create_new_csv else final_last_timestamp,
            )

        if merged_df.empty:
            print("No data available after aggregation. Skipping final CSV generation.")
            success = True
            return 0

        merged_df = merged_df.resample("1min").mean()
        merged_df.reset_index(inplace=True)

        if not create_new_csv and final_last_timestamp is not None:
            merged_df = merged_df[merged_df["Time"] > final_last_timestamp]

        if merged_df.empty:
            print("No new rows to append to merged CSV.")
            success = True
            return 0

        merged_df = merged_df.sort_values("Time")
        merged_df = merged_df.drop_duplicates(subset=["Time"], keep="last")
        merged_df["Time"] = merged_df["Time"].dt.strftime("%Y-%m-%d %H:%M:%S")

        append_dataframe_to_csv(merged_df, final_output_path)
        print(f"Appended merged data to {final_output_path}")

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
