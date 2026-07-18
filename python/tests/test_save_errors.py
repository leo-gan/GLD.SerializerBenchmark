"""save_errors must not create a header-only errors file on clean runs."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.report import BenchmarkError, save_errors


def test_save_errors_empty_does_not_create_file(tmp_path: Path):
    path = tmp_path / "run.errors.csv"
    save_errors([], str(path))
    assert not path.exists()


def test_save_errors_empty_removes_preexisting_file(tmp_path: Path):
    path = tmp_path / "run.errors.csv"
    path.write_text("TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n", encoding="utf-8")
    assert path.exists()
    save_errors([], str(path))
    assert not path.exists()


def test_save_errors_with_errors_writes_header_and_rows(tmp_path: Path):
    path = tmp_path / "run.errors.csv"
    err = BenchmarkError(
        string_or_stream="bytes",
        test_data_name="message",
        serializer_name="orjson",
        repetition=1,
        error_text="boom",
    )
    save_errors([err], str(path))
    assert path.exists()
    text = path.read_text(encoding="utf-8")
    assert "TestDataName,SerializerName,StringOrStream,Repetition,ErrorText" in text
    assert "message" in text and "orjson" in text and "boom" in text
