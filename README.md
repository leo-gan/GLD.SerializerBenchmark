# Multi-Language Serializer Benchmark

Scientific, multi-language suite for **measuring and comparing serialization libraries**.

- [Serialization 101](https://leo-gan.github.io/GLD.SerializerBenchmark/theory/101/) — a starting point for anyone who wants to understand data serialization—students, data scientists, backend engineers, and systems architects.
- [Benchmarks](https://leo-gan.github.io/GLD.SerializerBenchmark/analysis/)
- [📊 Dashboard](https://leo-gan.github.io/GLD.SerializerBenchmark/dashboard/)

---

## Who it is for

| Audience | Use case |
|----------|----------|
| **Computer Science Students** | Theory, history, examples |
| **Researchers** | Reproducible methods, CIs, configurable payloads, metrics |
| **Serializer authors** | Measure, compare, and improve |
| **System integrators** | Find serializers that fit custom payloads and environments |

---

## Supported languages

- [C# (.NET)](https://leo-gan.github.io/GLD.SerializerBenchmark/c-sharp/) — 37 serializers registered
- [Python](https://leo-gan.github.io/GLD.SerializerBenchmark/python/) — 16
- [Rust](https://leo-gan.github.io/GLD.SerializerBenchmark/rust/) — 15
- [C](https://leo-gan.github.io/GLD.SerializerBenchmark/c/) — 19
- [JavaScript](https://leo-gan.github.io/GLD.SerializerBenchmark/javascript/) — 19
- [Go](https://leo-gan.github.io/GLD.SerializerBenchmark/go/) — 12

[Adding a language](https://leo-gan.github.io/GLD.SerializerBenchmark/analysis/ADDING_A_LANGUAGE/).

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
analyze-benchmarks --compare-a rust:2026-07-09-194122 --compare-b rust:latest
```

**Modes**: `smoke` (2 reps) · `all-single` (10) · `full` (100) · `research` (500).

After regenerating results into `docs/analysis/`, review and commit before `publish-docs` deploys the site.

---

## Test data

Suite fixtures (type ids): **message**, **document**, **telemetry**, **strings**, and **event**.

Catalog and defaults: `schemas/data_catalog_v2.yaml`. Run matrices: `config/library/`.  
Docs: [test data configuration](https://leo-gan.github.io/GLD.SerializerBenchmark/analysis/test_data_configuration/), [data model](https://leo-gan.github.io/GLD.SerializerBenchmark/analysis/data_model_v2/).

---

## Statistics

- [Analysis methodology](https://leo-gan.github.io/GLD.SerializerBenchmark/analysis/ANALYSIS_METHODOLOGY/)
- [Metrics](https://leo-gan.github.io/GLD.SerializerBenchmark/analysis/METRICS/)
