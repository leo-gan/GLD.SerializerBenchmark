"""Parser tests."""

from __future__ import annotations

import csv
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from benchmark_analysis.parser import parse_csv_file


def test_parse_legacy_csv_without_language():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False, newline="") as f:
        w = csv.writer(f)
        w.writerow(["StringOrStream", "TestDataName", "Repetitions", "RepetitionIndex",
                    "SerializerName", "TimeSer", "TimeDeser", "Size", "TimeSerAndDeser",
                    "OpPerSecSer", "OpPerSecDeser", "OpPerSecSerAndDeser"])
        w.writerow(["string", "Person", 1, 0, "Json.NET", 1000, 2000, 50, 3000, 1, 1, 1])
        path = f.name
    recs, skipped = parse_csv_file(path, language_hint="csharp")
    assert len(recs) == 1
    assert skipped == 0
    assert recs[0]["Language"] == "csharp"
    assert recs[0]["TimeSer"] == 1000


def test_parse_v11_csv_with_language():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False, newline="") as f:
        w = csv.writer(f)
        # SerializerVersion immediately after SerializerName (current contract).
        w.writerow(["Language", "StringOrStream", "TestDataName", "Repetitions", "RepetitionIndex",
                    "SerializerName", "SerializerVersion", "TimeSer", "TimeDeser", "Size",
                    "TimeSerAndDeser", "OpPerSecSer", "OpPerSecDeser", "OpPerSecSerAndDeser",
                    "MemoryPeakBytes", "FidelityScore"])
        w.writerow(["rust", "bytes", "Person", 10, 1, "serde_json", "1.0.145", 5000, 6000, 80,
                    11000, 1, 1, 1, 0, 1.0])
        path = f.name
    recs, skipped = parse_csv_file(path)
    assert skipped == 0
    assert recs[0]["Language"] == "rust"
    assert recs[0]["FidelityScore"] == 1.0
    assert recs[0]["SerializerVersion"] == "1.0.145"


def test_parse_legacy_serializer_version_at_end():
    """Older CSVs put SerializerVersion after FidelityScore — still readable by name."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False, newline="") as f:
        w = csv.writer(f)
        w.writerow(["Language", "StringOrStream", "TestDataName", "Repetitions", "RepetitionIndex",
                    "SerializerName", "TimeSer", "TimeDeser", "Size", "TimeSerAndDeser",
                    "OpPerSecSer", "OpPerSecDeser", "OpPerSecSerAndDeser", "MemoryPeakBytes",
                    "FidelityScore", "SerializerVersion"])
        w.writerow(["python", "bytes", "Person", 10, 1, "orjson", 5000, 6000, 80, 11000,
                    1, 1, 1, 0, 1.0, "3.11.9"])
        path = f.name
    recs, skipped = parse_csv_file(path)
    assert skipped == 0
    assert recs[0]["SerializerVersion"] == "3.11.9"
