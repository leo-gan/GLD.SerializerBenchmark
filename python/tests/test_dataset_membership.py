"""Python runner membership follows serializer_data_sets, by exact name."""

from __future__ import annotations

import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO / "python" / "src"))
sys.path.insert(0, str(_REPO / "analysis" / "src"))

from benchmark.dataset_membership import dataset_allows


def test_python_membership_is_exact():
    assert dataset_allows("orjson", "message") is True
    assert dataset_allows("orjson", "table") is True
    assert dataset_allows("orjson", "grid") is False
    assert dataset_allows("orjson", "tensor") is False
    assert dataset_allows("h5py", "grid") is True
    assert dataset_allows("h5py", "message") is False
    assert dataset_allows("pickle", "graph") is True
    assert dataset_allows("cloudpickle", "graph") is True
    assert dataset_allows("dill", "graph") is False
    assert dataset_allows("dagr-frozen", "graph") is True
    assert dataset_allows("dagr-frozen-packed", "graph") is False
    assert dataset_allows("dagr-packed", "message") is True
    assert dataset_allows("arrow-ipc", "tensor_view") is True
    assert dataset_allows("arrow-ipc", "message") is False
    assert dataset_allows("flatbuffers", "prompt") is True
    assert dataset_allows("gld-kiln", "message") is True
    assert dataset_allows("gld-kiln", "shard") is True
    assert dataset_allows("gld-kiln", "table") is False
    assert dataset_allows("protobuf", "signal") is True
    assert dataset_allows("protobuf", "request") is False
    assert dataset_allows("msgspec", "document") is True
    assert dataset_allows("msgspec", "table") is False
