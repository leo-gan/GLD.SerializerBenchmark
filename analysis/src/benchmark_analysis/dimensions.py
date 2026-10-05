"""Standard and Data Set labels.

These are labels on rows the suite already produces. They do not add a timed
loop. Optional I/O membership is the opt-in list in config/dimensions.yaml.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

from benchmark_analysis.run_config_v2 import DEFAULT_CATALOG

_REPO_ROOT = DEFAULT_CATALOG.parents[1]
DEFAULT_DIMENSIONS = _REPO_ROOT / "config" / "dimensions.yaml"
DEFAULT_STANDARDS = _REPO_ROOT / "compliance" / "serializer-standards.json"


class DimensionError(ValueError):
    """Invalid dimension contract or an unknown serializer/type."""


def _load_yaml(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise DimensionError(f"expected a mapping: {path}")
    return data


def load_dimensions(path: Path | None = None) -> dict[str, Any]:
    return _load_yaml(path or DEFAULT_DIMENSIONS)


def load_standards(path: Path | None = None) -> dict[str, Any]:
    raw = json.loads((path or DEFAULT_STANDARDS).read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or "languages" not in raw:
        raise DimensionError("serializer-standards.json is missing languages")
    return raw


def data_set_for_type(type_id: str, catalog: dict[str, Any] | None = None) -> str:
    """Parent data set of a type id. Raises if the type or the label is missing."""
    if catalog is None:
        from benchmark_analysis.run_config_v2 import load_catalog

        catalog = load_catalog(DEFAULT_CATALOG)
    types = catalog.get("types") or {}
    entry = types.get(type_id)
    if not isinstance(entry, dict):
        raise DimensionError(f"unknown type id: {type_id!r}")
    data_set = entry.get("data_set")
    if not isinstance(data_set, str) or not data_set:
        raise DimensionError(f"type {type_id!r} has no data_set")
    return data_set


def standard_for(
    language: str,
    serializer: str,
    standards: dict[str, Any] | None = None,
    dimensions: dict[str, Any] | None = None,
) -> str:
    """Compliance standard id for one timed row.

    An empty compliance list becomes ``empty_value`` (``custom``).
    A serializer with several ids uses the primary id in the dimension contract.
    A missing serializer is an error.
    """
    if standards is None:
        standards = load_standards()
    if dimensions is None:
        dimensions = load_dimensions()
    rules = dimensions.get("standards") or {}
    empty_value = rules.get("empty_value") or "custom"
    langs = standards.get("languages") or {}
    lang_map = langs.get(language)
    if not isinstance(lang_map, dict) or serializer not in lang_map:
        raise DimensionError(f"no standard entry for {language}/{serializer}")
    ids = lang_map[serializer]
    if not isinstance(ids, list):
        raise DimensionError(f"standards for {language}/{serializer} must be a list")
    if len(ids) == 0:
        return str(empty_value)
    if len(ids) == 1:
        return str(ids[0])
    primary_lang = (rules.get("primary") or {}).get(language) or {}
    primary = primary_lang.get(serializer)
    if primary is None:
        raise DimensionError(
            f"{language}/{serializer} has standards {ids} and no primary id"
        )
    if primary not in ids:
        raise DimensionError(
            f"primary {primary!r} for {language}/{serializer} is not in {ids}"
        )
    return str(primary)


def optional_io_index(dimensions: dict[str, Any] | None = None) -> dict[tuple[str, str], dict[str, Any]]:
    """(language, serializer) → opt-in row. One row per serializer."""
    if dimensions is None:
        dimensions = load_dimensions()
    out: dict[tuple[str, str], dict[str, Any]] = {}
    for row in (dimensions.get("optional_io") or {}).get("opt_in") or []:
        key = (row["language"], row["serializer"])
        if key in out:
            raise DimensionError(f"duplicate optional I/O opt-in: {key}")
        out[key] = row
    return out


_LABEL_CACHE: dict[str, Any] = {}


def _standards_and_dimensions() -> tuple[dict[str, Any], dict[str, Any]]:
    if "standards" not in _LABEL_CACHE:
        _LABEL_CACHE["standards"] = load_standards()
        _LABEL_CACHE["dimensions"] = load_dimensions()
    return _LABEL_CACHE["standards"], _LABEL_CACHE["dimensions"]


def label_result_group(group: dict[str, Any], *, strict: bool = False) -> dict[str, Any]:
    """Set data_set and standard on one result group.

    Unknown serializers become standard None unless strict is set.
    Unknown type ids always raise.
    """
    standards, dimensions = _standards_and_dimensions()
    raw = str(group.get("test_data") or "")
    base = raw.split("@", 1)[0]
    group["data_set"] = data_set_for_type(base)
    try:
        group["standard"] = standard_for(
            str(group.get("language") or ""),
            str(group.get("serializer") or ""),
            standards,
            dimensions,
        )
    except DimensionError:
        if strict:
            raise
        group["standard"] = None
    return group


def label_stats_document(doc: dict[str, Any]) -> int:
    """Label every group in a published stats document. Strict."""
    n = 0
    for group in doc.get("groups") or []:
        if not isinstance(group, dict):
            continue
        label_result_group(group, strict=True)
        n += 1
    return n
