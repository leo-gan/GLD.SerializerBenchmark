"""Dimension contract: Data Set on every type, Standard from the compliance catalog."""

from __future__ import annotations

from pathlib import Path

import pytest

from benchmark_analysis.dimensions import (
    DimensionError,
    data_set_for_type,
    load_dimensions,
    load_standards,
    optional_io_index,
    standard_for,
)
from benchmark_analysis.run_config_v2 import load_catalog, resolve_type_config

_REPO = Path(__file__).resolve().parents[2]
_CATALOG = _REPO / "schemas" / "data_catalog_v2.yaml"

SUITE = {"message", "document", "telemetry", "strings", "event"}
COLUMNAR = {"table", "table_project", "nested_table", "signal"}


def test_each_type_has_one_data_set():
    catalog = load_catalog(_CATALOG)
    dims = load_dimensions()
    allowed = set(dims["data_sets"]["ids"])
    found = {}
    for type_id in catalog["types"]:
        found[type_id] = data_set_for_type(type_id, catalog)
    assert set(found) == SUITE | COLUMNAR
    assert set(found.values()) <= allowed
    assert {k for k, v in found.items() if v == "suite"} == SUITE
    assert {k for k, v in found.items() if v == "columnar"} == COLUMNAR


def test_data_set_is_not_part_of_the_type_config_hash():
    catalog = load_catalog(_CATALOG)
    resolved = resolve_type_config("message", {}, catalog)
    assert "data_set" not in resolved


def test_standard_single_and_empty_and_primary():
    standards = load_standards()
    dims = load_dimensions()
    assert standard_for("c", "yyjson", standards, dims) == "json"
    assert standard_for("c", "custom-binary", standards, dims) == "custom"
    assert standard_for("csharp", "MS Bond Json", standards, dims) == "json"
    assert standard_for("python", "pickle", standards, dims) == "custom"


def test_missing_serializer_is_an_error():
    with pytest.raises(DimensionError, match="no standard entry"):
        standard_for("c", "not-a-serializer")


def test_unknown_type_is_an_error():
    with pytest.raises(DimensionError, match="unknown type"):
        data_set_for_type("not-a-type", load_catalog(_CATALOG))


def test_opt_in_rows_name_real_serializers():
    standards = load_standards()
    dims = load_dimensions()
    index = optional_io_index(dims)
    assert len(index) == len(dims["optional_io"]["opt_in"])
    excluded = set(dims["optional_io"]["excluded_languages"])
    for (language, serializer), row in index.items():
        assert language not in excluded
        assert row["level"] in ("stream", "string")
        assert row["stream_mode"] in ("native", "text_on_stream")
        # The name is in the compliance catalog, so the label join will succeed.
        standard_for(language, serializer, standards, dims)
    assert dims["optional_io"]["parent_when_same_size"] == "average"
    assert dims["optional_io"]["parent_when_base64"] == "raw_bytes"
    assert dims["optional_io"]["standard_filter_default"] == "all"
    assert dims["optional_io"]["threshold_percent"] == 10
