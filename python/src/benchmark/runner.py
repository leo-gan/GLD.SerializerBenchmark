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

import io
import sys
import time
import tracemalloc
from typing import Any, Dict, List, Optional, Tuple

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
    Cbor2Serializer,
    CloudpickleSerializer,
    MsgspecMessagePackSerializer,
    MsgpackSerializer,
    MsgspecSerializer,
    OrjsonSerializer,
    PickleSerializer,
    ProtobufSerializer,
    RapidjsonSerializer,
    Serializer,
)

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

ALL_SERIALIZERS: List[Serializer] = [
    OrjsonSerializer(),
    MsgspecSerializer(),
    RapidjsonSerializer(),
    MsgspecMessagePackSerializer(),
    MsgpackSerializer(),
    Cbor2Serializer(),
    ProtobufSerializer(),
    AvroSerializer(),
    PickleSerializer(),
    CloudpickleSerializer(),
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
    log_dir: str = "logs/python",
) -> None:
    """Execute the full benchmark suite."""
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

    # Storage
    log_file = f"{log_dir}/benchmark-log.csv"
    error_file = f"{log_dir}/benchmark-errors.csv"
    storage = LogStorage(log_file)
    errors: List[BenchmarkError] = []

    for td_name, td_cls in test_data:
        print(f"\n[PROGRESS] Testing Data: {td_name} (Targeting {len(serializers)} serializers, {repetitions} reps)")
        _test_on_data(td_name, td_cls, repetitions, serializers, storage, errors)
        save_errors(errors, error_file)

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
    print("\n[PROGRESS] Benchmark Complete. Results saved to", log_file)


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

        # Set type hint and let serializers pre-build per-type codecs/schemas outside timing.
        setattr(serializer, "_last_type", td_cls)
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

    for i in range(repetitions):
        log = BenchmarkLog(
            string_or_stream=mode,
            test_data_name=td_name,
            repetitions=repetitions,
            repetition_index=i,
            serializer_name=serializer.name,
        )

        try:
            _single_test(serializer, serializable, expected, mode, log, td_cls)
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
) -> None:
    """Execute one serialization + deserialization + comparison."""
    tracemalloc.start()

    if mode == "bytes":
        # Serialize
        t0 = time.perf_counter_ns()
        data = serializer.serialize_bytes(serializable)
        t1 = time.perf_counter_ns()
        log.time_ser_ns = t1 - t0
        log.size_bytes = len(data)

        # Deserialize
        t0 = time.perf_counter_ns()
        processed = serializer.deserialize_bytes(data)
        t1 = time.perf_counter_ns()
        log.time_deser_ns = t1 - t0
    else:
        stream = io.BytesIO()

        # Serialize
        t0 = time.perf_counter_ns()
        serializer.serialize_stream(serializable, stream)
        t1 = time.perf_counter_ns()
        log.time_ser_ns = t1 - t0
        log.size_bytes = stream.tell()

        # Deserialize
        t0 = time.perf_counter_ns()
        processed = serializer.deserialize_stream(stream)
        t1 = time.perf_counter_ns()
        log.time_deser_ns = t1 - t0

    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    log.memory_peak_bytes = peak

    # Semantic comparison
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
