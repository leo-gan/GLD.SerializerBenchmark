"""Serializer → data set membership is config, and suite stays the default."""

from __future__ import annotations

from pathlib import Path

import pytest

from benchmark_analysis.config_loader import repo_root
from benchmark_analysis.serializer_data_sets import (
    EXACT_COMMA_FILTER_LANGS,
    NONE_FILTER,
    SKIP_FILTER,
    SerializerDataSetError,
    allow_list,
    data_set_for_run_config,
    data_sets_for_serializer,
    default_filter,
    load_serializer_data_sets,
    measures_type,
    parse_serializer_data_sets,
)

_REPO = repo_root()
_LIB = _REPO / "config" / "library"

# The reviewed map. An absent name is suite only and is not listed.
_EXPECTED = {
    "python": {
        "arrow-ipc": ("columnar", "tensor"),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "orc": ("columnar",),
        "orc-uncompressed": ("columnar",),
        "orjson": ("suite", "columnar"),
        "protobuf": ("suite", "columnar"),
        "avro": ("suite", "columnar"),
        "flatbuffers": ("suite", "columnar", "tensor"),
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "pickle": ("suite", "graph"),
        "cloudpickle": ("suite", "graph"),
        "h5py": ("array",),
        "netCDF4": ("array",),
        "adios2": ("array",),
        "gld-kiln": ("suite", "tensor"),
    },
    "cpp": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "orc": ("columnar",),
        "orc-uncompressed": ("columnar",),
        "sbe": ("columnar",),
        "nlohmann_json": ("suite", "columnar"),
        "protobuf": ("suite", "columnar"),
        "flatbuffers": ("suite", "columnar"),
        "avro": ("suite", "columnar"),
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "highfive": ("array",),
        "gld-kiln": ("suite", "tensor"),
    },
    "csharp": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "System.Text.Json": ("suite", "columnar"),
        "Google.Protobuf": ("suite", "columnar"),
        "FlatSharp": ("suite", "columnar"),
        "Apache.Avro": ("suite", "columnar"),
        "PureHDF": ("array",),
        "gld-kiln": ("suite", "tensor"),
    },
    "go": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "sbe": ("columnar",),
        "encoding/json": ("suite", "columnar"),
        "protobuf": ("suite", "columnar"),
        "hamba/avro": ("suite", "columnar"),
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "gld-kiln": ("suite", "tensor"),
    },
    "java": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "orc": ("columnar",),
        "orc-uncompressed": ("columnar",),
        "sbe": ("columnar",),
        "jackson": ("suite", "columnar"),
        "protobuf": ("suite", "columnar"),
        "flatbuffers": ("suite", "columnar"),
        "avro": ("suite", "columnar"),
        "gld-kiln": ("suite", "tensor"),
    },
    "kotlin": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "orc": ("columnar",),
        "orc-uncompressed": ("columnar",),
        "sbe": ("columnar",),
        "kotlinx-json": ("suite", "columnar"),
        "protobuf": ("suite", "columnar"),
        "flatbuffers": ("suite", "columnar"),
        "avro": ("suite", "columnar"),
    },
    "javascript": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "JSON.stringify": ("suite", "columnar"),
        "protobufjs": ("suite", "columnar"),
        "flatbuffers": ("suite", "columnar"),
        "avsc": ("suite", "columnar"),
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "h5wasm": ("array",),
        "gld-kiln": ("suite", "tensor"),
    },
    "rust": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "sbe": ("columnar",),
        "serde_json": ("suite", "columnar"),
        "prost": ("suite", "columnar"),
        "serde_avro_fast": ("suite", "columnar"),
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "hdf5-metno": ("array",),
        "gld-kiln": ("suite", "tensor"),
    },
    "mojo": {
        "arrow-ipc": ("columnar",),
        "parquet": ("columnar",),
        "parquet-uncompressed": ("columnar",),
        "gld-kiln": ("suite", "tensor"),
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "gld-hdf5": ("array",),
    },
    "swift": {
        "dagr-regular": ("suite", "graph"),
        "dagr-frozen": ("suite", "graph"),
        "gld-kiln": ("suite", "tensor"),
    },
    "c": {"hdf5": ("array",), "gld-kiln": ("suite", "tensor")},
    "zig": {"gld-kiln": ("suite", "tensor")},
    "fortran": {
        "hdf5-fortran": ("array",),
        "netcdf-fortran": ("array",),
        "adios2": ("array",),
        "gld-arrow": ("array",),
    },
}


def test_config_matches_the_reviewed_map():
    assert load_serializer_data_sets() == _EXPECTED


def test_absent_names_are_suite_only():
    assert data_sets_for_serializer("python", "dill") == ("suite",)
    assert data_sets_for_serializer("python", "msgspec") == ("suite",)
    assert data_sets_for_serializer("mojo", "gld-netcdf") == ("suite",)
    assert data_sets_for_serializer("mojo", "gld-adios2") == ("suite",)
    assert data_sets_for_serializer("php", "gld-arrow") == ("suite",)
    assert data_sets_for_serializer("zig", "gld-arrow") == ("suite",)
    assert data_sets_for_serializer("go", "linkedin/goavro") == ("suite",)
    assert data_sets_for_serializer("kotlin", "avro4k") == ("suite",)
    assert data_sets_for_serializer("kotlin", "protobuf-kotlin") == ("suite",)
    assert data_sets_for_serializer("rust", "flexbuffers") == ("suite",)
    assert data_sets_for_serializer("csharp", "ProtoBuf") == ("suite",)
    assert "php" not in load_serializer_data_sets()
    assert data_sets_for_serializer("zig", "gld-kiln") == ("suite", "tensor")
    assert data_sets_for_serializer("zig", "gld-arrow") == ("suite",)


def test_packed_dagr_is_not_on_graph_and_protobuf_is_not_on_tensor():
    assert allow_list("python", "graph") == [
        "dagr-regular",
        "dagr-frozen",
        "pickle",
        "cloudpickle",
    ]
    assert measures_type("python", "dagr-frozen-packed", "graph") is False
    assert measures_type("python", "dagr-packed", "graph") is False
    assert measures_type("python", "protobuf", "tensor") is False
    assert measures_type("python", "arrow-ipc", "tensor") is True
    assert measures_type("python", "arrow-ipc", "message") is False
    assert measures_type("python", "flatbuffers", "request") is True
    assert measures_type("python", "flatbuffers", "message") is True
    assert measures_type("mojo", "gld-kiln", "shard") is True
    assert measures_type("mojo", "gld-kiln", "table") is False
    assert measures_type("fortran", "gld-arrow", "grid") is True
    assert measures_type("fortran", "gld-arrow", "message") is False
    assert measures_type("python", "h5py", "grid_window") is True
    assert measures_type("python", "orjson", "table") is True
    assert measures_type("python", "orjson", "grid") is False


def test_specialized_filters_and_suite_skip():
    assert default_filter("python", _LIB / "default.yaml") == SKIP_FILTER
    assert default_filter("rust", _LIB / "smoke.yaml") == SKIP_FILTER
    assert default_filter("mojo", _LIB / "tensor.yaml") == SKIP_FILTER
    assert default_filter("swift", _LIB / "graph.yaml") == SKIP_FILTER
    assert default_filter("c", _LIB / "array.yaml") == SKIP_FILTER
    assert default_filter("php", _LIB / "columnar.yaml") == SKIP_FILTER
    columnar = default_filter("rust", _LIB / "columnar-smoke.yaml")
    assert columnar.split(",") == allow_list("rust", "columnar")
    assert default_filter("fortran", _LIB / "array-smoke.yaml") == (
        "hdf5-fortran,netcdf-fortran,adios2,gld-arrow"
    )
    assert default_filter("java", _LIB / "graph.yaml") == NONE_FILTER
    assert default_filter("go", _LIB / "tensor.yaml") == "gld-kiln"
    assert data_set_for_run_config(_LIB / "columnar.yaml") == "columnar"
    assert data_set_for_run_config(_LIB / "tensor-smoke.yaml") == "tensor"


def test_exact_comma_languages_are_the_ones_that_split_tokens():
    assert EXACT_COMMA_FILTER_LANGS == {
        "csharp",
        "cpp",
        "fortran",
        "go",
        "java",
        "javascript",
        "kotlin",
        "rust",
    }


def test_parse_rejects_unknown_set_empty_list_and_unknown_language():
    known = {"suite", "columnar", "graph", "array", "tensor"}
    langs = {"python"}
    with pytest.raises(SerializerDataSetError, match="unknown data set"):
        parse_serializer_data_sets(
            {"python": {"h5py": ["grid"]}},
            known_sets=known,
            known_langs=langs,
        )
    with pytest.raises(SerializerDataSetError, match="non-empty"):
        parse_serializer_data_sets(
            {"python": {"h5py": []}},
            known_sets=known,
            known_langs=langs,
        )
    with pytest.raises(SerializerDataSetError, match="unknown language"):
        parse_serializer_data_sets(
            {"nope": {"h5py": ["array"]}},
            known_sets=known,
            known_langs=langs,
        )


def test_detector_does_not_treat_config_sh_as_a_shared_bench_input():
    script = (
        Path(__file__).resolve().parents[2]
        / ".grok"
        / "skills"
        / "prepare-pr"
        / "scripts"
        / "detect-changed-langs.sh"
    )
    text = script.read_text(encoding="utf-8")
    assert 'scripts/lib/*' in text
    assert '[[ "$p" == "scripts/lib/config.sh" ]]' in text
    assert "return 1" in text.split('[[ "$p" == "scripts/lib/config.sh" ]]', 1)[1][:200]
