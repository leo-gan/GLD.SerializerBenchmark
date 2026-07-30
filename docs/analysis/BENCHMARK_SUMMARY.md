# Benchmark Results

This page is a **table of contents for measured numbers**. Pivot tables and latency charts live on each language’s **Results** page.

Those snapshots are generated on a developer machine and committed into `docs/`. Continuous integration deploys the site; it does **not** re-run analysis. Numbers depend on the machine and the CSV used—re-running elsewhere may differ.

Analysis documentation hub: [Method overview](index.md).

---

## Results by language

| Language | Results snapshot | Inventory (what we measure) |
|----------|------------------|-----------------------------|
| C# | [Results](../c-sharp/results.md) | [Overview](../c-sharp/index.md) |
| Python | [Results](../python/results.md) | [Overview](../python/index.md) |
| Rust | [Results](../rust/results.md) | [Overview](../rust/index.md) |
| C | [Results](../c/results.md) | [Overview](../c/index.md) |
| JavaScript | [Results](../javascript/results.md) | [Overview](../javascript/index.md) |
| Go | [Results](../go/results.md) | [Overview](../go/index.md) |
| Java | [Results](../java/results.md) | [Overview](../java/index.md) |
| C++ | [Results](../cpp/results.md) | [Overview](../cpp/index.md) |
| Swift | [Results](../swift/results.md) | [Overview](../swift/index.md) |

Related (not numbers): [Modes](modes.md) · [Serialization categories](serialization_categories.md) · [Analysis methodology](ANALYSIS_METHODOLOGY.md) · [Benchmark architecture](architecture.md)

---

## Regenerating language snapshots {#regenerating-language-snapshots}

This hub file is **not** rewritten by `analyze-benchmarks`.

You need local CSVs at `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` (gitignored; produced by a benchmark runner or by `./scripts/run-all-benchmarks.sh --mode full`).

```bash
cd analysis && pip install -e .   # once

# All languages (tables + latency charts; this hub stays static)
analyze-benchmarks

# One language only
analyze-benchmarks -l python   # or rust, csharp, c, javascript, go, java, cpp, swift

# Custom log location
analyze-benchmarks -l python --logs python/logs/python
# or: analyze-benchmarks --logs python=python/logs/python
```

| Output | Role |
|--------|------|
| `docs/<lang>/results.md` | Per-language tables and plot embeds |
| `docs/analysis/plots/violin/<lang>_*.png` | Shared latency-distribution images |

By default the CLI writes **both** tables and plots. Commit updated `results.md` and plot paths as needed.

The `publish-docs` workflow only runs `mkdocs gh-deploy` from the committed `docs/` tree—it does **not** re-run analysis or benchmarks.

How stats are computed: [Analysis methodology](ANALYSIS_METHODOLOGY.md).

## Other analysis CLI outputs

| Output | Where |
|--------|--------|
| Language Results + latency charts | `docs/<lang>/results.md`, `docs/analysis/plots/violin/` |
| Version A/B report | `reports/VERSION_COMPARE.md` (`--compare-a` / `--compare-b`) |
| Regression baseline | `reports/baseline.json` by default (`--save-baseline` / `--check-regression`) |

See [Analysis methodology](ANALYSIS_METHODOLOGY.md) for how numbers are computed.
