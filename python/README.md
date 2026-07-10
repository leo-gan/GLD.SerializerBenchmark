# Python Serializer Benchmark

Dockerized harness evaluating **16 Python serializers** with the same CSV schema and dual-mode (bytes / stream) methodology as the other language suites.

Serializer inventory: [docs/python/index.md](../docs/python/index.md).

## Serializer Groups

| Group | Serializers | Notes |
| :--- | :--- | :--- |
| **JSON** | `json`, `orjson`, `msgspec`, `rapidjson`, `pydantic`, `mashumaro`, `serpyco-rs` | Text-based; typed stacks use prepare/prepare_data. |
| **Binary** | `msgpack`, `msgspec-msgpack`, `cbor2` | Compact binary, schema-optional. |
| **Schema** | `protobuf`, `avro`, `flatbuffers` | Requires schemas / codegen (flatc for FlatBuffers). |
| **Python-native** | `pickle`, `cloudpickle`, `dill` | Language-native pickle family. |

## Test data

| Type id | Purpose |
| :--- | :--- |
| **message** | Flat mixed primitives (small POCO). |
| **document** | Nested document with line items. |
| **telemetry** | Numeric bulk / measurements. |
| **strings** | Homogeneous string list (allocation pressure). |
| **event** | Event envelope with attributes. |

Catalog: `schemas/data_catalog_v2.yaml`. Run matrices: `config/library/`.

## Benchmark Dimensions

- **bytes mode**: Serializer produces/consumes `bytes` directly.
- **stream mode**: Serializer writes to/reads from `io.BytesIO`.

Every serializer is tested in **both modes**. Libraries without a native stream API adapt by writing the `bytes` output to `BytesIO`.

## Metrics

| Metric | How It Is Measured | Rationale |
| :--- | :--- | :--- |
| **Throughput (ops/sec)** | `1_000_000_000 / nanoseconds` for serialize, deserialize, and combined. | Same formula as other harnesses. |
| **Latency** | Total elapsed nanoseconds per repetition; **all** indices written to CSV (including warmup index 0). Analysis may exclude warmup. | Raw logs stay complete for re-analysis. |
| **Memory Allocation** | `tracemalloc` peak allocated bytes during each repetition. | C-extension allocations may be under-counted. |
| **Output Size** | `len(bytes)` or `BytesIO.tell()`. | Comparable across languages. |
| **Type Fidelity** | Semantic roundtrip equality score (1.0 = perfect). | Relaxes strict type identity (`datetime` vs ISO string, etc.). |

## Architecture & Design Decisions

### Why a Custom Runner Instead of pytest-benchmark?

1. **Format parity** with the multi-language CSV schema.
2. **Warm-up contract**: every successful rep (including index `0`) is written; analysis drops warmup when configured.
3. **Multi-metric integration** (latency, size, memory, fidelity) without fixture noise.
4. **Bytes vs stream** dual mode is simpler in a standalone loop.

### Semantic equality

Serializers differ in type fidelity (JSON date strings, msgpack list vs tuple, schema classes). The comparer treats logically equal values as success while still catching data loss.

## Running the Benchmarks

### Docker (recommended)

```bash
cd python
./scripts/run-benchmarks.sh smoke
```

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Smoke** | `./scripts/run-benchmarks.sh smoke` | Short matrix from `config/library/smoke.yaml`. |
| **Verify All** | `./scripts/run-benchmarks.sh all-single` | 10 reps, all serializers, full type matrix. |
| **Full Run** | `./scripts/run-benchmarks.sh full` | 100 repetitions. |
| **Research** | `./scripts/run-benchmarks.sh research` | 500 repetitions. |
| **Custom** | `./scripts/run-benchmarks.sh custom 50 "json" "message"` | Custom reps and name filters. |

Logs under monorepo `logs/python/`:

- `YYYY-MM-DD-HHMMSS.csv` — per-repetition metrics
- `YYYY-MM-DD-HHMMSS.errors.csv` — only when errors occur
- `YYYY-MM-DD-HHMMSS.configs.json` — run config / environment sidecar

Override logs root with `LOG_DIR` / `BENCHMARK_LOG_DIR` (results go to `$LOG_DIR/python/`).

### Local (without Docker)

Python 3.12+ and [uv](https://docs.astral.sh/uv/):

```bash
cd python
uv sync
uv run python -m benchmark.runner 100
```

```
python -m benchmark.runner <repetitions> [serializerFilter] [dataFilter]
```

Examples:

```bash
uv run python -m benchmark.runner 100
uv run python -m benchmark.runner 10 "json" "message"
uv run python -m benchmark.runner 1 "msgpack" ""
```

## Extending the Suite

### Add a serializer

1. Implement `Serializer` in `src/benchmark/serializers/`.
2. Register in `ALL_SERIALIZERS` (`runner_v2` / package entry).
3. Add dependency to `pyproject.toml` and `uv sync`.

### Add a fixture type

1. Catalog entry in `schemas/data_catalog_v2.yaml` and run config cells.
2. Generator / models under `src/benchmark/data_v2/`.
3. Schema mappings (protobuf, avro, …) as needed.

## Results & Analysis

CSV columns include language, mode, type id, serializer, version, timings (ns), size, fidelity, and optional batch/hash columns.

```bash
analyze-benchmarks -l python
```

See root README and [Benchmark architecture](../docs/analysis/architecture.md).

---

*Authored by Leonid Ganeline*
