"""CSV parsing utilities for benchmark data."""

from __future__ import annotations

import csv
import os
from typing import Dict, List, Optional, Tuple


def parse_csv_file(filepath: str, language_hint: Optional[str] = None) -> Tuple[List[Dict], int]:
    """Parse benchmark CSV file and return (records, skipped_count).

    Supports legacy headers (no Language column) and v1.1+ with Language,
    MemoryPeakBytes, FidelityScore, SerializerVersion.

    The second return value makes skipped/malformed rows auditable by callers.
    """
    records: List[Dict] = []
    skipped = 0
    if not filepath or not os.path.exists(filepath):
        return records, 0

    # Infer language from path if not provided
    if language_hint is None:
        low = filepath.replace("\\", "/").lower()
        for token, lang in (
            ("/csharp/", "csharp"),
            ("/c-sharp/", "csharp"),
            ("/python/", "python"),
            ("/rust/", "rust"),
            ("/javascript/", "javascript"),
            ("/logs/go/", "go"),
            ("/go/", "go"),
            ("/logs/c/", "c"),
        ):
            if token in low:
                language_hint = lang
                break
        if language_hint is None:
            # Robust C detection: require "c" as an exact path segment (prevents
            # false positives on "compat", "case", "data/case.csv" etc).
            parts = [p for p in low.split("/") if p]
            if "c" in parts:
                language_hint = "c"
            elif low.endswith(("/c", "/c/", "/c.csv")):
                language_hint = "c"

    with open(filepath, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                lang = (row.get("Language") or language_hint or "").strip()
                record = {
                    "Language": lang,
                    "StringOrStream": row.get("StringOrStream", ""),
                    "TestDataName": row.get("TestDataName", ""),
                    "Repetitions": int(row.get("Repetitions", 0) or 0),
                    "RepetitionIndex": int(row.get("RepetitionIndex", 0) or 0),
                    "SerializerName": row.get("SerializerName", ""),
                    "TimeSer": int(float(row.get("TimeSer", 0) or 0)),
                    "TimeDeser": int(float(row.get("TimeDeser", 0) or 0)),
                    "Size": int(float(row.get("Size", 0) or 0)),
                    "TimeSerAndDeser": int(float(row.get("TimeSerAndDeser", 0) or 0)),
                    "OpPerSecSer": float(row.get("OpPerSecSer", 0) or 0),
                    "OpPerSecDeser": float(row.get("OpPerSecDeser", 0) or 0),
                    "OpPerSecSerAndDeser": float(row.get("OpPerSecSerAndDeser", 0) or 0),
                }
                if "MemoryPeakBytes" in row and row["MemoryPeakBytes"] not in (None, ""):
                    record["MemoryPeakBytes"] = int(float(row["MemoryPeakBytes"]))
                if "FidelityScore" in row and row["FidelityScore"] not in (None, ""):
                    record["FidelityScore"] = float(row["FidelityScore"])
                if "SerializerVersion" in row and row["SerializerVersion"]:
                    record["SerializerVersion"] = row["SerializerVersion"]
                # Optional metadata (Rust v0.2+; ignored if absent for older CSVs)
                if "NativeKind" in row and row["NativeKind"] not in (None, ""):
                    record["NativeKind"] = str(row["NativeKind"]).strip()
                if "StreamMode" in row and row["StreamMode"] not in (None, ""):
                    record["StreamMode"] = str(row["StreamMode"]).strip()
                # Data Model v2 optional columns
                if "DataTypeInstanceCount" in row and row["DataTypeInstanceCount"] not in (None, ""):
                    record["DataTypeInstanceCount"] = int(float(row["DataTypeInstanceCount"]))
                if "TypeConfigHash" in row and row["TypeConfigHash"] not in (None, ""):
                    record["TypeConfigHash"] = str(row["TypeConfigHash"]).strip()
                if "SizeGzip" in row and row["SizeGzip"] not in (None, ""):
                    record["SizeGzip"] = int(float(row["SizeGzip"]))
                if "SizeZstd" in row and row["SizeZstd"] not in (None, ""):
                    record["SizeZstd"] = int(float(row["SizeZstd"]))
                records.append(record)
            except (ValueError, KeyError, TypeError) as e:
                skipped += 1
                print(f"Warning: Skipping malformed row: {row}, error: {e}")
    if skipped:
        print(f"Parser: skipped {skipped} malformed row(s) from {filepath}")
    return records, skipped

