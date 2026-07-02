# Cross-Language Serializer Benchmark

> **[Serialization 101 & Benchmark Reports](https://leo-gan.github.io/GLD.SerializerBenchmark/)** — theory, methodology, and results for senior engineers and data scientists.

Scientific, multi-language benchmark suite for **comparing serialization libraries** fairly: identical conceptual payloads, dual I/O modes (`bytes`/`stream`), nanosecond timing (C# ticks normalized in analysis), and publication-oriented statistics (bootstrap CIs, effect sizes, non-parametric A/B tests).

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

| Language | Harness | Serializers (target) | Logs |
|----------|---------|----------------------|------|
| C# (.NET) | [`c-sharp/`](c-sharp/) | 38 | `logs/csharp/` |
| Python | [`python/`](python/) | 10 | `logs/python/` |
| **Rust** | [`rust/`](rust/) | 12 | `logs/rust/` |
| **C** | [`c/`](c/) | 12 | `logs/c/` |
| **JavaScript (Node)** | [`javascript/`](javascript/) | 11–12 | `logs/javascript/` |

Add more languages via [`docs/analysis/ADDING_A_LANGUAGE.md`](docs/analysis/ADDING_A_LANGUAGE.md).

## Configuration

Most parameters live in **[`config/benchmark_config.yaml`](config/benchmark_config.yaml)** (modes, statistics, languages, CSV schema, paths). Test-data shape/seed: **[`schemas/test_data_config.json`](schemas/test_data_config.json)**.

## Quick start

```bash
# One language (smoke)
./rust/scripts/run-benchmarks.sh smoke
./c/scripts/run-benchmarks.sh smoke
./javascript/scripts/run-benchmarks.sh smoke
./python/scripts/run-benchmarks.sh smoke   # may use Docker
./c-sharp/scripts/run-benchmarks.sh smoke

# All languages
./scripts/run-all-benchmarks.sh --mode all-single

# One language only
./scripts/run-all-benchmarks.sh --mode full --lang rust

# Analysis (install analysis package first)
cd analysis && pip install -e .   # or: uv pip install -e .
# Local scratch (gitignored):
analyze-benchmarks --generate-summary --generate-plots
# Publish snapshot for GitHub Pages (commit docs/analysis/** after review):
analyze-benchmarks --generate-summary --generate-plots

# Serializer version A vs B
analyze-benchmarks --compare-a rust:v1 --compare-b rust:v2
```

Modes: `smoke` (2 reps) · `all-single` (10) · `full` (100) · `research` (500) — see config.

**Published results:** Tables and violin plots on [GitHub Pages](https://leo-gan.github.io/GLD.SerializerBenchmark/) are **maintainer-committed snapshots** under [`docs/analysis/`](docs/analysis/) (generated locally only). CI does not regenerate them. Your own benchmark runs may differ from the site — that is OK.

## Shared test data

- **Person**, **Integer**, **Telemetry**, **SimpleObject**, **StringArray**, **EDI_835**, **ObjectGraph** (cycles; only graph-capable serializers)
- Config: [Test data configuration](docs/analysis/test_data_configuration.md)

## Statistics (analysis)

See [Analysis methodology](docs/analysis/ANALYSIS_METHODOLOGY.md) and `statistics:` in the master config:

1. Exclude warmup (rep 0)
2. IQR outlier filter
3. Mean / median / std / MAD / CV / percentiles
4. Bootstrap 95% CI on the mean
5. Cliff's δ + Hedges' g vs fastest in group
6. Optional Mann–Whitney U + Holm for A/B versions

## Benchmark architecture & extensibility

- [Benchmark architecture](docs/analysis/architecture.md)
- [Adding a language](docs/analysis/ADDING_A_LANGUAGE.md)
- Harness contract: emit timestamped `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with `Language=<id>`, times in **nanoseconds** (except legacy C# ticks)

## Documentation site

Language ecosystem pages (serializer inventories live on each overview):

- [C#](docs/c-sharp/index.md) · [Python](docs/python/index.md)
- [Rust](docs/rust/index.md) · [C](docs/c/index.md) · [JavaScript](docs/javascript/index.md)
- Benchmarks: [analysis overview](docs/analysis/index.md) · per-language [C#](docs/c-sharp/results.md) / [Python](docs/python/results.md) / [Rust](docs/rust/results.md) / [C](docs/c/results.md) / [JavaScript](docs/javascript/results.md) results

The `publish-docs` workflow only runs `mkdocs gh-deploy` from the committed `docs/` tree. Refresh site results by regenerating into `docs/analysis/` locally and committing.

## License

MIT
