# Python Serializer Benchmark

A Dockerized benchmarking suite evaluating **16 Python serializers** across 7 realistic data structures, designed to match the methodology and output format of the companion [.NET (C#) benchmark](../c-sharp/).

Serializer inventory: [docs/python/index.md](../docs/python/index.md).

## Serializer Groups

| Group | Serializers | Notes |
| :--- | :--- | :--- |
| **JSON** | `json`, `orjson`, `msgspec`, `rapidjson`, `pydantic`, `mashumaro`, `serpyco-rs` | Text-based; typed stacks use prepare/prepare_data. |
| **Binary** | `msgpack`, `msgspec-msgpack`, `cbor2` | Compact binary, schema-optional. |
| **Schema** | `protobuf`, `avro`, `flatbuffers` | Requires schemas / codegen (flatc for FlatBuffers). |
| **Python-native** | `pickle`, `cloudpickle`, `dill` | Language-native; cycles only here. |


## Test Data Scenarios

| Test Class | Purpose & Stress Points |
| :--- | :--- |
| **Person** | Nested objects, enums, strings — the "gold standard" general-use POCO. |
| **Integer** | Primitive throughput ceiling. |
| **Telemetry** | Numeric arrays and high-frequency data; tests binary format efficiency. |
| **SimpleObject** | Minimal overhead baseline. |
| **StringArray** | Array of 100 strings; tests memory allocation and string encoding. |
| **EDI_835** | Deeply nested health-care claim document; tests recursion depth. |
| **ObjectGraph** | Circular references; only `pickle`, `cloudpickle`, and `dill` are expected to pass. |

## Benchmark Dimensions

- **bytes mode** (analogous to C# `string`): Serializer produces/consumes `bytes` directly.
- **stream mode** (analogous to C# `Stream`): Serializer writes to/reads from `io.BytesIO`.

Every serializer is tested in **both modes**, matching C# coverage. For libraries without a native stream API, the benchmark adapts by writing the `bytes` output to `BytesIO`.

## Metrics

| Metric | How It Is Measured | Rationale |
| :--- | :--- | :--- |
| **Throughput (ops/sec)** | `1_000_000_000 / nanoseconds` for serialize, deserialize, and combined. | Same formula as other harnesses (including C#). |
| **Latency** | Total elapsed nanoseconds per repetition, **all** indices written to CSV (including warmup index 0). Analysis may exclude warmup; harness console summary may too. | Raw logs stay complete for re-analysis; per-call p50/p99 omitted to avoid instrumentation overhead. |
| **Memory Allocation** | `tracemalloc` peak allocated bytes during each repetition. | Standard Python heap profiler; documents that C-extension allocations (orjson, msgpack) may be under-counted. |
| **Output Size** | `len(bytes)` in bytes mode; `BytesIO.tell()` in stream mode. | Directly comparable to C# `Size`. |
| **Type Fidelity** | Semantic roundtrip equality score (1.0 = perfect, 0.0 = failure). | Relaxes strict type identity: `datetime` vs ISO string, `tuple` vs `list`, etc., are considered equal if they represent the same logical value. |

## Architecture & Design Decisions

### Why a Custom Runner Instead of pytest-benchmark?

1. **Format Parity**: The C# suite writes a specific CSV schema (`StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser`). A custom runner guarantees identical column layout plus the two Python-specific extensions (`MemoryPeakBytes`, `FidelityScore`).
2. **Warm-up contract**: Every successful rep (including index `0`) is written to the raw CSV. Only the analysis pipeline (`statistics.exclude_warmup`) drops warmup for tables/plots; harness console averages may mirror that for a quick readout without rewriting the file.
3. **Multi-metric Integration**: pytest-benchmark is built around latency only. Adding `tracemalloc` peaks and semantic comparers inside a pytest fixture adds measurement noise and fixture overhead.
4. **Stream vs Bytes Dual Mode**: pytest-benchmark's `benchmark()` fixture expects a callable; orchestrating two distinct APIs (bytes vs stream) with shared error tracking is cleaner in a standalone loop.

### Why `tracemalloc` for Memory?

Python has no direct equivalent to .NET GC allocation counters. `tracemalloc` is the most reliable built-in tool for tracking **Python heap allocations** during a code block. It is well documented that C-extension allocations (e.g., inside `orjson`'s or `msgpack`'s C code) are not captured. This limitation is explicitly noted in the results to avoid misleading comparisons.

### Semantic Equality Instead of Strict Equality

Python serializers vary wildly in type fidelity:
- JSON stores `datetime` as ISO strings.
- `msgpack` converts `tuple` → `list`.
- Schema serializers return generated classes, not the original dataclass.

A *semantic* comparer treats two values as equal if they represent the same logical data, even if Python types differ. This prevents false failures for well-behaved serializers while still catching genuine data loss.

## Running the Benchmarks

### Docker (Recommended)

Ensure [Docker](https://docker.com) is installed.

#### 1. Build and Smoke Test
```bash
cd python
./scripts/run-benchmarks.sh smoke
```

#### 2. Execution Modes

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Smoke** | `./scripts/run-benchmarks.sh smoke` | 2 repetitions of `pickle` on `Person` (matches `config/benchmark_config.yaml`). |
| **Verify All** | `./scripts/run-benchmarks.sh all-single` | 10 repetitions of **all** serializers on all data. |
| **Full Run** | `./scripts/run-benchmarks.sh full` | 100 repetitions of all serializers. |
| **Research** | `./scripts/run-benchmarks.sh research` | 500 repetitions of all serializers. |
| **Custom** | `./scripts/run-benchmarks.sh custom 50 "json" "Person"` | Custom repetitions and filters. |

#### 3. Monitoring Progress
```bash
docker logs -f $(docker ps -lq)
```

#### 4. Results
Logs are saved under the **monorepo root** `logs/python/` (absolute path), even when you run from `python/`:

- `YYYY-MM-DD-HHMMSS.csv` (timestamped): Raw per-repetition metrics.
- `YYYY-MM-DD-HHMMSS.errors.csv`: Per-run failure details (same stem as the result CSV / `.environment.json`). **Only written when at least one error occurred** — clean runs do not create this file.
- `YYYY-MM-DD-HHMMSS.environment.json`: Hardware/OS sidecar (when `benchmark_analysis` is available).

Override the logs **root** with `LOG_DIR` or `BENCHMARK_LOG_DIR` (results go to `$LOG_DIR/python/`). Docker/orchestrator scripts set this to the repo `logs/` mount.

### Local Development (Without Docker)

Requires Python 3.12+ and [uv](https://docs.astral.sh/uv/).

```bash
cd python
uv sync
uv run python -m benchmark.runner 100
```

### CLI Arguments

```
python -m benchmark.runner <repetitions> [serializerFilter] [dataFilter]
```

Examples:
```bash
# 100 reps, all serializers, all data
uv run python -m benchmark.runner 100

# 10 reps, only JSON serializers, only Person
uv run python -m benchmark.runner 10 "json" "Person"

# 1 rep, only binary serializers
uv run python -m benchmark.runner 1 "msgpack" ""
```

## Extending the Suite

### Add a New Serializer

1. Create a file in `src/benchmark/serializers/` implementing `Serializer` from `src/benchmark/serializers/base.py`.
2. Register it in `src/benchmark/runner.py` in `ALL_SERIALIZERS`.
3. Add the dependency to `pyproject.toml` and run `uv sync`.

### Add New Test Data

1. Define a `@dataclass` in `src/benchmark/data/models.py`.
2. Add a generator in `src/benchmark/data/generator.py`.
3. Register the `(name, class)` pair in `src/benchmark/runner.py` in `ALL_TEST_DATA`.
4. Add conversion logic in schema serializers (`protobuf.py`, `avro.py`) if applicable.

## Results & Analysis

The benchmark outputs timestamped files `logs/python/YYYY-MM-DD-HHMMSS.csv` with the following columns:

```
StringOrStream,TestDataName,Repetitions,RepetitionIndex,
SerializerName,TimeSer,TimeDeser,Size,
TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,
MemoryPeakBytes,FidelityScore
```

Aggregate results are printed to stdout after each run in a format aligned with the C# console output.

Analysis and docs snapshots: install `analysis/`, then `analyze-benchmarks` (all languages) or `analyze-benchmarks -l python` (see root README and [Benchmark architecture — Goals](../docs/analysis/architecture.md)). Optional log path: `--logs LANG=PATH`. Write published tables/plots into `docs/analysis/` and `docs/<lang>/results.md` locally and commit; CI does not regenerate them.

---

*Authored by Leonid Ganeline*
