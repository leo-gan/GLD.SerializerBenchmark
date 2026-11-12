#!/usr/bin/env python3
"""Write one n=1 example of each data type for the dashboard explain panel.

The record is the catalog default at seed 42, the same builder the timed
runs use. Long lists are clipped. A matrix is not pasted in full.

    python3 dashboard/scripts/write-type-examples.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "analysis" / "src"))
sys.path.insert(0, str(ROOT / "python" / "src"))

from benchmark.data_v2.generator import make_one  # noqa: E402
from benchmark_analysis.run_config_v2 import load_catalog, resolve_type_config  # noqa: E402

OUT = ROOT / "dashboard" / "public" / "data" / "type-examples.json"
SEED = 42

# Order matches the dashboard data-type menus.
TYPE_IDS = [
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
    "tensor",
    "tensor_view",
    "prompt",
    "shard",
    "request",
]

NOTES = {
    "table_project": "The write is this row. The timed read returns f_float_0 only.",
    "grid": "values run y outer, x inner. The list below is the start of the array.",
    "grid_window": "The write is this array. The timed read returns the interior window.",
    "tensor": 'values[0] is negative zero and values[1] is a quiet NaN, written here as "-0" and "NaN".',
    "tensor_view": "Same matrix as tensor. The timed read borrows the encoded bytes.",
    "prompt": "Each list is batch × seq, row-major. The lists below are the start.",
    "shard": "Weights are row-major. Each list below is the start of that block.",
    "request": "One call: an id, a model name, a temperature, and the prompt tensors.",
    "graph": "Orders share a region by index. People form a ring; next is the next person's index.",
}


def _num(value: float) -> Any:
    if isinstance(value, float):
        if math.isnan(value):
            return "NaN"
        if value == 0.0 and math.copysign(1.0, value) < 0:
            return "-0"
        if math.isinf(value):
            return "Infinity" if value > 0 else "-Infinity"
    return value


def _clip(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _clip(item) for key, item in value.items()}
    if isinstance(value, list):
        items = [_clip(item) for item in value]
        objects = bool(items) and all(isinstance(item, dict) for item in items)
        if objects and len(items) > 8:
            return items[:2] + [{"_more": len(items) - 2}]
        if not objects and len(items) > 32:
            return items[:4] + [{"_more": len(items) - 4}]
        return items
    return _num(value)


def _graph(book: Any) -> dict[str, Any]:
    regions: list[Any] = []
    region_ids: dict[int, int] = {}
    orders = []
    for order in book.orders:
        region = order.region
        key = id(region)
        if key not in region_ids:
            region_ids[key] = len(regions)
            regions.append(
                {"code": region.code, "note": region.note, "version": region.version}
            )
        orders.append(
            {"sku": order.sku, "qty": order.qty, "region": region_ids[key]}
        )
    # Order 0 and order 4 share region 0. Keep both so the share is visible.
    if len(orders) > 5:
        orders = orders[:5] + [{"_more": len(orders) - 5}]
    people = []
    index = {id(person): i for i, person in enumerate(book.people)}
    for person in book.people:
        people.append({"name": person.name, "next": index[id(person.next)]})
    return {"regions": regions, "orders": orders, "people": people}


def _record(type_id: str, catalog: dict[str, Any]) -> Any:
    config = resolve_type_config(type_id, None, catalog)
    made = make_one(type_id, config, SEED, 0)
    if type_id == "graph":
        raw = _graph(made)
    elif hasattr(made, "to_dict"):
        raw = made.to_dict()
    else:
        raw = made
    return _clip(raw)


def main() -> int:
    catalog = load_catalog()
    types = {}
    for type_id in TYPE_IDS:
        entry: dict[str, Any] = {"record": _record(type_id, catalog)}
        note = NOTES.get(type_id)
        if note:
            entry["note"] = note
        types[type_id] = entry
    payload = {"seed": SEED, "n": 1, "types": types}
    OUT.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
