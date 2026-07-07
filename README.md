# Multi-Language Serializer Benchmark

Scientific, multi-language suite for **comparing serialization libraries** under shared fixtures and a common analysis pipeline.

[Serialization 101 & Benchmark Reports](https://leo-gan.github.io/GLD.SerializerBenchmark/) — theory, methodology, serializer overviews, and measured results.

Benchmarks use shared conceptual payloads and publication-oriented statistics.

---

## Who it is for

| Audience | Use case |
|----------|----------|
| **Researchers** | Reproducible methods, CIs, configurable payloads, metrics |
| **Serializer authors** | Compare and measure old vs new version |
| **System integrators** | Find serializers that fit custom payloads and environments |
| **Maintainers** | Add serializers and languages and analyze results without rewriting analysis |

---

## Supported languages

Registered counts (source of truth: language **Overview** pages and [Benchmarks overview](docs/analysis/index.md)):

| Language | Serializers (registered) | Docs |
|----------|--------------------------:|------|
| C# (.NET) | 37 | [Overview](docs/c-sharp/index.md) · [Results](docs/c-sharp/results.md) |
| Python | 16 | [Overview](docs/python/index.md) · [Results](docs/python/results.md) |
| Rust | 15 | [Overview](docs/rust/index.md) · [Results](docs/rust/results.md) |
| C | 12 | [Overview](docs/c/index.md) · [Results](docs/c/results.md) |
| JavaScript (Node) | 12 † | [Overview](docs/javascript/index.md) · [Results](docs/javascript/results.md) |
| Go | 12 | [Overview](docs/go/index.md) · [Results](docs/go/results.md) |

† Optional native builds (for example simdjson) may change the JavaScript inventory; see the overview.

Add a language: [Adding a language](docs/analysis/ADDING_A_LANGUAGE.md).

---

## Documentation map

| Section | Contents |
|---------|----------|
| **[Serialization 101](docs/theory/index.md)** | Trade-offs; [Historical](docs/theory/historical_perspective.md), [Data science](docs/theory/data_science_perspective.md), and [Engineering](docs/theory/engineer_perspective.md) lenses |
| **[Deep dives](docs/theory/deep-dives/index.md)** | Mechanisms: memory layout, encode/decode cost, schemas, evolution, binary families, zero-copy, compression |
| **Language tracks** | Per-language inventories and **Results** (links in the table above) |
| **[Benchmarks](docs/analysis/index.md)** | [Dashboard](https://leo-gan.github.io/GLD.SerializerBenchmark/dashboard/), [categories](docs/analysis/serialization_categories.md), [methodology](docs/analysis/ANALYSIS_METHODOLOGY.md), [architecture](docs/analysis/architecture.md) |

Published tables and plots under `docs/` are **maintainer-committed snapshots**. CI deploys `mkdocs` from that tree; it does not re-run benchmarks. Local runs may differ from the site.

---

## Configuration

| File | Role |
|------|------|
| [`config/benchmark_config.yaml`](config/benchmark_config.yaml) | Master runtime config: modes/reps, enabled languages and runners, statistics defaults, paths, regression threshold, seed |
| [`schemas/test_data_config.json`](schemas/test_data_config.json) | Test-data **shape** knobs (seed should match `reproducibility.random_seed`) |

Shell harnesses read the master config via [`scripts/read-config.py`](scripts/read-config.py); analysis uses `benchmark_analysis.config_loader`.

---

## Quick start

```bash
# Smoke one language
./<lang>/scripts/run-benchmarks.sh smoke

# Orchestrator: all languages or one language
./scripts/run-all-benchmarks.sh --mode all-single
./scripts/run-all-benchmarks.sh --mode full --lang rust

# Analysis package (from analysis/)
cd analysis && uv pip install -e .   # or: pip install -e .
analyze-benchmarks                  # publish snapshot: tables + plots into docs/
analyze-benchmarks -l python
analyze-benchmarks -l python --logs python/logs/python
analyze-benchmarks --compare-a rust:v1 --compare-b rust:v2
```

**Modes** (see config): `smoke` (2 reps) · `all-single` (10) · `full` (100) · `research` (500).

After regenerating results into `docs/analysis/`, review and commit before `publish-docs` deploys the site.

---

## Shared test data

Fixtures include **Person**, **Integer**, **Telemetry**, **SimpleObject**, **StringArray**, **EDI_835**, and **ObjectGraph** (cycles; only graph-capable serializers).

[Test data configuration](docs/analysis/test_data_configuration.md).

---

## Statistics

See [Analysis methodology](docs/analysis/ANALYSIS_METHODOLOGY.md) and the `statistics:` block in the master config.

Harnesses write every successful repetition (including warmup index 0) with no IQR or other post-filter. Only the analysis package applies:

1. Exclude warmup (rep 0) when `statistics.exclude_warmup`
2. IQR outlier filter (all-or-nothing on ser / deser / total)
3. Mean / median / std / MAD / CV / percentiles
4. Bootstrap 95% CI on the mean
5. Cliff's δ and Hedges' g vs the fastest in group
6. Optional Mann–Whitney U with Holm adjustment for A/B versions

---

## Harness contract

- Emit timestamped `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with `Language=<id>`
- Times in **nanoseconds**
- Include **all** successful `RepetitionIndex` values (including 0)

Extensibility: [Benchmark architecture](docs/analysis/architecture.md) · [Adding a language](docs/analysis/ADDING_A_LANGUAGE.md).

---

## License

MIT
