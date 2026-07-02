# Benchmarks

Empirical performance comparison of serializers across **C#**, **Python**, **Rust**, **C**, and **JavaScript**, using shared conceptual payloads and a common CSV + analysis pipeline.

| Language | Serializers (registered) | Inventory (what we measure) | Results (snapshot) |
|----------|--------------------------|----------------------------|--------------------|
| C# | 38 | [Overview](../c-sharp/index.md) | [Results](../c-sharp/results.md) |
| Python | 16 | [Overview](../python/index.md) | [Results](../python/results.md) |
| Rust | 15 | [Overview](../rust/index.md) | [Results](../rust/results.md) |
| C | 11 | [Overview](../c/index.md) | [Results](../c/results.md) |
| JavaScript | 12 | [Overview](../javascript/index.md) | [Results](../javascript/results.md) |

Inventories are the **source of truth for what we measure** (hand-written). Results pages are **generated** local snapshots (pivots + plots).

Suite layout and harness timing model: [Benchmark architecture](architecture.md). Extending languages: [Adding a Language](ADDING_A_LANGUAGE.md).

---

## Regenerating published reports (maintainers)

Requires local CSVs at `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` (gitignored; from harness or
`./scripts/run-all-benchmarks.sh --mode full`).

```bash
cd analysis && pip install -e .   # once

# All languages (tables + violin plots; hub index is static)
analyze-benchmarks

# One language only
analyze-benchmarks -l python

# Custom log location
analyze-benchmarks -l python --logs python/logs/python
# or: analyze-benchmarks --logs python=python/logs/python
```

By default the CLI writes **both** results tables and violin plots (no separate flags).

| Output | Role |
|--------|------|
| `docs/analysis/plots/violin/*.png` | Shared plot assets |
| `docs/<lang>/results.md` | Per-language pivots + plot embeds (`c-sharp`, `python`, `rust`, `c`, `javascript`) |

The hub [Benchmark Results](BENCHMARK_SUMMARY.md) is a **static** hand-maintained index (not overwritten by `analyze-benchmarks`).

The `publish-docs` workflow only runs `mkdocs gh-deploy` from the committed `docs/` tree — it does **not** re-run analysis or benchmarks.

Pivot tables and plots are **not** hand-maintained; regenerate from CSVs and commit.
