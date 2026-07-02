"""Default log directory must be repo-root logs/python, not cwd-relative."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
sys.path.insert(0, str(ROOT / "src"))

from benchmark.runner import _default_log_dir, _repo_root


def test_repo_root_points_at_monorepo():
    root = _repo_root()
    assert root is not None
    assert (root / "config" / "benchmark_config.yaml").is_file()
    assert root == REPO.resolve()


def test_default_log_dir_is_repo_logs_python(monkeypatch, tmp_path: Path):
    monkeypatch.delenv("LOG_DIR", raising=False)
    monkeypatch.delenv("BENCHMARK_LOG_DIR", raising=False)
    # Even if cwd is elsewhere, default stays under repo logs/python
    monkeypatch.chdir(tmp_path)
    d = _default_log_dir()
    assert d == (REPO / "logs" / "python").resolve()
    assert d.is_absolute()


def test_log_dir_env_overrides(monkeypatch, tmp_path: Path):
    monkeypatch.setenv("LOG_DIR", str(tmp_path / "custom_logs"))
    d = _default_log_dir()
    assert d == (tmp_path / "custom_logs" / "python").resolve()

    monkeypatch.setenv("LOG_DIR", str(tmp_path / "custom_logs" / "python"))
    d2 = _default_log_dir()
    assert d2 == (tmp_path / "custom_logs" / "python").resolve()
