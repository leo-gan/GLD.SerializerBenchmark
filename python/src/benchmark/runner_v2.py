"""
Data Model v2 benchmark runner (Python pilot).

Usage:
    python -m benchmark.runner_v2 [repetitions] [serializerFilter] [dataFilter]
    BENCHMARK_RUN_CONFIG=config/library/smoke.yaml python -m benchmark.runner_v2 2

Env:
    BENCHMARK_RUN_CONFIG  path to run config YAML (default: config/library/default.yaml)
    BENCHMARK_SEED        int seed (default: 42)
    LOG_DIR               logs root
"""

from __future__ import annotations

import datetime
import gzip
import io
import json
import os
import sys
import time
import tracemalloc
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .comparer import compare
from .data_v2.fidelity import fidelity_v2
from .data_v2.generator import instances_for_cell
from .data_v2 import protobuf_bridge
from .report import BenchmarkError, BenchmarkLog, LogStorage, aggregate_logs, print_report, save_errors
from .serializers import (
    AvroSerializer,
    Cbor2Serializer,
    CloudpickleSerializer,
    DillSerializer,
    FlatBuffersSerializer,
    MashumaroSerializer,
    MsgpackSerializer,
    MsgspecMessagePackSerializer,
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

# Keep all serializers registered; Avro/FlatBuffers need v2 schemas (supports may skip).
ALL_SERIALIZERS = [
    StdlibJsonSerializer(),
    OrjsonSerializer(),
    MsgspecSerializer(),
    RapidjsonSerializer(),
    PydanticSerializer(),
    MashumaroSerializer(),
    SerpycoSerializer(),
    MsgspecMessagePackSerializer(),
    MsgpackSerializer(),
    Cbor2Serializer(),
    ProtobufSerializer(),
    AvroSerializer(),
    FlatBuffersSerializer(),
    PickleSerializer(),
    CloudpickleSerializer(),
    DillSerializer(),
]


def _repo_root():
    env = (os.environ.get("BENCHMARK_REPO_ROOT") or "").strip()
    if env:
        ep = Path(env).expanduser().resolve()
        if (ep / "schemas" / "data_catalog_v2.yaml").is_file() or (
            ep / "config" / "benchmark_config.yaml"
        ).is_file():
            return ep
    for p in Path(__file__).resolve().parents:
        if (p / "config" / "benchmark_config.yaml").is_file():
            return p
        if (p / "schemas" / "data_catalog_v2.yaml").is_file() and (
            p / "config" / "library"
        ).is_dir():
            return p
    return None


def _default_log_dir():
    env_root = (os.environ.get("LOG_DIR") or os.environ.get("BENCHMARK_LOG_DIR") or "").strip()
    if env_root:
        root = Path(env_root).expanduser()
        if root.name == "python":
            return root.resolve()
        return (root / "python").resolve()
    repo = _repo_root()
    if repo is not None:
        return (repo / "logs" / "python").resolve()
    return (Path.cwd() / "logs" / "python").resolve()


def _load_resolved(run_config: Path, seed: int) -> dict:
    root = _repo_root()
    analysis_src = (root / "analysis" / "src") if root else None
    if analysis_src and analysis_src.is_dir():
        s = str(analysis_src)
        if s not in sys.path:
            sys.path.insert(0, s)
    from benchmark_analysis.run_config_v2 import resolve_run_config

    catalog = (root / "schemas" / "data_catalog_v2.yaml") if root else None
    return resolve_run_config(run_config, catalog_path=catalog, seed=seed)


def _compress_sizes(raw: bytes) -> Tuple[int, int]:
    gz = len(gzip.compress(raw, compresslevel=6))
    zstd_len = 0
    try:
        import zstandard as zstd  # type: ignore

        zstd_len = len(zstd.ZstdCompressor(level=3).compress(raw))
    except Exception:
        try:
            # optional: brotli not required; leave 0 if no zstd
            pass
        except Exception:
            pass
    return gz, zstd_len


def _pack_payload(instances: list, n: int) -> Any:
    if n == 1:
        return instances[0]
    return instances


def _prepare_for_serializer(
    serializer: Serializer,
    type_id: str,
    instances: list,
    n: int,
) -> Tuple[Any, Any, type]:
    """Return (serializable, expected_for_fidelity, type_hint)."""
    payload = _pack_payload(instances, n)
    name = serializer.name.lower()

    if name == "protobuf":
        if not protobuf_bridge.available():
            raise RuntimeError("v2 protobuf stubs missing; run scripts/schemas/generate-all.sh")
        batch = n > 1
        cls = protobuf_bridge.message_class_for(type_id, batch=batch)
        if cls is None:
            raise TypeError(f"No v2 protobuf mapping for {type_id} batch={batch}")
        # Do not call prepare() — v1 TYPE_MAP has no v2 models; set msg class directly.
        serializer._test_data_name = type_id  # type: ignore[attr-defined]
        serializer._msg_cls = cls  # type: ignore[attr-defined]
        src = instances if batch else instances[0]
        native = protobuf_bridge.to_pb(src)
        return native, payload, type(instances[0])

    # Generic path: dataclass or list of dataclasses
    tip = type(instances[0]) if instances else dict
    serializer.prepare(type_id, tip if n == 1 else list)
    serializable = serializer.prepare_data(payload, type_id, tip if n == 1 else list)
    return serializable, payload, tip if n == 1 else list


def run_v2(
    repetitions: int = 100,
    serializer_filter: Optional[str] = None,
    data_filter: Optional[str] = None,
    log_dir: Optional[str] = None,
    run_config_path: Optional[str] = None,
    seed: Optional[int] = None,
) -> Path:
    root = _repo_root()
    if run_config_path is None:
        run_config_path = os.environ.get("BENCHMARK_RUN_CONFIG") or (
            str(root / "config" / "library" / "default.yaml") if root else "config/library/default.yaml"
        )
    if seed is None:
        seed = int(os.environ.get("BENCHMARK_SEED") or "42")

    resolved = _load_resolved(Path(run_config_path), seed)
    cells = resolved["cells"]
    if data_filter:
        cells = [c for c in cells if data_filter.lower() in c["type_id"].lower()]

    serializers = [
        s
        for s in ALL_SERIALIZERS
        if serializer_filter is None or serializer_filter.lower() in s.name.lower()
    ]

    if not serializers or not cells:
        print("No cells or serializers matched.")
        return Path(".")

    # Budget ladder (soft)
    soft = 60 * ((len(serializers) + 9) // 10)
    hard = int((resolved.get("budget") or {}).get("hard_cap_seconds") or 600)
    reps_fb = int((resolved.get("budget") or {}).get("reps_fallback") or 50)
    t_start = time.monotonic()
    if repetitions > reps_fb and len(serializers) * len(cells) * 2 * repetitions > 50_000:
        # heuristic: large matrix → start at fallback reps
        print(f"[PROGRESS] Large matrix; using reps_fallback={reps_fb} (was {repetitions})")
        repetitions = reps_fb

    ts = os.environ.get("BENCHMARK_TS") or datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
    os.environ["BENCHMARK_TS"] = ts
    log_dir_path = Path(log_dir).expanduser().resolve() if log_dir else _default_log_dir()
    log_dir_path.mkdir(parents=True, exist_ok=True)
    ts_file = log_dir_path / f"{ts}.csv"
    error_file = log_dir_path / f"{ts}.errors.csv"
    storage = LogStorage(str(ts_file))
    errors: List[BenchmarkError] = []

    print(f"[PROGRESS] Data Model v2 run config={resolved['run_config']['path']}")
    print(f"[PROGRESS] cells={len(cells)} serializers={len(serializers)} reps={repetitions}")
    print(f"[PROGRESS] soft_budget≈{soft}s hard_cap={hard}s → {ts_file}")

    io_modes = (resolved.get("execution") or {}).get("io_modes") or ["bytes", "stream"]
    compress_mode = (resolved.get("compression") or {}).get("mode") or "none"

    for cell in cells:
        type_id = cell["type_id"]
        n = int(cell["data_type_instance_count"])
        cfg = cell["type_config"]
        th = cell["type_config_hash"]
        print(f"\n[PROGRESS] Cell {type_id} N={n} hash={th}")

        instances = instances_for_cell(type_id, cfg, seed=seed, data_type_instance_count=n)

        for serializer in serializers:
            if time.monotonic() - t_start > hard:
                print(f"[ERROR] Hard cap {hard}s exceeded; stopping.")
                break
            if not serializer.supports(type_id):
                continue
            try:
                serializable, expected, tip = _prepare_for_serializer(
                    serializer, type_id, instances, n
                )
            except Exception as exc:
                err = BenchmarkError(
                    string_or_stream="bytes",
                    test_data_name=type_id,
                    serializer_name=serializer.name,
                    repetition=0,
                    error_text=f"prepare: {type(exc).__name__}: {exc}",
                )
                err.try_add_to(errors)
                continue

            size_gz = size_zstd = 0
            if compress_mode == "size_only":
                try:
                    raw = serializer.serialize_bytes(serializable)
                    size_gz, size_zstd = _compress_sizes(raw)
                except Exception:
                    pass

            for mode in io_modes:
                _run_reps_v2(
                    serializer,
                    serializable,
                    expected,
                    type_id,
                    tip,
                    repetitions,
                    mode,
                    storage,
                    errors,
                    data_type_instance_count=n,
                    type_config_hash=th,
                    size_gzip=size_gz,
                    size_zstd=size_zstd,
                )
            save_errors(errors, str(error_file))
        else:
            continue
        break  # hard cap outer

    storage.close()
    logs = storage.read_all()
    console_logs = logs if repetitions == 1 else [l for l in logs if l.repetition_index != 0]
    results = aggregate_logs(console_logs)
    print_report(
        repetitions,
        results,
        errors,
        sorted({c["type_id"] for c in cells}),
        [s.name for s in serializers],
    )

    # Sidecar
    try:
        from benchmark_analysis.environment import capture_environment

        capture_environment(
            str(ts_file),
            extra={
                "data_model_version": 2,
                "run_config": resolved["run_config"],
                "dataset": {
                    "seed": seed,
                    "cells": resolved["cells"],
                    "compression": resolved.get("compression"),
                    "execution": resolved.get("execution"),
                },
                "serializers": [{"name": s.name, "version": s.version} for s in serializers],
            },
        )
        print(f"[PROGRESS] Sidecar → {ts_file.with_suffix('.configs.json')}")
    except Exception as e:
        # Fallback write dataset-only sidecar
        side = ts_file.with_suffix(".configs.json")
        payload = {
            "data_model_version": 2,
            "run_config": resolved["run_config"],
            "dataset": {"seed": seed, "cells": resolved["cells"]},
            "note": f"environment capture failed: {e}",
        }
        side.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"[WARN] Wrote partial sidecar: {e}")

    elapsed = time.monotonic() - t_start
    print(f"\n[PROGRESS] v2 complete in {elapsed:.1f}s → {ts_file}")
    return ts_file


def _run_reps_v2(
    serializer: Serializer,
    serializable: Any,
    expected: Any,
    td_name: str,
    td_cls: type,
    repetitions: int,
    mode: str,
    storage: LogStorage,
    errors: List[BenchmarkError],
    *,
    data_type_instance_count: int,
    type_config_hash: str,
    size_gzip: int,
    size_zstd: int,
) -> None:
    was_error = False
    cached_memory_peak = 0
    for i in range(repetitions):
        log = BenchmarkLog(
            string_or_stream=mode,
            test_data_name=td_name,
            repetitions=repetitions,
            repetition_index=i,
            serializer_name=serializer.name,
            serializer_version=serializer.version,
            data_type_instance_count=data_type_instance_count,
            type_config_hash=type_config_hash,
            size_gzip_bytes=size_gzip,
            size_zstd_bytes=size_zstd,
        )
        try:
            measure_memory = not was_error and cached_memory_peak == 0
            _single_v2(
                serializer,
                serializable,
                expected,
                mode,
                log,
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


def _single_v2(
    serializer: Serializer,
    serializable: Any,
    expected: Any,
    mode: str,
    log: BenchmarkLog,
    *,
    measure_memory: bool,
) -> None:
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
                blob = serializer.serialize_bytes(serializable)
                serializer.deserialize_bytes(blob)
            else:
                st = io.BytesIO()
                serializer.serialize_stream(serializable, st)
                serializer.deserialize_stream(st)
            _, peak = tracemalloc.get_traced_memory()
            log.memory_peak_bytes = peak
        finally:
            tracemalloc.stop()
    else:
        log.memory_peak_bytes = 0

    score = fidelity_v2(expected, processed)
    if score < 1.0:
        # fall back to generic comparer for dict-like
        ok, err = compare(expected, processed)
        score = 1.0 if ok else 0.0
        if not ok:
            raise RuntimeError(f"Roundtrip mismatch: {err}")
    log.fidelity_score = score


def main() -> None:
    args = sys.argv[1:]
    # Optional: --config path
    run_config = None
    filtered: List[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--config" and i + 1 < len(args):
            run_config = args[i + 1]
            i += 2
            continue
        filtered.append(args[i])
        i += 1
    repetitions = int(filtered[0]) if filtered else 2
    serializer_filter = filtered[1] if len(filtered) > 1 else None
    data_filter = filtered[2] if len(filtered) > 2 else None
    run_v2(
        repetitions,
        serializer_filter,
        data_filter,
        run_config_path=run_config,
    )


if __name__ == "__main__":
    main()
