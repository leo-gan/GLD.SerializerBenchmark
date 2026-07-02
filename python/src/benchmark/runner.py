"""
Custom benchmark runner, matching the C# design.

Usage:
    python -m benchmark.runner <repetitions> [serializerFilter] [dataFilter]

Arguments:
    repetitions      Number of repetitions per serializer + data pair (default 100).
    serializerFilter Optional substring filter for serializer names.
    dataFilter       Optional substring filter for test data names.

This runner deliberately avoids pytest-benchmark and other frameworks to ensure:
1. Full control over warm-up logic, stream vs bytes modes, and CSV output format.
2. Exact alignment with the C# benchmark columns and aggregation rules.
3. Integration of non-timing metrics (memory allocation, type fidelity).
"""

from __future__ import annotations

import datetime
import io
import os
import sys
import time
import tracemalloc
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def _repo_root() -> Optional[Path]:
    """Locate the monorepo root (directory that contains ``config/benchmark_config.yaml``)."""
    for p in Path(__file__).resolve().parents:
        if (p / "config" / "benchmark_config.yaml").is_file():
            return p
    return None


def _default_log_dir() -> Path:
    """Canonical log directory: ``<repo>/logs/python`` (not cwd-relative).

    Resolution order:
    1. ``LOG_DIR`` / ``BENCHMARK_LOG_DIR`` env (logs *root*, e.g. repo ``logs/`` or
       container ``/app/logs``) → append ``python`` unless the path already ends
       with ``python``.
    2. Monorepo root via ``config/benchmark_config.yaml`` next to this package.
    3. Docker/image layout: parent that has ``src/benchmark`` + ``generated``.
    4. Last resort: ``<cwd>/logs/python`` (absolute).
    """
    env_root = (os.environ.get("LOG_DIR") or os.environ.get("BENCHMARK_LOG_DIR") or "").strip()
    if env_root:
        root = Path(env_root).expanduser()
        if root.name == "python":
            return root.resolve()
        return (root / "python").resolve()

    repo = _repo_root()
    if repo is not None:
        return (repo / "logs" / "python").resolve()

    for p in Path(__file__).resolve().parents:
        if (p / "src" / "benchmark").is_dir() and (p / "generated").is_dir():
            return (p / "logs" / "python").resolve()

    return (Path.cwd() / "logs" / "python").resolve()

from .comparer import compare
from .data.generator import generate_test_data
from .data.models import (
    Claim, EDI835, Gender, GraphNode, Passport, Person,
    PoliceRecord, ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
)
from .report import (
    AggregateResult,
    BenchmarkError,
    BenchmarkLog,
    LogStorage,
    aggregate_logs,
    print_report,
    save_errors,
)
from .serializers import (
    AvroSerializer,
    FlatBuffersSerializer,
    Cbor2Serializer,
    CloudpickleSerializer,
    DillSerializer,
    MashumaroSerializer,
    MsgspecMessagePackSerializer,
    MsgpackSerializer,
    MsgspecSerializer,
    OrjsonSerializer,
    PickleSerializer,
    ProtobufSerializer,
    PydanticSerializer,
    RapidjsonSerializer,
    SerpycoSerializer,
    Serializer,
    StdlibJsonSerializer,
)

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

ALL_SERIALIZERS: List[Serializer] = [
    # JSON
    StdlibJsonSerializer(),
    OrjsonSerializer(),
    MsgspecSerializer(),
    RapidjsonSerializer(),
    PydanticSerializer(),
    MashumaroSerializer(),
    SerpycoSerializer(),
    # Binary
    MsgspecMessagePackSerializer(),
    MsgpackSerializer(),
    Cbor2Serializer(),
    # Schema
    ProtobufSerializer(),
    AvroSerializer(),
    FlatBuffersSerializer(),
    # Native
    PickleSerializer(),
    CloudpickleSerializer(),
    DillSerializer(),
]

ALL_TEST_DATA = [
    ("Person", Person),
    ("Integer", int),
    ("Telemetry", TelemetryData),
    ("SimpleObject", SimpleObject),
    ("StringArray", StringArrayObject),
    ("EDI_835", EDI835),
    ("ObjectGraph", GraphNode),
]


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def run(
    repetitions: int = 100,
    serializer_filter: Optional[str] = None,
    data_filter: Optional[str] = None,
    log_dir: Optional[str] = None,
) -> None:
    """Execute the full benchmark suite.

    Results are written under the monorepo ``logs/python/`` directory by default
    (absolute path), independent of the process working directory. Override with
    ``log_dir=...`` or env ``LOG_DIR`` / ``BENCHMARK_LOG_DIR`` (logs root).
    """
    # Filter
    serializers = [
        s for s in ALL_SERIALIZERS
        if serializer_filter is None or serializer_filter.lower() in s.name.lower()
    ]
    test_data = [
        (name, cls) for name, cls in ALL_TEST_DATA
        if data_filter is None or data_filter.lower() in name.lower()
    ]

    if not serializers or not test_data:
        print("No test data or serializers matched the filters.")
        return

    # Timestamped result file — each run gets its own CSV, never overwritten.
    # Export BENCHMARK_TS so capture_environment (and child tools) see the same stem.
    ts = os.environ.get("BENCHMARK_TS") or datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
    os.environ["BENCHMARK_TS"] = ts
    log_dir_path = Path(log_dir).expanduser().resolve() if log_dir else _default_log_dir()
    log_dir_path.mkdir(parents=True, exist_ok=True)
    print(f"[PROGRESS] Writing results under {log_dir_path}")


    ts_file = log_dir_path / f"{ts}.csv"
    # Per-run errors beside the result CSV (same stem as .environment.json)
    error_file = log_dir_path / f"{ts}.errors.csv"

    log_file = str(ts_file)
    storage = LogStorage(log_file)
    errors: List[BenchmarkError] = []

    for td_name, td_cls in test_data:
        print(f"\n[PROGRESS] Testing Data: {td_name} (Targeting {len(serializers)} serializers, {repetitions} reps)")
        _test_on_data(td_name, td_cls, repetitions, serializers, storage, errors)
        save_errors(errors, str(error_file))

    storage.close()

    # Aggregate and report
    logs = storage.read_all()
    # Exclude warmup (repetition_index == 0) when repetitions > 1, like C#
    filtered = [l for l in logs if repetitions == 1 or l.repetition_index != 0]
    results = aggregate_logs(filtered)

    print_report(
        repetitions,
        results,
        errors,
        [name for name, _ in test_data],
        [s.name for s in serializers],
    )

    # Capture environment metadata beside the result CSV
    try:
        from benchmark_analysis.environment import capture_environment
        capture_environment(str(ts_file))
        print(f"[PROGRESS] Environment captured -> {ts_file.with_suffix('.environment.json')}")
    except ImportError:
        print("[WARN] benchmark_analysis not installed; skipping environment capture")
    except Exception as e:
        print(f"[WARN] Environment capture failed: {e}")

    print(f"\n[PROGRESS] Benchmark Complete. Results saved to {ts_file}")


def _test_on_data(
    td_name: str,
    td_cls: type,
    repetitions: int,
    serializers: List[Serializer],
    storage: LogStorage,
    errors: List[BenchmarkError],
) -> None:
    """Run all serializers against a single test data type."""
    original = generate_test_data(td_name)

    for serializer in serializers:
        if not serializer.supports(td_name):
            continue

        # Pre-build codecs/schemas and convert to library-native values outside timing.
        serializer.prepare(td_name, td_cls)
        serializer_original = serializer.prepare_data(original, td_name, td_cls)

        print(f"[DEBUG] Starting {serializer.name} (bytes)")
        _run_repetitions(
            serializer, serializer_original, original, td_name, td_cls, repetitions, "bytes", storage, errors
        )
        print(f"[DEBUG] Starting {serializer.name} (stream)")
        _run_repetitions(
            serializer, serializer_original, original, td_name, td_cls, repetitions, "stream", storage, errors
        )


def _run_repetitions(
    serializer: Serializer,
    serializable: Any,
    expected: Any,
    td_name: str,
    td_cls: type,
    repetitions: int,
    mode: str,
    storage: LogStorage,
    errors: List[BenchmarkError],
) -> None:
    """Run repetitions for a single serializer + data + mode."""
    was_error = False
    # Memory sampling is deliberately *outside* timed ser/des: tracemalloc active
    # during encode/decode inflates alloc-heavy codecs (fastavro, msgpack, …) by 2–3×.
    # We measure peak once on the first successful rep and reuse for the group.
    cached_memory_peak = 0

    for i in range(repetitions):
        log = BenchmarkLog(
            string_or_stream=mode,
            test_data_name=td_name,
            repetitions=repetitions,
            repetition_index=i,
            serializer_name=serializer.name,
        )

        try:
            measure_memory = not was_error and cached_memory_peak == 0
            _single_test(
                serializer,
                serializable,
                expected,
                mode,
                log,
                td_cls,
                measure_memory=measure_memory,
            )
            if measure_memory:
                cached_memory_peak = log.memory_peak_bytes
            else:
                log.memory_peak_bytes = cached_memory_peak
        except Exception as exc:
            if not was_error:
                err = BenchmarkError(
                    string_or_stream=mode,
                    test_data_name=td_name,
                    serializer_name=serializer.name,
                    repetition=i,
                    error_text=f"{type(exc).__name__}: {exc}",
                )
                err.try_add_to(errors)
                was_error = True
            continue

        if not was_error:
            storage.write(log)


def _single_test(
    serializer: Serializer,
    serializable: Any,
    expected: Any,
    mode: str,
    log: BenchmarkLog,
    td_cls: type,
    *,
    measure_memory: bool = False,
) -> None:
    """Execute one serialization + deserialization + comparison.

    Timing never runs under an active ``tracemalloc`` session. Optional memory
    sampling re-runs the same ser/des once *after* timers (first rep only).
    """
    if mode == "bytes":
        t0 = time.perf_counter_ns()
        data = serializer.serialize_bytes(serializable)
        t1 = time.perf_counter_ns()
        log.time_ser_ns = t1 - t0
        log.size_bytes = len(data)

        t0 = time.perf_counter_ns()
        processed = serializer.deserialize_bytes(data)
        t1 = time.perf_counter_ns()
        log.time_deser_ns = t1 - t0
    else:
        stream = io.BytesIO()

        t0 = time.perf_counter_ns()
        serializer.serialize_stream(serializable, stream)
        t1 = time.perf_counter_ns()
        log.time_ser_ns = t1 - t0
        log.size_bytes = stream.tell()

        t0 = time.perf_counter_ns()
        processed = serializer.deserialize_stream(stream)
        t1 = time.perf_counter_ns()
        log.time_deser_ns = t1 - t0

    if measure_memory:
        tracemalloc.start()
        try:
            if mode == "bytes":
                _blob = serializer.serialize_bytes(serializable)
                serializer.deserialize_bytes(_blob)
            else:
                _stream = io.BytesIO()
                serializer.serialize_stream(serializable, _stream)
                serializer.deserialize_stream(_stream)
            _, peak = tracemalloc.get_traced_memory()
            log.memory_peak_bytes = peak
        finally:
            tracemalloc.stop()
    else:
        log.memory_peak_bytes = 0

    # Semantic comparison (untimed)
    ok, err_text = compare(expected, processed)
    log.fidelity_score = 1.0 if ok else 0.0
    if not ok:
        raise RuntimeError(f"Roundtrip mismatch: {err_text}")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main() -> None:
    args = sys.argv[1:]
    repetitions = int(args[0]) if args else 100
    serializer_filter = args[1] if len(args) > 1 else None
    data_filter = args[2] if len(args) > 2 else None
    run(repetitions, serializer_filter, data_filter)


if __name__ == "__main__":
    main()
