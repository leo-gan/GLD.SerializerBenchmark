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
from benchmark.data_v2.fidelity import expected_for_fidelity, fidelity_for, fidelity_graph, fidelity_v2
from benchmark.data_v2.models import (
    Book,
    Document,
    Event,
    Message,
    NestedRow,
    Order,
    Person,
    Region,
    Signal,
    Strings,
    TableRow,
    Telemetry,
)

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
        ("table", TableRow),
        ("table_project", TableRow),
        ("nested_table", NestedRow),
        ("signal", Signal),
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


def test_table_strings_repeat_across_rows(catalog):
    cfg = resolve_type_config("table", {}, catalog)
    rows = instances_for_cell("table", cfg, seed=42, data_type_instance_count=40)
    values = [row.f_str_0 for row in rows]
    assert len(set(values)) < len(values)
    again = instances_for_cell("table", cfg, seed=42, data_type_instance_count=40)
    assert [row.f_str_0 for row in again] == values


def test_table_and_table_project_share_shape_not_seed(catalog):
    table_cfg = resolve_type_config("table", {}, catalog)
    project_cfg = resolve_type_config("table_project", {}, catalog)
    assert table_cfg == project_cfg
    table_row = make_one("table", table_cfg, seed=42, instance_index=0)
    project_row = make_one("table_project", project_cfg, seed=42, instance_index=0)
    assert table_row != project_row


def test_table_project_expected_column(catalog):
    cfg = resolve_type_config("table_project", {}, catalog)
    rows = instances_for_cell("table_project", cfg, seed=42, data_type_instance_count=4)
    expected = expected_for_fidelity("table_project", rows)
    assert expected == [row.f_float_0 for row in rows]
    assert len(expected) == 4
    assert fidelity_v2(expected, list(expected)) == 1.0
    assert fidelity_v2(expected, rows) == 0.0
    one = instances_for_cell("table_project", cfg, seed=42, data_type_instance_count=1)
    assert expected_for_fidelity("table_project", one) == [one[0].f_float_0]


def test_nested_table_children(catalog):
    cfg = resolve_type_config("nested_table", {}, catalog)
    row = make_one("nested_table", cfg, seed=3, instance_index=0)
    assert len(row.items) == 4


def _alias_copy(book: Book) -> Book:
    regions: dict[int, Region] = {}
    orders = []
    for order in book.orders:
        key = id(order.region)
        region = regions.get(key)
        if region is None:
            region = Region(code=order.region.code, note=order.region.note, version=order.region.version)
            regions[key] = region
        orders.append(Order(sku=order.sku, qty=order.qty, region=region))
    people = [Person(name=person.name, next=None) for person in book.people]
    for i, person in enumerate(people):
        person.next = people[(i + 1) % len(people)]
    return Book(orders=orders, people=people)


def _duplicated_copy(book: Book) -> Book:
    orders = [
        Order(
            sku=order.sku,
            qty=order.qty,
            region=Region(code=order.region.code, note=order.region.note, version=order.region.version),
        )
        for order in book.orders
    ]
    people = [Person(name=person.name, next=None) for person in book.people]
    for i, person in enumerate(people):
        nxt = book.people[(i + 1) % len(book.people)]
        person.next = Person(name=nxt.name, next=None)
    return Book(orders=orders, people=people)


def test_graph_shape_and_identity(catalog):
    cfg = resolve_type_config("graph", {}, catalog)
    book = make_one("graph", cfg, seed=42, instance_index=0)
    assert isinstance(book, Book)
    assert len(book.orders) == 32
    assert len(book.people) == 8
    assert len({id(order.region) for order in book.orders}) == 4
    assert len({order.sku for order in book.orders}) == 32
    assert all(len(order.region.note) == 64 for order in book.orders)
    counts: dict[int, int] = {}
    for order in book.orders:
        counts[id(order.region)] = counts.get(id(order.region), 0) + 1
    assert set(counts.values()) == {8}
    start = book.people[0]
    node = start
    for _ in range(8):
        node = node.next
    assert node is start
    for i, person in enumerate(book.people):
        assert person.next is book.people[(i + 1) % 8]

    again = make_one("graph", cfg, seed=42, instance_index=0)
    assert fidelity_graph(book, again) == 1.0
    other = make_one("graph", cfg, seed=42, instance_index=1)
    assert fidelity_graph(book, other) == 0.0
    assert fidelity_graph(book, _alias_copy(book)) == 1.0
    assert fidelity_graph(book, _duplicated_copy(book)) == 0.0
    # The suite walker is not the graph comparator. A duplicated copy is still
    # a dataclass the structural walk must not be asked to recurse into.
    assert fidelity_for("graph", book, _duplicated_copy(book)) == 0.0
    assert fidelity_for("message", Message(
        f_bool=True, f_int32=1, f_int64=2, f_float64=1.0,
        f_string="a", f_bool_2=False, f_int32_2=3, f_string_2="b",
    ), Message(
        f_bool=True, f_int32=1, f_int64=2, f_float64=1.0,
        f_string="a", f_bool_2=False, f_int32_2=3, f_string_2="b",
    )) == 1.0


def test_signal_group_is_fixed_then_variable(catalog):
    cfg = resolve_type_config("signal", {}, catalog)
    row = make_one("signal", cfg, seed=9, instance_index=0)
    assert len(row.legs) == 4
    assert all(leg.leg_pad == 0 for leg in row.legs)


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
