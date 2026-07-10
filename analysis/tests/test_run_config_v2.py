"""Tests for Data Model v2 run config resolution."""

from __future__ import annotations

from pathlib import Path

import pytest

from benchmark_analysis.run_config_v2 import (
    RunConfigError,
    expand_cells,
    load_catalog,
    resolve_run_config,
    resolve_type_config,
    soft_budget_seconds,
    type_config_hash,
)

_REPO = Path(__file__).resolve().parents[2]
_LIBRARY = _REPO / "config" / "library"
_CATALOG = _REPO / "schemas" / "data_catalog_v2.yaml"


def test_catalog_loads_five_types():
    cat = load_catalog(_CATALOG)
    assert cat["data_model_version"] == 2
    assert set(cat["types"]) == {"message", "document", "telemetry", "strings", "event"}


def test_resolve_empty_type_config_fills_defaults():
    cat = load_catalog(_CATALOG)
    resolved = resolve_type_config("telemetry", {}, cat)
    assert resolved["points"] == 32
    assert resolved["number_type"] == "float64"
    assert "all_available" not in str(resolved.get("primitive_types", []))


def test_message_all_available_expands():
    cat = load_catalog(_CATALOG)
    resolved = resolve_type_config("message", {}, cat)
    assert resolved["primitive_types"] == [
        "bool",
        "int32",
        "int64",
        "float64",
        "utf8_string",
    ]


def test_forbidden_keys_rejected():
    cat = load_catalog(_CATALOG)
    with pytest.raises(RunConfigError, match="must not contain"):
        resolve_type_config("message", {"data_type_instance_count": 1}, cat)


def test_type_config_hash_stable():
    cat = load_catalog(_CATALOG)
    a = resolve_type_config("strings", {}, cat)
    b = resolve_type_config("strings", {}, cat)
    assert type_config_hash(a) == type_config_hash(b)
    assert len(type_config_hash(a)) == 12


def test_smoke_expand_cell_count():
    resolved = resolve_run_config(_LIBRARY / "smoke.yaml", catalog_path=_CATALOG, seed=42)
    assert resolved["cell_count"] == 2  # message + telemetry × [1]
    assert resolved["seed"] == 42
    assert resolved["run_config"]["content_sha256"]
    ids = {(c["type_id"], c["data_type_instance_count"]) for c in resolved["cells"]}
    assert ids == {("message", 1), ("telemetry", 1)}


def test_default_expand_cell_count():
    resolved = resolve_run_config(_LIBRARY / "default.yaml", catalog_path=_CATALOG)
    # 5 types × 2 counts
    assert resolved["cell_count"] == 10
    counts = {c["data_type_instance_count"] for c in resolved["cells"]}
    assert counts == {1, 100}


def test_unknown_type_id():
    cat = load_catalog(_CATALOG)
    with pytest.raises(RunConfigError, match="unknown type_id"):
        expand_cells(
            {"types": [{"type_id": "nope", "type_config": {}}], "data_type_instance_count": [1]},
            cat,
        )


def test_soft_budget():
    assert soft_budget_seconds(1) == 60
    assert soft_budget_seconds(10) == 60
    assert soft_budget_seconds(11) == 120
    assert soft_budget_seconds(19) == 120
