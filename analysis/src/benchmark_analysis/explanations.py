"""Dashboard sentences for Standard, Data Set, and Data Type.

The words live next to the definitions:

- standards: config/standards.yaml (path recorded in config/dimensions.yaml)
- data sets: ``explanation`` on each ``data_sets`` row in config/benchmark_config.yaml
- data types: ``explanation`` on each type in schemas/data_catalog_v2.yaml
- menu values that combine types or batch sizes: ``data_type_views`` in
  config/dimensions.yaml

The dashboard reads the copy in dashboard/public/data/dimension-labels.json.
"""

from __future__ import annotations

from typing import Any

import yaml

from benchmark_analysis.config_loader import data_sets, repo_root
from benchmark_analysis.dimensions import load_dimensions
from benchmark_analysis.run_config_v2 import DEFAULT_CATALOG, load_catalog


def _clean(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    return " ".join(value.split())


def load_standard_definitions(dimensions: dict[str, Any] | None = None) -> dict[str, dict[str, str]]:
    """id → {label, explanation} from the standards definition file."""
    dims = dimensions if dimensions is not None else load_dimensions()
    rel = str((dims.get("standards") or {}).get("definitions") or "config/standards.yaml")
    path = repo_root() / rel
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    rows = raw.get("standards") or {}
    out: dict[str, dict[str, str]] = {}
    for sid, row in rows.items():
        if isinstance(row, str):
            out[str(sid)] = {"label": str(sid), "explanation": _clean(row)}
            continue
        if not isinstance(row, dict):
            continue
        out[str(sid)] = {
            "label": _clean(row.get("label")) or str(sid),
            "explanation": _clean(row.get("explanation")),
        }
    return out


def load_dashboard_explanations() -> dict[str, Any]:
    """The explanations object stored on dimension-labels.json."""
    dims = load_dimensions()
    standards = {
        sid: row["explanation"]
        for sid, row in load_standard_definitions(dims).items()
    }
    sets: dict[str, str] = {}
    for row in data_sets():
        sid = row.get("id")
        if isinstance(sid, str) and sid:
            sets[sid] = _clean(row.get("explanation"))
    catalog = load_catalog(DEFAULT_CATALOG)
    types: dict[str, str] = {}
    for type_id, entry in (catalog.get("types") or {}).items():
        if isinstance(entry, dict):
            types[str(type_id)] = _clean(entry.get("explanation"))
    views_raw = dims.get("data_type_views") or {}
    views = {
        str(key): _clean(value)
        for key, value in views_raw.items()
        if isinstance(value, str)
    }
    return {
        "standards": standards,
        "data_sets": sets,
        "data_types": types,
        "views": views,
    }
