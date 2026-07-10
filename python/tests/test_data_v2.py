"""Data Model v2 make_one determinism and catalog alignment."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_PYTHON_ROOT = Path(__file__).resolve().parents[1]
_REPO = _PYTHON_ROOT.parent
sys.path.insert(0, str(_PYTHON_ROOT / "src"))
sys.path.insert(0, str(_REPO / "analysis" / "src"))

from benchmark_analysis.run_config_v2 import load_catalog, resolve_run_config, resolve_type_config

from benchmark.data_v2 import instances_for_cell, make_one
from benchmark.data_v2.models import Document, Event, Message, Strings, Telemetry

_CATALOG = _REPO / "schemas" / "data_catalog_v2.yaml"
_LIBRARY = _REPO / "config" / "library"


@pytest.fixture(scope="module")
def catalog():
    return load_catalog(_CATALOG)


@pytest.mark.parametrize(
    "type_id,cls",
    [
        ("message", Message),
        ("document", Document),
        ("telemetry", Telemetry),
        ("strings", Strings),
        ("event", Event),
    ],
)
def test_make_one_deterministic(catalog, type_id, cls):
    cfg = resolve_type_config(type_id, {}, catalog)
    a = make_one(type_id, cfg, seed=42, instance_index=0)
    b = make_one(type_id, cfg, seed=42, instance_index=0)
    assert isinstance(a, cls)
    assert a == b
    c = make_one(type_id, cfg, seed=42, instance_index=1)
    assert a != c


def test_telemetry_points_from_config(catalog):
    cfg = resolve_type_config("telemetry", {"points": 10}, catalog)
    t = make_one("telemetry", cfg, seed=1, instance_index=0)
    assert len(t.values) == 10
    assert len(t.tags) == cfg["tag_count"]


def test_document_children(catalog):
    cfg = resolve_type_config("document", {"children": 3}, catalog)
    d = make_one("document", cfg, seed=7, instance_index=0)
    assert len(d.items) == 3


def test_instances_for_cell_count(catalog):
    cfg = resolve_type_config("event", {}, catalog)
    batch = instances_for_cell("event", cfg, seed=42, data_type_instance_count=5)
    assert len(batch) == 5
    assert len({e.event_id for e in batch}) == 5


def test_default_run_config_cells_generate():
    resolved = resolve_run_config(_LIBRARY / "default.yaml", catalog_path=_CATALOG, seed=42)
    for cell in resolved["cells"]:
        batch = instances_for_cell(
            cell["type_id"],
            cell["type_config"],
            seed=42,
            data_type_instance_count=cell["data_type_instance_count"],
        )
        assert len(batch) == cell["data_type_instance_count"]
