"""Master config loader reads config/benchmark_config.yaml."""

from __future__ import annotations

from benchmark_analysis.config_loader import (
    enabled_languages,
    known_language_ids,
    language_docs_dir,
    mode_repetitions,
    random_seed,
)


def test_mode_repetitions_from_config():
    assert mode_repetitions("smoke") == 2
    assert mode_repetitions("all-single") == 10
    assert mode_repetitions("full") == 100
    assert mode_repetitions("research") == 500


def test_seed_and_languages():
    assert random_seed() == 42
    ids = known_language_ids()
    assert "python" in ids
    assert "go" in ids
    assert "java" in ids
    enabled = {e["id"] for e in enabled_languages()}
    assert "go" in enabled
    assert "java" in enabled
    assert language_docs_dir("csharp") == "c-sharp"
    assert language_docs_dir("java") == "java"
