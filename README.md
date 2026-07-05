# Cross-Language Serializer Benchmark

> **[Serialization 101 & Benchmark Reports](https://leo-gan.github.io/GLD.SerializerBenchmark/)** — theory, methodology, and results for senior engineers and data scientists.

Scientific, multi-language benchmark suite for **comparing serialization libraries** fairly: identical conceptual payloads, dual I/O modes (`bytes`/`stream`), nanosecond timing in harness CSVs (all languages including C#; published latency tables use **µs**), and publication-oriented statistics (bootstrap CIs, effect sizes, non-parametric A/B tests).

## Who it is for

Same audiences as [Benchmark architecture — Goals](docs/analysis/architecture.md) (details and examples there):

| Audience | Use case |
|----------|----------|
| **Researchers** | Reproducible methods, CIs, effect sizes, configurable outlier/warmup policy |
| **Serializer authors** | Compare old vs new version: `analyze-benchmarks --compare-a old.csv --compare-b new.csv` |
| **System integrators** | Custom payloads (`schemas/test_data_config.json`) and environments; same CSV + analysis pipeline |
| **Maintainers** | Add languages and publish docs snapshots without rewriting analysis ([Adding a language](docs/analysis/ADDING_A_LANGUAGE.md)) |

Picking a serializer for one runtime (integrator/researcher workflow) uses language **Overview** / **Results** on the [docs site](https://leo-gan.github.io/GLD.SerializerBenchmark/) or a local regen into `docs/analysis`.

## Supported languages

| Language | Serializers (registered) |
|----------|--------------------------|
| C# (.NET) | 38 |
| Python | 16 |
| Rust | 15 |
| C | 19 |
| JavaScript (Node) | 12–13 |
| Go | 12 |

Add more languages via [`docs/analysis/ADDING_A_LANGUAGE.md`](docs/analysis/ADDING_A_LANGUAGE.md).

## Configuration

**Master config (used at runtime):** **[`config/benchmark_config.yaml`](config/benchmark_config.yaml)** — modes/reps, enabled languages + runners, statistics defaults, paths, regression threshold, seed. Shell harnesses read it via [`scripts/read-config.py`](scripts/read-config.py); analysis via `benchmark_analysis.config_loader`. Test-data **shape** knobs: **[`schemas/test_data_config.json`](schemas/test_data_config.json)** (seed should match `reproducibility.random_seed`).

## Quick start

```bash
# One language (smoke)
./rust/scripts/run-benchmarks.sh smoke
./c/scripts/run-benchmarks.sh smoke
./javascript/scripts/run-benchmarks.sh smoke
./go/scripts/run-benchmarks.sh smoke
./python/scripts/run-benchmarks.sh smoke   # may use Docker
./c-sharp/scripts/run-benchmarks.sh smoke

# All languages
./scripts/run-all-benchmarks.sh --mode all-single

# One language only
./scripts/run-all-benchmarks.sh --mode full --lang rust

# Analysis (install analysis package first)
cd analysis && pip install -e .   # or: uv pip install -e .
# Publish snapshot for GitHub Pages (tables + plots; commit docs/ after review):
analyze-benchmarks
# One language only:
analyze-benchmarks -l python
# Custom log path:
analyze-benchmarks -l python --logs python/logs/python

# Serializer version A vs B
analyze-benchmarks --compare-a rust:v1 --compare-b rust:v2
```

Modes: `smoke` (2 reps) · `all-single` (10) · `full` (100) · `research` (500) — see config.

**Published results:** Tables and violin plots on [GitHub Pages](https://leo-gan.github.io/GLD.SerializerBenchmark/) are **maintainer-committed snapshots** under [`docs/analysis/`](docs/analysis/) (generated locally only). CI does not regenerate them. Your own benchmark runs may differ from the site — that is OK.

## Shared test data

- **Person**, **Integer**, **Telemetry**, **SimpleObject**, **StringArray**, **EDI_835**, **ObjectGraph** (cycles; only graph-capable serializers)
- Config: [Test data configuration](docs/analysis/test_data_configuration.md)

## Statistics (analysis)

See [Analysis methodology](docs/analysis/ANALYSIS_METHODOLOGY.md) and `statistics:` in the master config.

**Raw logs are complete:** harnesses write every successful repetition (including warmup index 0) with no IQR or other post-filter. Only the analysis package applies:

1. Exclude warmup (rep 0) when `statistics.exclude_warmup`
2. IQR outlier filter (all-or-nothing on ser/deser/total)
3. Mean / median / std / MAD / CV / percentiles
4. Bootstrap 95% CI on the mean
5. Cliff's δ + Hedges' g vs fastest in group
6. Optional Mann–Whitney U + Holm for A/B versions

## Benchmark architecture & extensibility

- [Benchmark architecture](docs/analysis/architecture.md)
- [Adding a language](docs/analysis/ADDING_A_LANGUAGE.md)
- Harness contract: emit timestamped `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with `Language=<id>`, times in **nanoseconds**, **all** successful `RepetitionIndex` values (including 0)

## Documentation site

Language ecosystem pages (serializer inventories live on each overview):

- [C#](docs/c-sharp/index.md) · [Python](docs/python/index.md)
- [Rust](docs/rust/index.md) · [C](docs/c/index.md) · [JavaScript](docs/javascript/index.md) · [Go](docs/go/index.md)
- Benchmarks: [analysis overview](docs/analysis/index.md) · per-language [C#](docs/c-sharp/results.md) / [Python](docs/python/results.md) / [Rust](docs/rust/results.md) / [C](docs/c/results.md) / [JavaScript](docs/javascript/results.md) / [Go](docs/go/results.md) results

The `publish-docs` workflow only runs `mkdocs gh-deploy` from the committed `docs/` tree. Refresh site results by regenerating into `docs/analysis/` locally and committing.

## License

MIT
