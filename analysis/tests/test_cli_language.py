"""CLI language filter and artifact-generation defaults."""
from __future__ import annotations

import pytest

from benchmark_analysis.cli import (
    _filter_lang_paths,
    _normalize_language,
)


def test_normalize_language_aliases():
    assert _normalize_language("python") == "python"
    assert _normalize_language("py") == "python"
    assert _normalize_language("CS") == "csharp"
    assert _normalize_language("c-sharp") == "csharp"
    assert _normalize_language("js") == "javascript"


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
