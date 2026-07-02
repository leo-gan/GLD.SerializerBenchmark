# Benchmarks

Empirical performance comparison of serializers across **C#**, **Python**, **Rust**, **C**, and **JavaScript**, using shared conceptual payloads and a common CSV + analysis pipeline.

| Language | Serializers (registered) | Inventory (what we measure) | Results (snapshot) |
|----------|--------------------------|----------------------------|--------------------|
| C# | 38 | [Overview](../c-sharp/index.md) | [Results](../c-sharp/results.md) |
| Python | 10 | [Overview](../python/index.md) | [Results](../python/results.md) |
| Rust | 12 | [Overview](../rust/index.md) | [Results](../rust/results.md) |
| C | 11 | [Overview](../c/index.md) | [Results](../c/results.md) |
| JavaScript | 12 | [Overview](../javascript/index.md) | [Results](../javascript/results.md) |

Inventories are the **source of truth for what we measure** (hand-written). Results pages are **generated** local snapshots (pivots + plots).

Suite layout and harness timing model: [Benchmark architecture](architecture.md). Extending languages: [Adding a Language](ADDING_A_LANGUAGE.md).

---

## Regenerating published reports (maintainers)

Requires local CSVs at `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` (gitignored; from harness or
`./scripts/run-all-benchmarks.sh --mode full`). Use **both** flags so the hub index,
PNGs, and per-language pages stay in sync:

```bash
cd analysis && pip install -e .   # once
analyze-benchmarks \
```

That writes (commit these for Pages):

| Output | Role |
|--------|------|
| `docs/analysis/BENCHMARK_SUMMARY.md` | Hub **Benchmark Results** (links only) |
| `docs/analysis/plots/violin/*.png` | Shared plot assets |
| `docs/<lang>/results.md` | Per-language pivots + plot embeds (`c-sharp`, `python`, `rust`, `c`, `javascript`) |

Either flag alone still refreshes `docs/<lang>/results.md` from current CSVs, but
By default both results tables and violin plots are written. Use `-l python` (etc.) to limit to one language
`BENCHMARK_SUMMARY.md`. Prefer both flags for a full snapshot.

The CLI writes the hub/PNGs under `reports/` (gitignored) and refreshes `docs/<lang>/results.md` when a sibling `docs/` directory exists.

The `publish-docs` workflow only runs `mkdocs gh-deploy` from the committed `docs/` tree — it does **not** re-run analysis or benchmarks.

Pivot tables and plots are **not** hand-maintained; regenerate from CSVs and commit.
