# Benchmarks

Empirical performance comparison of serializers across **C#**, **Python**, **Rust**, **C**, and **JavaScript**, using shared conceptual payloads and a common CSV + analysis pipeline.

| Language | Harness | Serializers (registered) | Logs |
|----------|---------|--------------------------|------|
| C# | [`c-sharp/`](../../c-sharp/) | 38 | `logs/csharp/` |
| Python | [`python/`](../../python/) | 10 | `logs/python/` |
| Rust | [`rust/`](../../rust/) | 12 | `logs/rust/` |
| C | [`c/`](../../c/) | 12 | `logs/c/` |
| JavaScript | [`javascript/`](../../javascript/) | 11–12 | `logs/javascript/` |

---

## Quick Access

| Report | Description |
|--------|-------------|
| [Serialization Categories](./serialization_categories.md) | How serializers are classified **in this suite** |
| [Analysis Methodology](./ANALYSIS_METHODOLOGY.md) | Statistical methods and data processing pipeline |
| [Test Data Configuration](./test_data_configuration.md) | Test data types and generation rules |
| [Detailed Report](./BENCHMARK_SUMMARY.md) | Generated summary (re-run analysis to refresh) |
| [Performance (violin plots)](./violin-plots.md) | Visualizations of latency distributions |

---

## Generating reports

```bash
cd analysis && pip install -e .
analyze-benchmarks --generate-summary --generate-plots --output-dir ../reports
```

Reports land under `reports/`. Copy or CI may sync artifacts into `docs/analysis/` for the MkDocs site. Top-performer tables are **not** hand-maintained here — regenerate from current CSVs.

---

## Key Findings (qualitative)

- **Binary formats** (MessagePack, Protobuf-style, compact native codecs) often outperform text JSON within a language.
- **Schema-driven** serializers usually achieve smaller payloads by omitting field names.
- **Zero-allocation / zero-copy** techniques (e.g. MemoryPack, FlatSharp, rkyv patterns) reduce GC pressure on managed runtimes.
- Python’s **orjson** and **msgspec** (native extensions) far outperform pure-Python baselines in this suite.
- Some harnesses use **documented stand-ins** (C portable codecs; Rust `prost-wire` / `rkyv` wrappers) — read language caveats before citing numbers in a paper.

---

## Per-language inventories (source of truth for “what we measure”)

- [C#](../c-sharp/index.md) · [Python](../python/index.md) · [Rust](../rust/index.md) · [C](../c/index.md) · [JavaScript](../javascript/index.md)
