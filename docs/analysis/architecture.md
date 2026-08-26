# Benchmark architecture

This page describes **how the suite is built**: folder layout, who the measurements are for, what is timed, and where configuration lives.

Think of it as the **lab design** for the experiment. How we turn raw timings into tables is covered in [Analysis methodology](ANALYSIS_METHODOLOGY.md).

| If you need… | Go here |
|--------------|---------|
| Statistics (warmup, outliers, confidence intervals) | [Analysis methodology](ANALYSIS_METHODOLOGY.md) |
| Sample data shapes and size knobs | [Test data](test_data_configuration.md) |
| JSON vs binary vs schema families | [Serialization categories](serialization_categories.md) |
| How to add another language | [Adding a language](ADDING_A_LANGUAGE.md) |
| How to add one library to an existing language | [Adding a serializer](ADDING_A_SERIALIZER.md) |
| Published numbers | [Dashboard](../dashboard/) · [Claims and replication](CLAIMS_AND_REPLICATION.md) |

---

## Learning goals

By the end of this page you should be able to:

1. Name the main folders of the repository and what each one is for.
2. Explain the difference between **setup work** and **timed work**.
3. List the rules every language **benchmark runner** (older docs: *harness*) must follow so results stay comparable.
4. Choose a **run mode** (smoke, full, research, …) for your purpose.

---

## One pipeline, four kinds of reader

Everyone uses the **same measurement contract** and the **same analysis path**. What changes is the question you bring:

| Reader | Primary question | How the suite helps |
|--------|------------------|---------------------|
| **Student or researcher** | Are the rankings inside one language trustworthy? | Fixed data types, run modes, warmup exclusion, outlier handling, confidence intervals, effect sizes — see [methodology](ANALYSIS_METHODOLOGY.md) |
| **Library author** | Can I drop in my codec? Did it get better or worse? | [Adding a serializer](ADDING_A_SERIALIZER.md); stable names + `--compare-a` / `--compare-b`; optional regression check |
| **System builder** | What fits *our* data shapes and runtime? | Tunable test-data config, two I/O modes, language inventories, same CSV format for private runs |
| **Maintainer** | Can I add a language without rewriting analysis? | Registry in `benchmark_config.yaml` plus the [Adding a language](ADDING_A_LANGUAGE.md) checklist |

**Typical paths**

- **Publish a snapshot:** run all benchmark runners in `full` mode, run `analyze-benchmarks`, then `python3 dashboard/scripts/sync-data.py` and commit packed Dashboard data.
- **Author A/B test:** two CSVs of the same language → compare with `--compare-a` / `--compare-b`.
- **Private experiment:** change data-type sizes, run one language, keep unpublished reports under `reports/` or pack a local Dashboard.

---

## Repository layout

| Path | Role |
|------|------|
| `config/benchmark_config.yaml` | Run modes, statistics defaults, language list, CSV column schema |
| `schemas/` | Shared data catalog, Protocol Buffers and related wire definitions |
| `logs/<language>/` | Timestamped result CSVs (gitignored; not published as raw files) |
| `analysis/` | Python package that implements the `analyze-benchmarks` command |
| `python/`, `c-sharp/`, `rust/`, `c/`, `javascript/`, `go/`, `java/`, `cpp/`, `swift/` | One benchmark runner per language |
| `docs/` | MkDocs site: theory, inventories, Dashboard, this analysis section |
| `scripts/run-all-benchmarks.sh` | Orchestrates multi-language runs |

Published site numbers are packed **on a developer machine** into `docs/dashboard/data/<lang>_latest.json.gz` via `dashboard/scripts/sync-data.py` (from `reports/stats_<lang>_latest.json`). Continuous integration only deploys the documentation site; it does not re-run the full analysis. See [Claims and replication](CLAIMS_AND_REPLICATION.md).

---

## What we measure {#measurement-model}

A fair timing experiment separates **preparation** (do this once, untimed) from **the loop** (do this many times, timed).

### Step by step

1. **Prepare (not timed)**  
   Load schemas, create codecs, allocate buffers, build the in-memory object the serializer expects. Different languages do this slightly differently; the rule is the same: setup is not timed. **Do not write the output bytes here.** The full contract is **[Timing honesty](TIMING_HONESTY.md)**.

2. **Timed loop** (for each repetition `i`):
   - `serialize(object)` → record **serialize time**
   - `deserialize(bytes)` → record **deserialize time**
   - Check **fidelity** (does the data still mean the same thing?). Failures go to an errors file; a broken round-trip is never treated as a speed win.

3. **Warmup**  
   The first repetition (`i = 0`) is still written to the CSV, but analysis **drops** it from averages. That removes cold-start effects such as just-in-time compilation or first-time cache misses.

### I/O modes (API path, not payload size)

CSV rows also record how the serializer was called:

| Label on the Dashboard | Meaning |
|------------------------|---------|
| **bytes mode** | Work with in-memory byte arrays (or equivalent; C# often uses **string**) |
| **stream mode** | Work through a stream-style API |

These names describe the **programming interface**, not whether the payload is “large” or “small.”

**Full explanation** (why both exist, C# string/Base64, native vs adapted stream, fair comparison): **[Modes](modes.md)**.

---

## Timing rules (suite-wide) {#timing-methodology-suite-wide-issue-59}

These policies keep native and managed languages from accidentally measuring different things (see also issue #59 in the project history).

| Concern | Policy |
|---------|--------|
| **Output buffer** | Prefer a **runner-owned** buffer (or a pre-sized scratch buffer) that is cleared and reused across repetitions. Cold allocation should land in warmup. Document the language’s choice. Do not mix “always allocate fresh” and “reuse buffer” across serializers of the same language without documenting both. |
| **Optimization barriers** | On optimizing native compilers (C, C++, Rust, …), force the compiler to keep timed inputs and outputs “alive” (`black_box`, `DoNotOptimize`, `KeepAlive`, or the language equivalent). Otherwise the compiler may delete the work as unused. |
| **Data-type dispatch** | Bind type-specific encode paths during **prepare** (function pointers, closures, monomorphic helpers). The timed serialize path should not pay for a large `switch`/`match` on data type when the data type is fixed for the whole cell. |
| **Random numbers** | Generation must be deterministic **within one language**. Prefer a well-known pseudo-random generator, seed it from `BENCHMARK_SEED` / `reproducibility.random_seed`, and document magic constants. Cross-language **identical** payloads are **not** required. |
| **Stream capacity floors** | If the runner grows a stream buffer floor across reps, keep it **per serializer**, not shared across codecs (interleaved schedules would otherwise amortize one codec’s growth onto another). |

Rust’s benchmark runner is a useful reference implementation: `rust/README.md` and `rust/src/run_v2.rs`.

---

## Timed-trial schedule (block shuffle) {#timed-trial-schedule}

By default, benchmark runners use **`reproducibility.schedule.strategy: block_shuffle`** so serializer identity is not confounded with wall-clock position (thermal throttling, frequency drift).

### Nesting

```text
for cell in cells:                         # fixed resolve / YAML order
  prepare every eligible serializer        # UNTimed, once per cell
  for mode in io_modes:                    # sequential mode blocks
    for rep in 0 .. repetitions-1:
      order = FisherYates(serializers, seed = H(...))
      for ser in order:
        timed serialize + deserialize
        write CSV row (RepetitionIndex = rep; optional RunOrder)
```

- **Cells** stay outer and fixed (different prepare cost; clear progress/budget).
- **I/O modes** stay sequential blocks (comparisons are within mode).
- **Serializers** are reshuffled **each rep** (Fisher–Yates).
- Escape hatch: `strategy: none` or env `BENCHMARK_SCHEDULE=none` restores legacy fixed order / older nesting.

### Normative seed recipe (all languages)

```text
key = "{base_seed}|{type_id}|{instance_count}|{type_config_hash}|{mode}|{rep}"
mode normalized: string|buffer → bytes; Stream → stream; then lowercase
u64 = first 8 bytes of SHA-256(utf-8 key) as little-endian
PRNG = SplitMix64(u64)
Fisher–Yates: for i = n-1 .. 1: j = next_u64() % (i+1); swap i,j
```

`base_seed` is `BENCHMARK_SEED` / `reproducibility.random_seed`. Do **not** advance the payload-generation PRNG for shuffling.

**Golden vector** (must match `analysis/tests/test_schedule.py`):

| Input | Value |
|-------|--------|
| names | `A`, `B`, `C` |
| base_seed | `42` |
| type_id / n / hash / mode / rep | `message` / `1` / `abc` / `bytes` / `0` |
| **result order** | **`C`, `B`, `A`** |

Reference implementation: `analysis/src/benchmark_analysis/schedule.py`.

### Optional CSV columns

| Column | Meaning |
|--------|---------|
| `RunOrder` | Monotonic 0-based index of **written** result rows in process order |
| `SchedulePosition` | Index of the serializer within the shuffled list for that rep |

Analysis groups by matrix keys, not file order; these columns are for audits and diagnostics.

---

## Benchmark runner contract (summary) {#harness-contract-summary}

Every language runner must satisfy this contract so analysis can treat files the same way.

| Requirement | Detail |
|-------------|--------|
| Output file | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` matching `csv_schema` |
| `Language` column | Language id (`csharp`, `python`, `rust`, …) |
| Time unit | **Nanoseconds** for every benchmark runner (including C#) |
| Modes | `bytes` / `stream` (C# may use `string` / `stream`) |
| Schedule | Default `block_shuffle`; see [Timed-trial schedule](#timed-trial-schedule) |
| Timed section | Serialize and deserialize only |
| Fidelity | Round-trip check; failures → `logs/<lang>/<ts>.errors.csv` |
| Seed | From `schemas` / master config `reproducibility.random_seed` |
| Methodology | Buffer reuse, barriers, prepare-bound kind — see [Timing rules](#timing-methodology-suite-wide-issue-59) above |

Full implementer checklist: [Adding a language](ADDING_A_LANGUAGE.md).

---

## From CSV to published numbers (preview)

```text
Load CSV
  → convert times to a common unit
  → drop warmup row
  → optional outlier filter
  → means, medians, percentiles
  → bootstrap confidence interval on the mean
  → effect sizes vs the fastest serializer in the group
  → optional A/B tests between two versions
```

Defaults live under `statistics:` and `modes:` in `config/benchmark_config.yaml`. The authoritative walkthrough is [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Run modes (how many repetitions) {#run-modes-how-many-repetitions}

Run modes come from `modes:` in `config/benchmark_config.yaml`. Runners should call `bench_mode_reps` rather than hard-coding counts.

| Mode | Repetitions | Intent |
|------|-------------|--------|
| `smoke` | 2 | Minimal sanity check / fast continuous-integration path |
| `all-single` | 10 | Quick pass over the full matrix |
| `full` | 100 | Publication-quality run |
| `research` | 500 | High-power statistical study |

**When to pick which mode, and how this differs from I/O mode:** **[Modes — run modes](modes.md#part-2-run-modes-how-heavy-the-experiment-is)**.

**Warmup policy:** benchmark runners **always log** every successful repetition, including index 0. Analysis drops `RepetitionIndex == 0` when `statistics.exclude_warmup` is true (the configured warmup count is **1**). Outlier filtering is also analysis-only. Raw files under `logs/<lang>/` are never rewritten by the stats pipeline.

---

## Configuration map

| Concern | Where it lives |
|---------|----------------|
| Run modes, stats, languages, paths | `config/benchmark_config.yaml` — [Modes](modes.md) |
| Payload shapes and seed | `schemas/data_catalog_v2.yaml` + `config/library/` — [Test data](test_data_configuration.md) |
| Paradigm inventories | [Serialization categories](serialization_categories.md) + each language **Overview** |
