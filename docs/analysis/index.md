# Benchmarks

Empirical comparison of serializers across **C#**, **Python**, **Rust**, **C**, **JavaScript**, and **Go**—shared conceptual payloads, one CSV contract, one analysis pipeline.

This page is the **hub** for the Benchmarks section: what each analysis page is for, and where language inventories and result snapshots live. It is not a second copy of architecture, methodology, or per-library inventories.

---

## Page map (read by role)

| Page | Single job | Start here if you need… |
|------|------------|-------------------------|
| **[Benchmark architecture](architecture.md)** | Suite layout, audiences, harness timing model, config locations | How measurements are *collected* |
| **[Serialization categories](serialization_categories.md)** | Four paradigms and which suite entries fall where | Fair within-paradigm comparisons |
| **[Test data types](test_data_configuration.md)** | Shared fixtures (`Person`, `Telemetry`, …) and size knobs | What `TestDataName` means |
| **[Analysis methodology](ANALYSIS_METHODOLOGY.md)** | Stats pipeline: warmup, outliers, CIs, effect sizes, outputs | How CSVs become tables/plots |
| **[Metrics catalog](METRICS.md)** | Every metric, importance tier, multi-way vs pairwise | What each published number means |
| **[Adding a language](ADDING_A_LANGUAGE.md)** | Checklist to register a new harness | Extending the matrix |
| **[Benchmark Results](BENCHMARK_SUMMARY.md)** | Static links to language **Results** + how to regenerate | Numbers and plots |

Theory ([Serialization](../theory/101/index.md)): [101](../theory/101/index.md) · [201](../theory/201/index.md) · [301](../theory/301/index.md) · [401](../theory/401/index.md).

---

## Languages in this suite

Counts match the **registered inventories on each language Overview** (hand-written source of truth for *what we measure*). Prefer those pages over `languages.*.serializers` in `config/benchmark_config.yaml`, which can lag harness registration.

| Language | Serializers (registered) | Inventory (hand-written SoT) | Results (generated snapshot) |
|----------|--------------------------|------------------------------|------------------------------|
| C# | **37** | [Overview](../c-sharp/index.md) | [Results](../c-sharp/results.md) |
| Python | **16** | [Overview](../python/index.md) | [Results](../python/results.md) |
| Rust | **15** | [Overview](../rust/index.md) | [Results](../rust/results.md) |
| C | **12** | [Overview](../c/index.md) | [Results](../c/results.md) |
| JavaScript | **12** † | [Overview](../javascript/index.md) | [Results](../javascript/results.md) |
| Go | **12** | [Overview](../go/index.md) | [Results](../go/results.md) |

† **JavaScript:** `simdjson` is optional (native addon). If it fails to build, the run still has the other **11** serializers.

- **Inventories** (`docs/<lang>/index.md`) — log names, categories, caveats.  
- **Results** (`docs/<lang>/results.md`) — local pivots and violin embeds; machine-dependent.  
- **Log ids:** harness `Language` column uses `csharp`, `python`, `rust`, `c`, `javascript`, `go` (docs folders may differ, e.g. `c-sharp` for C#).  
- **Regeneration** — [Benchmark Results](BENCHMARK_SUMMARY.md#regenerating-language-snapshots).

Compare serializers **within one language** (and ideally one [category](serialization_categories.md)). Cross-runtime absolute times are directional only—see [methodology limitations](ANALYSIS_METHODOLOGY.md#limitations).
