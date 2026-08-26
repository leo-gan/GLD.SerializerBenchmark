"""LogStorage write/read, aggregate_logs, and error dedup."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.report import (
    BenchmarkError,
    BenchmarkLog,
    LogStorage,
    aggregate_logs,
)


def _sample_log(**overrides) -> BenchmarkLog:
    row = BenchmarkLog(
        string_or_stream="bytes",
        test_data_name="message",
        repetitions=3,
        repetition_index=1,
        serializer_name="orjson",
        serializer_version="3.10.0",
        time_ser_ns=1_000,
        time_deser_ns=2_000,
        size_bytes=40,
        memory_peak_bytes=100,
        fidelity_score=1.0,
        data_type_instance_count=1,
        type_config_hash="abc",
        size_gzip_bytes=20,
        size_zstd_bytes=18,
        native_kind="dict",
        stream_mode="adapted",
        run_order=4,
        schedule_position=2,
    )
    for key, value in overrides.items():
        setattr(row, key, value)
    return row


def test_log_storage_write_read_roundtrip(tmp_path: Path):
    path = tmp_path / "run.csv"
    storage = LogStorage(str(path))
    storage.write(_sample_log())
    rows = storage.read_all()
    storage.close()

    assert len(rows) == 1
    got = rows[0]
    assert got.string_or_stream == "bytes"
    assert got.test_data_name == "message"
    assert got.serializer_name == "orjson"
    assert got.serializer_version == "3.10.0"
    assert got.time_ser_ns == 1_000
    assert got.time_deser_ns == 2_000
    assert got.size_bytes == 40
    assert got.memory_peak_bytes == 100
    assert got.fidelity_score == 1.0
    assert got.data_type_instance_count == 1
    assert got.type_config_hash == "abc"
    assert got.size_gzip_bytes == 20
    assert got.size_zstd_bytes == 18
    assert got.native_kind == "dict"
    assert got.stream_mode == "adapted"
    assert got.run_order == 4
    assert got.schedule_position == 2


def test_aggregate_logs_groups_and_averages():
    logs = [
        _sample_log(time_ser_ns=1_000, time_deser_ns=2_000, size_bytes=10, memory_peak_bytes=100),
        _sample_log(time_ser_ns=3_000, time_deser_ns=6_000, size_bytes=30, memory_peak_bytes=300),
        _sample_log(serializer_name="cbor2", time_ser_ns=5_000, time_deser_ns=5_000, size_bytes=8),
    ]
    results = aggregate_logs(logs)
    orjson = results[("message", "orjson", "bytes")]
    assert orjson.size_avg == 20
    assert orjson.memory_peak_avg == 200
    assert orjson.op_per_sec_ser_avg == (1_000_000.0 + 1_000_000.0 / 3) / 2
    assert ("message", "cbor2", "bytes") in results
    assert len(results) == 2


def test_try_add_to_dedups_same_error():
    errors: list[BenchmarkError] = []
    first = BenchmarkError(
        string_or_stream="bytes",
        test_data_name="message",
        serializer_name="orjson",
        repetition=1,
        error_text="boom",
    )
    same = BenchmarkError(
        string_or_stream="bytes",
        test_data_name="message",
        serializer_name="orjson",
        repetition=2,
        error_text="boom",
    )
    other = BenchmarkError(
        string_or_stream="bytes",
        test_data_name="message",
        serializer_name="orjson",
        repetition=3,
        error_text="different",
    )
    assert first.try_add_to(errors) is True
    assert same.try_add_to(errors) is False
    assert other.try_add_to(errors) is True
    assert len(errors) == 2
