"""CSV parsing utilities for benchmark data."""

from __future__ import annotations

import csv
import os
from typing import Dict, List, Optional


def parse_csv_file(filepath: str, language_hint: Optional[str] = None) -> List[Dict]:
    """Parse benchmark CSV file and return list of records.

    Supports legacy headers (no Language column) and v1.1+ with Language,
    MemoryPeakBytes, FidelityScore, SerializerVersion.
    """
    records: List[Dict] = []
    if not filepath or not os.path.exists(filepath):
        return records

    # Infer language from path if not provided
    if language_hint is None:
        low = filepath.replace("\\", "/").lower()
        for token, lang in (
            ("/csharp/", "csharp"),
            ("/c-sharp/", "csharp"),
            ("/python/", "python"),
            ("/rust/", "rust"),
            ("/javascript/", "javascript"),
            ("/logs/c/", "c"),
            ("/logs/c\\", "c"),
        ):
            if token in low:
                language_hint = lang
                break
        if language_hint is None and "/logs/c/" in low or low.rstrip("/").endswith("/c/benchmark-log.csv"):
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
                records.append(record)
            except (ValueError, KeyError, TypeError) as e:
                print(f"Warning: Skipping malformed row: {row}, error: {e}")
    return records


def parse_multi_language_logs(log_paths: Dict[str, str]) -> Dict[str, List[Dict]]:
    """Parse multiple language log files. Keys are language ids."""
    out: Dict[str, List[Dict]] = {}
    for lang, path in log_paths.items():
        if path and os.path.exists(path):
            out[lang] = parse_csv_file(path, language_hint=lang)
        else:
            out[lang] = []
    return out
