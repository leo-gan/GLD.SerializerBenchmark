"""
CSV logging and console reporting, matching the C# design.

The log format extends the C# CSV with two additional columns:
- MemoryPeakBytes: peak Python heap allocation during the repetition (tracemalloc)
- FidelityScore: 1.0 if roundtrip is semantically equal, 0.0 otherwise
"""

from __future__ import annotations

import csv
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class BenchmarkLog:
    """Single repetition result, analogous to C# Log class."""
    string_or_stream: str = ""
    test_data_name: str = ""
    repetitions: int = 0
    repetition_index: int = 0
    serializer_name: str = ""
    serializer_version: str = ""
    time_ser_ns: int = 0
    time_deser_ns: int = 0
    size_bytes: int = 0
    memory_peak_bytes: int = 0
    fidelity_score: float = 0.0
    # Data Model v2 (optional; empty/0 for v1 rows)
    data_type_instance_count: int = 0
    type_config_hash: str = ""
    size_gzip_bytes: int = 0
    size_zstd_bytes: int = 0
    # B-6 stream honesty (on stream rows)
    native_kind: str = ""
    stream_mode: str = ""
    # B-1 schedule audit (optional)
    run_order: int = -1
    schedule_position: int = -1

    @property
    def time_ser_and_deser_ns(self) -> int:
        return self.time_ser_ns + self.time_deser_ns

    @property
    def op_per_sec_ser(self) -> float:
        return 1_000_000_000.0 / self.time_ser_ns if self.time_ser_ns > 0 else 0.0

    @property
    def op_per_sec_deser(self) -> float:
        return 1_000_000_000.0 / self.time_deser_ns if self.time_deser_ns > 0 else 0.0

    @property
    def op_per_sec_ser_and_deser(self) -> float:
        total = self.time_ser_and_deser_ns
        return 1_000_000_000.0 / total if total > 0 else 0.0


# Full benchmark-runner CSV schema (SerializerVersion immediately after SerializerName).
# Trailing columns are optional Data Model v2 / schedule fields.
CSV_HEADER = [
    "Language",
    "StringOrStream",
    "TestDataName",
    "Repetitions",
    "RepetitionIndex",
    "SerializerName",
    "SerializerVersion",
    "TimeSer",
    "TimeDeser",
    "Size",
    "TimeSerAndDeser",
    "OpPerSecSer",
    "OpPerSecDeser",
    "OpPerSecSerAndDeser",
    "MemoryPeakBytes",
    "FidelityScore",
    "DataTypeInstanceCount",
    "TypeConfigHash",
    "SizeGzip",
    "SizeZstd",
    "NativeKind",
    "StreamMode",
    "RunOrder",
    "SchedulePosition",
]


class LogStorage:
    """Handles CSV write/read, analogous to C# LogStorage.

    Contract: every successful timed repetition is appended as-is, including
    warmup (``RepetitionIndex == 0``). Harnesses must not filter, winsorize,
    or otherwise post-process rows before write. Warmup/outlier policy is
    applied only by the analysis package when building tables and plots.
    """

    def __init__(self, log_file_name: str):
        self._log_file_name = log_file_name
        self._writer: Optional[Any] = None
        self._file_handle: Optional[Any] = None
        self._init_storage()

    def _init_storage(self) -> None:
        os.makedirs(os.path.dirname(self._log_file_name) or ".", exist_ok=True)
        self._file_handle = open(self._log_file_name, "w", newline="", encoding="utf-8")
        self._writer = csv.writer(self._file_handle)
        self._writer.writerow(CSV_HEADER)
        self._file_handle.flush()

    def write(self, log: BenchmarkLog) -> None:
        """Append one raw measurement row (no warmup/outlier filtering)."""
        self._writer.writerow([
            "python",
            log.string_or_stream,
            log.test_data_name,
            log.repetitions,
            log.repetition_index,
            log.serializer_name,
            log.serializer_version or "",
            log.time_ser_ns,
            log.time_deser_ns,
            log.size_bytes,
            log.time_ser_and_deser_ns,
            f"{log.op_per_sec_ser:.6f}",
            f"{log.op_per_sec_deser:.6f}",
            f"{log.op_per_sec_ser_and_deser:.6f}",
            log.memory_peak_bytes,
            f"{log.fidelity_score:.2f}",
            log.data_type_instance_count or "",
            log.type_config_hash or "",
            log.size_gzip_bytes or "",
            log.size_zstd_bytes or "",
            log.native_kind or "",
            log.stream_mode or "",
            log.run_order if log.run_order >= 0 else "",
            log.schedule_position if log.schedule_position >= 0 else "",
        ])
        self._file_handle.flush()

    def read_all(self) -> List[BenchmarkLog]:
        logs: List[BenchmarkLog] = []
        with open(self._log_file_name, "r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                logs.append(BenchmarkLog(
                    string_or_stream=row["StringOrStream"],
                    test_data_name=row["TestDataName"],
                    repetitions=int(row["Repetitions"]),
                    repetition_index=int(row["RepetitionIndex"]),
                    serializer_name=row["SerializerName"],
                    serializer_version=row.get("SerializerVersion") or "",
                    time_ser_ns=int(row["TimeSer"]),
                    time_deser_ns=int(row["TimeDeser"]),
                    size_bytes=int(row["Size"]),
                    memory_peak_bytes=int(float(row["MemoryPeakBytes"] or 0)),
                    fidelity_score=float(row["FidelityScore"] or 0),
                    data_type_instance_count=int(float(row["DataTypeInstanceCount"] or 0))
                    if row.get("DataTypeInstanceCount") not in (None, "")
                    else 0,
                    type_config_hash=row.get("TypeConfigHash") or "",
                    size_gzip_bytes=int(float(row["SizeGzip"] or 0))
                    if row.get("SizeGzip") not in (None, "")
                    else 0,
                    size_zstd_bytes=int(float(row["SizeZstd"] or 0))
                    if row.get("SizeZstd") not in (None, "")
                    else 0,
                    run_order=int(float(row["RunOrder"]))
                    if row.get("RunOrder") not in (None, "")
                    else -1,
                    schedule_position=int(float(row["SchedulePosition"]))
                    if row.get("SchedulePosition") not in (None, "")
                    else -1,
                ))
        return logs

    def close(self) -> None:
        if self._file_handle:
            self._file_handle.close()
            self._file_handle = None


@dataclass
class BenchmarkError:
    """Tracks a single serializer failure, analogous to C# Error."""
    string_or_stream: str = ""
    test_data_name: str = ""
    serializer_name: str = ""
    repetition: int = 0
    error_text: str = ""

    def try_add_to(self, errors: List[BenchmarkError]) -> bool:
        """Add self to errors list if not already present. Returns True if added."""
        for e in errors:
            if (self.string_or_stream == e.string_or_stream
                    and self.test_data_name == e.test_data_name
                    and self.serializer_name == e.serializer_name
                    and self.error_text == e.error_text):
                return False
        errors.append(self)
        return True


def save_errors(errors: List[BenchmarkError], file_name: str) -> None:
    """Write per-run error CSV, or remove/skip the file when there are no errors.

    Clean runs must not leave a header-only ``*.errors.csv`` on disk.
    """
    if not errors:
        if os.path.isfile(file_name):
            os.remove(file_name)
        return

    os.makedirs(os.path.dirname(file_name) or ".", exist_ok=True)
    with open(file_name, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["TestDataName", "SerializerName", "StringOrStream", "Repetition", "ErrorText"])
        for e in errors:
            writer.writerow([
                e.test_data_name,
                e.serializer_name,
                e.string_or_stream,
                e.repetition,
                e.error_text,
            ])


@dataclass
class AggregateResult:
    """Aggregated results across repetitions, analogous to C# AggregateLogs."""
    string_or_stream: str
    test_data_name: str
    serializer_name: str
    op_per_sec_ser_avg: float = 0.0
    op_per_sec_deser_avg: float = 0.0
    op_per_sec_ser_and_deser_avg: float = 0.0
    size_avg: int = 0
    memory_peak_avg: int = 0
    fidelity_avg: float = 0.0


def aggregate_logs(logs: List[BenchmarkLog]) -> Dict[tuple, AggregateResult]:
    """Group logs by (test_data, serializer, mode) and compute averages."""
    from statistics import mean
    results: Dict[tuple, AggregateResult] = {}

    groups: Dict[tuple, List[BenchmarkLog]] = {}
    for log in logs:
        key = (log.test_data_name, log.serializer_name, log.string_or_stream)
        groups.setdefault(key, []).append(log)

    for key, group in groups.items():
        results[key] = AggregateResult(
            string_or_stream=key[2],
            test_data_name=key[0],
            serializer_name=key[1],
            op_per_sec_ser_avg=mean(l.op_per_sec_ser for l in group),
            op_per_sec_deser_avg=mean(l.op_per_sec_deser for l in group),
            op_per_sec_ser_and_deser_avg=mean(l.op_per_sec_ser_and_deser for l in group),
            size_avg=int(mean(l.size_bytes for l in group)),
            memory_peak_avg=int(mean(l.memory_peak_bytes for l in group)),
            fidelity_avg=mean(l.fidelity_score for l in group),
        )

    return results


def print_report(
    repetitions: int,
    results: Dict[tuple, AggregateResult],
    errors: List[BenchmarkError],
    test_data_names: List[str],
    serializer_names: List[str],
) -> None:
    """Console report matching C# output style."""
    print(f"\n\nTests performed {repetitions} times for each TestData + Serializer pair")
    print("#" * 80)

    for td_name in test_data_names:
        print(f"\nTest Data: {td_name}")
        print(
            "Serializer:               Ops/sec Avg:  Ser      Deser   Ser+Deser  Size: Avg  Memory  Fidelity"
        )
        print("=" * 95)

        for ser_name in serializer_names:
            # Only show modes that were actually run (or errors recorded).
            modes_present = sorted(
                {
                    m
                    for (td, sn, m) in results
                    if td == td_name and sn == ser_name
                }
                | {
                    e.string_or_stream
                    for e in errors
                    if e.test_data_name == td_name and e.serializer_name == ser_name
                }
            )
            if not modes_present:
                # No data and no errors for this pair — skip row (e.g. unsupported).
                continue
            for mode in modes_present:
                key = (td_name, ser_name, mode)
                if key in results:
                    r = results[key]
                    print(
                        f"{ser_name:<21} {mode:<6}   "
                        f"{r.op_per_sec_ser_avg:>12,.0f} "
                        f"{r.op_per_sec_deser_avg:>10,.0f} "
                        f"{r.op_per_sec_ser_and_deser_avg:>10,.0f} "
                        f"{r.size_avg:>10,} "
                        f"{r.memory_peak_avg:>8,} "
                        f"{r.fidelity_avg:>8.2f}"
                    )
                else:
                    print(
                        f"{ser_name:<21} {mode:<6}   "
                        f"{'FAILED':>12} {'FAILED':>10} {'FAILED':>10} "
                        f"{'FAILED':>10} {'FAILED':>8} {'FAILED':>8}"
                    )

        # Print errors for this test data
        td_errors = [e for e in errors if e.test_data_name == td_name]
        if td_errors:
            print(f"\nErrors in {td_name}")
            print("." * 80)
            for e in sorted(td_errors, key=lambda x: x.serializer_name):
                print(f"{e.serializer_name:<21} -{e.string_or_stream:<6}s \n\t{e.error_text}")
