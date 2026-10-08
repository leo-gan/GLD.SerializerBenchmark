"""Parent row is one per serializer. Optional I/O is a child list."""

from benchmark_analysis.fold_io import fold_io_groups

DIMS = {
    "optional_io": {
        "base64_size_ratio": 0.75,
        "base64_size_tolerance": 0.05,
        "opt_in": [
            {"language": "go", "serializer": "sonic", "level": "stream", "stream_mode": "native"},
            {"language": "csharp", "serializer": "MemoryPack", "level": "string", "stream_mode": "native"},
            {"language": "csharp", "serializer": "ShapeShift.Json", "level": "stream", "stream_mode": "native"},
        ],
    }
}


def _group(lang, ser, mode, median, size, stream_mode=""):
    group = {
        "language": lang,
        "serializer": ser,
        "test_data": "message",
        "type_config_hash": "abc",
        "data_type_instance_count": 100,
        "mode": mode,
        "standard": "json",
        "data_set": "suite",
        "variants": {
            "iqr_1.5": {
                "total_median_ns": median,
                "total_mean_ns": median,
                "avg_time_total_ns": median,
                "median_size_bytes": size,
                "runs": 99,
                "filter": {"policy": "iqr_1.5"},
            }
        },
    }
    if stream_mode:
        group["StreamMode"] = stream_mode
    return group


def test_same_size_opt_in_averages_and_keeps_both_children():
    groups = [
        _group("go", "sonic", "bytes", 100.0, 40),
        _group("go", "sonic", "stream", 140.0, 40, "native"),
    ]
    folded = fold_io_groups(groups, DIMS)
    assert len(folded) == 1
    parent = folded[0]
    assert parent["io_parent"] == "average"
    assert parent["mode"] == "published"
    assert parent["variants"]["iqr_1.5"]["total_median_ns"] == 120.0
    assert parent["variants"]["iqr_1.5"]["median_size_bytes"] == 40.0
    assert [c["level"] for c in parent["optional"]] == ["bytes", "stream"]
    assert parent["optional"][1]["variants"]["iqr_1.5"]["total_median_ns"] == 140.0


def test_csharp_base64_parent_is_raw_bytes_and_string_is_the_child():
    groups = [
        _group("csharp", "MemoryPack", "string", 40.0, 80),
        _group("csharp", "MemoryPack", "stream", 26.0, 60, "native"),
    ]
    parent = fold_io_groups(groups, DIMS)[0]
    assert parent["io_parent"] == "raw_bytes"
    assert parent["variants"]["iqr_1.5"]["total_median_ns"] == 26.0
    assert parent["variants"]["iqr_1.5"]["median_size_bytes"] == 60.0
    assert len(parent["optional"]) == 1
    assert parent["optional"][0]["level"] == "string"
    assert parent["optional"][0]["variants"]["iqr_1.5"]["median_size_bytes"] == 80.0


def test_non_opt_in_keeps_only_the_in_memory_row():
    groups = [
        _group("python", "orjson", "bytes", 10.0, 20),
        _group("python", "orjson", "stream", 10.2, 20, "adapted"),
    ]
    parent = fold_io_groups(groups, DIMS)[0]
    assert parent["io_parent"] == "in_memory"
    assert parent["optional"] == []
    assert parent["variants"]["iqr_1.5"]["total_median_ns"] == 10.0


def test_csharp_base64_outside_the_opt_in_has_no_child():
    groups = [
        _group("csharp", "FsPickler", "string", 50.0, 80),
        _group("csharp", "FsPickler", "stream", 48.0, 60, "native"),
    ]
    parent = fold_io_groups(groups, DIMS)[0]
    assert parent["io_parent"] == "raw_bytes"
    assert parent["variants"]["iqr_1.5"]["total_median_ns"] == 48.0
    assert parent["optional"] == []


def test_single_level_stays_one_row():
    parent = fold_io_groups([_group("javascript", "JSON.stringify", "bytes", 5.0, 12)], DIMS)[0]
    assert parent["io_parent"] == "single"
    assert parent["optional"] == []
    assert parent["variants"]["iqr_1.5"]["total_median_ns"] == 5.0
