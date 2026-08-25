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


def test_run_config_paths_from_master_config():
    """smoke/default library YAML paths come from data_model_v2 in master config."""
    import subprocess
    import sys
    from pathlib import Path

    from benchmark_analysis.config_loader import dig, load_master_config, repo_root

    root = repo_root()
    cfg = load_master_config()
    smoke_rel = dig(cfg, "data_model_v2.smoke_run_config", "config/library/smoke.yaml")
    default_rel = dig(cfg, "data_model_v2.default_run_config", "config/library/default.yaml")
    script = root / "scripts" / "read-config.py"
    for mode, expected_rel in (("smoke", smoke_rel), ("all-single", default_rel), ("full", default_rel)):
        out = subprocess.check_output(
            [sys.executable, str(script), "--run-config-for-mode", mode],
            cwd=str(root),
            text=True,
        ).strip()
        p = Path(out)
        assert p.is_file(), f"missing run config for {mode}: {out}"
        assert p.resolve() == (root / expected_rel).resolve()


def test_seed_and_languages():
    assert random_seed() == 42
    ids = known_language_ids()
    assert "python" in ids
    assert "go" in ids
    assert "java" in ids
    assert "cpp" in ids
    assert "swift" in ids
    enabled = {e["id"] for e in enabled_languages()}
    assert "go" in enabled
    assert "java" in enabled
    assert "cpp" in enabled
    assert "swift" in enabled
    assert language_docs_dir("csharp") == "c-sharp"
    assert language_docs_dir("java") == "java"
    assert language_docs_dir("cpp") == "cpp"
    assert language_docs_dir("swift") == "swift"
