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


def test_catalog_loads_suite_types():
    cat = load_catalog(_CATALOG)
    assert cat["data_model_version"] == 2
    assert set(cat["types"]) == {
        "message",
        "document",
        "telemetry",
        "strings",
        "event",
        "table",
        "table_project",
        "nested_table",
        "signal",
        "graph",
        "grid",
        "grid_window",
    }


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


def test_columnar_run_configs_cell_counts():
    smoke = resolve_run_config(_LIBRARY / "columnar-smoke.yaml", catalog_path=_CATALOG, seed=42)
    assert smoke["cell_count"] == 4
    assert {c["data_type_instance_count"] for c in smoke["cells"]} == {1}
    assert smoke["compression"]["mode"] == "none"

    full = resolve_run_config(_LIBRARY / "columnar.yaml", catalog_path=_CATALOG, seed=42)
    assert full["cell_count"] == 10  # 3+3+2+2
    by_type: dict[str, set[int]] = {}
    hashes: dict[str, str] = {}
    for cell in full["cells"]:
        by_type.setdefault(cell["type_id"], set()).add(cell["data_type_instance_count"])
        hashes[cell["type_id"]] = cell["type_config_hash"]
    assert by_type["table"] == {1, 100, 10000}
    assert by_type["table_project"] == {1, 100, 10000}
    assert by_type["nested_table"] == {1, 100}
    assert by_type["signal"] == {1, 100}
    assert hashes["table"] == hashes["table_project"]
    assert full["compression"]["mode"] == "none"
    assert full["execution"]["io_modes"] == ["bytes"]


def test_graph_run_config_cell_counts():
    resolved = resolve_run_config(_LIBRARY / "graph.yaml", catalog_path=_CATALOG, seed=42)
    assert resolved["cell_count"] == 2
    assert {(c["type_id"], c["data_type_instance_count"]) for c in resolved["cells"]} == {
        ("graph", 1),
        ("graph", 100),
    }
    assert resolved["compression"]["mode"] == "none"
    assert resolved["execution"]["io_modes"] == ["bytes"]
    cfg = resolved["cells"][0]["type_config"]
    assert cfg["order_count"] == 32
    assert cfg["region_count"] == 4
    assert cfg["ring_size"] == 8


def test_array_run_configs_cell_counts():
    smoke = resolve_run_config(_LIBRARY / "array-smoke.yaml", catalog_path=_CATALOG, seed=42)
    assert smoke["cell_count"] == 2
    assert {(c["type_id"], c["data_type_instance_count"]) for c in smoke["cells"]} == {
        ("grid", 1),
        ("grid_window", 1),
    }
    full = resolve_run_config(_LIBRARY / "array.yaml", catalog_path=_CATALOG, seed=42)
    assert full["cell_count"] == 2
    by_id = {c["type_id"]: c for c in full["cells"]}
    assert by_id["grid"]["type_config"]["nx"] == 512
    assert by_id["grid"]["type_config"]["ny"] == 512
    assert "window" not in by_id["grid"]["type_config"]
    window = by_id["grid_window"]["type_config"]["window"]
    assert window == {"x0": 128, "y0": 64, "wx": 256, "wy": 128}
    assert by_id["grid"]["type_config_hash"] != by_id["grid_window"]["type_config_hash"]
    assert full["compression"]["mode"] == "none"
    assert full["execution"]["io_modes"] == ["bytes"]


def test_grid_window_must_lie_inside_the_array():
    cat = load_catalog(_CATALOG)
    with pytest.raises(RunConfigError, match="does not lie inside"):
        resolve_type_config(
            "grid_window",
            {"window": {"x0": 400, "y0": 0, "wx": 256, "wy": 128}},
            cat,
        )


def test_signal_schema_field_order():
    proto = (_REPO / "schemas" / "v2" / "protobuf" / "benchmark_v2.proto").read_text(encoding="utf-8")
    signal = proto.split("message Signal {", 1)[1].split("message BatchSignal", 1)[0]
    assert signal.index("int64 seq") < signal.index("string symbol")
    assert signal.index("string symbol") < signal.index("string venue")
    assert signal.index("string venue") < signal.index("repeated SignalLeg legs")

    # sbe-tool 1.40.2 rejects a group after variable-length data
    # ("group node specified after data node"). Signal's wire order is the
    # fixed block, then legs, then symbol and venue. Field ids are unchanged.
    xml = (_REPO / "schemas" / "v2" / "sbe" / "signal.xml").read_text(encoding="utf-8")
    body = xml.split('<sbe:message name="Signal"', 1)[1].split("</sbe:message>", 1)[0]
    assert body.index('name="seq"') < body.index('name="legs"')
    assert body.index('name="legs"') < body.index('name="symbol"')
    assert body.index('name="symbol"') < body.index('name="venue"')


def test_soft_budget():
    assert soft_budget_seconds(1) == 60
    assert soft_budget_seconds(10) == 60
    assert soft_budget_seconds(11) == 120
    assert soft_budget_seconds(19) == 120
