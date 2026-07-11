"""CLI language filter and --logs assignment helpers."""
from __future__ import annotations

from pathlib import Path

import pytest

from benchmark_analysis.cli import (
    _filter_lang_paths,
    _normalize_language,
    _resolve_logs_assignment,
    _split_logs_spec,
)


def test_normalize_language_aliases():
    assert _normalize_language("python") == "python"
    assert _normalize_language("py") == "python"
    assert _normalize_language("CS") == "csharp"
    assert _normalize_language("c-sharp") == "csharp"
    assert _normalize_language("js") == "javascript"
    assert _normalize_language("go") == "go"
    assert _normalize_language("golang") == "go"
    assert _normalize_language("java") == "java"
    assert _normalize_language("jdk") == "java"
    assert _normalize_language("jvm") == "java"


def test_normalize_language_unknown():
    with pytest.raises(SystemExit):
        _normalize_language("cobol")


def test_filter_lang_paths():
    paths = {
        "python": "a.csv",
        "rust": "b.csv",
        "csharp": "c.csv",
    }
    assert _filter_lang_paths(paths, None) == paths
    assert _filter_lang_paths(paths, ["python"]) == {"python": "a.csv"}
    assert _filter_lang_paths(paths, ["py", "rust"]) == {
        "python": "a.csv",
        "rust": "b.csv",
    }


def test_split_logs_spec():
    assert _split_logs_spec("python=/tmp/x") == ("python", "/tmp/x")
    assert _split_logs_spec("py=logs/python") == ("python", "logs/python")
    assert _split_logs_spec("/tmp/only/path") == (None, "/tmp/only/path")


def test_resolve_logs_assignment_with_lang_eq(tmp_path: Path):
    csv = tmp_path / "2026-07-02-101618.csv"
    csv.write_text("StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,TimeSer,TimeDeser,Size\n")
    lang, path = _resolve_logs_assignment(
        f"python={csv}",
        languages=None,
        logs_root=tmp_path,
    )
    assert lang == "python"
    assert path == str(csv)


def test_resolve_logs_assignment_bare_path_with_language_flag(tmp_path: Path):
    csv = tmp_path / "2026-07-02-101618.csv"
    csv.write_text("x\n")
    lang, path = _resolve_logs_assignment(
        str(csv),
        languages=["python"],
        logs_root=tmp_path,
    )
    assert lang == "python"
    assert path == str(csv)
