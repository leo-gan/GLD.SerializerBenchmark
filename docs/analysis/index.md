# Benchmarks

This section explains **how this project measures serializers**, not the theory of formats themselves. On the site it lives under the **Benchmarks** tab. Live interactive results live under the **Dashboard** tab.

If Learn / Serialization 101 answers *“what is serialization?”*, Benchmarks answers *“how do we time it fairly, and what do the numbers mean?”*

You do not need to be a performance engineer to read these pages. They are written for introductory computer science students and for anyone who wants a clear picture of the suite before diving into tables and plots.

---

## Learning goals

After reading this section you should be able to:

1. Say what a **benchmark** is measuring here (serialize and deserialize time, size, and correctness).
2. Find the page for the five data sets, for modes, for statistics, for metrics, or for published numbers.
3. Compare serializers **within one language and one standard**, on the same data set and data type, instead of treating absolute times as a global ranking.
4. Open a language **Overview** (what libraries we measure, roster and caveats) under the **Languages** tab.
5. Open the **Dashboard** for measured numbers and interactive comparisons.

For the ideas behind formats, start with [Serialization 101](../theory/101/index.md) under **Learn**.

---

## Data sets

Every published number is for one **data set** and one **data type** inside it. A library is measured only on the sets it can carry. There are five sets.

| Data set | Data types | Shapes |
|----------|------------|--------|
| Suite | `message`, `document`, `telemetry`, `strings`, `event` | [Suite](suite.md) |
| Columnar | `table`, `table_project`, `nested_table`, `signal` | [Columnar](columnar.md) |
| Graph | `graph` | [Graph](graph.md) |
| Array | `grid`, `grid_window` | [Array](array.md) |
| Tensor | `tensor`, `tensor_view`, `prompt`, `shard`, `request` | [Tensor](tensor.md) |

Generator rules and the run-config table are on [Data sets](test_data_configuration.md). The shapes are on each set’s page. The word itself is defined on [Terminology](terminology.md#data-set).

---

## The big picture in one paragraph

Each programming language has a small program called a **benchmark runner**. The benchmark runner builds sample data, runs each serializer many times, checks that the data comes back correctly, and writes a spreadsheet-like file (CSV). A shared **analysis** program then cleans those runs, computes summaries, and produces the tables and charts you see on the site. Everyone shares the same data shapes and the same analysis rules so comparisons stay fair.

```text
  benchmark runner (C#, Python, Rust, …)
       │  timed serialize + deserialize
       ▼
  logs/<language>/*.csv
       │
       ▼
  analyze-benchmarks
       │
       └──► reports/stats_<lang>_latest.json   (Dashboard sync input)
```

---

## Contribute

| Task | Guide |
|------|--------|
| Add **one library** to an existing language | [Adding a serializer](ADDING_A_SERIALIZER.md) |
| Add a **new language** tree | [Adding a language](ADDING_A_LANGUAGE.md) |

---

## Terminology

Data set, data type, runner, and the prohibited words are defined on [Terminology](terminology.md). **Fixture** means data type. **Harness** means benchmark runner.

---

## How to read this section

The left sidebar is the reading order. Each page assumes you have read the ones above it.

1. Read **[Terminology](terminology.md)** for the words, including data set and data type.
2. Read **[Data sets](test_data_configuration.md)** for the shared rules, then the page for one set: **[Suite](suite.md)**, **[Columnar](columnar.md)**, **[Graph](graph.md)**, **[Array](array.md)**, or **[Tensor](tensor.md)**. The Array page also says which languages are measured on that set.
3. Read **[Families](families.md)** for the teaching map, and for how a family differs from a data set.
4. Read **[Architecture](architecture.md)** for how the repository times a library.
5. Read **[Timing honesty](TIMING_HONESTY.md)** for what `prepare` may do and what `serialize` must do.
6. Read **[Modes](modes.md)** for bytes versus stream, and for smoke through research.
7. Read **[Methodology](ANALYSIS_METHODOLOGY.md)** for warmup, filters, and uncertainty.
8. Open **[Metrics](METRICS.md)** when a column name is opaque.
9. Read **[Claims and replication](CLAIMS_AND_REPLICATION.md)** before you publish a claim.

Contributor checklists come after that path: **[Adding a serializer](ADDING_A_SERIALIZER.md)** and **[Adding a language](ADDING_A_LANGUAGE.md)**.

| Page | What you will learn | Start here if you want… |
|------|---------------------|-------------------------|
| **[Terminology](terminology.md)** | Data set, data type, runner, and the words this site does not use | A term is unclear, or an older page says “fixture” |
| **[Data sets](test_data_configuration.md)** | The five sets, the shared knobs, and links to each set’s page | What we serialize |
| **[Suite](suite.md)**, **[Columnar](columnar.md)**, **[Graph](graph.md)**, **[Array](array.md)**, **[Tensor](tensor.md)** | The types in one set, and what each one stresses. Array also lists who is measured. | One data set |
| **[Families](families.md)** | Teaching map: JSON, schemaless binary, schema-driven, language-native, columnar | Which standard a product question points at |
| **[Architecture](architecture.md)** | How the repository is organized and how timing works | The measurement design |
| **[Timing honesty](TIMING_HONESTY.md)** | What belongs in `prepare` vs the timed encode/decode | “Is this row measuring a real encode?” |
| **[Modes](modes.md)** | I/O modes (bytes/stream) and run modes (smoke…research) | Why the Dashboard Mode filter has two paths; which run preset to use |
| **[Methodology](ANALYSIS_METHODOLOGY.md)** | Warmup, outliers, confidence intervals, effect sizes, exploratory ranks | How CSVs become published numbers |
| **[Metrics](METRICS.md)** | Names and meanings of every reported measurement | “What does this column mean?” |
| **[Claims and replication](CLAIMS_AND_REPLICATION.md)** | L1 / L2 / L3: what you may claim from one run vs many | Honest generalization language |
| **[Adding a serializer](ADDING_A_SERIALIZER.md)** | Drop-in checklist for one library | Author path |
| **[Adding a language](ADDING_A_LANGUAGE.md)** | Checklist to plug in a new language benchmark runner | Extending the suite |
| **[Dashboard](../dashboard/)** | Live measured numbers (Overview, Details, Compare) | The published L1 artifact |

Theory tracks: [101](../theory/101/index.md) · [201](../theory/201/index.md) · [301](../theory/301/index.md) · [401](../theory/401/index.md). Live charts: [Dashboard](../dashboard/).

---

## Languages in this suite

Each language has a hand-written **Overview** (roster, caveats, how to read this runner). Measured numbers live on the **Dashboard**.

| Language | Serializers (registered) | Overview | Dashboard |
|----------|--------------------------|----------|-----------|
| C | **21** | [Overview](../c/index.md) | [Dashboard](../dashboard/?lang=c) |
| C# | **56** | [Overview](../c-sharp/index.md) | [Dashboard](../dashboard/?lang=csharp) |
| C++ | **40** ‡ | [Overview](../cpp/index.md) | [Dashboard](../dashboard/?lang=cpp) |
| Fortran | **9** | [Overview](../fortran/index.md) | [Dashboard](../dashboard/?lang=fortran) |
| Go | **35** | [Overview](../go/index.md) | [Dashboard](../dashboard/?lang=go) |
| Java | **30** | [Overview](../java/index.md) | [Dashboard](../dashboard/?lang=java) |
| JavaScript | **34** † | [Overview](../javascript/index.md) | [Dashboard](../dashboard/?lang=javascript) |
| Kotlin | **34** | [Overview](../kotlin/index.md) | [Dashboard](../dashboard/?lang=kotlin) |
| Mojo | **21** | [Overview](../mojo/index.md) | [Dashboard](../dashboard/?lang=mojo) |
| PHP | **18** | [Overview](../php/index.md) | [Dashboard](../dashboard/?lang=php) |
| Python | **37** | [Overview](../python/index.md) | [Dashboard](../dashboard/?lang=python) |
| Rust | **33** | [Overview](../rust/index.md) | [Dashboard](../dashboard/?lang=rust) |
| Swift | **23** | [Overview](../swift/index.md) | [Dashboard](../dashboard/?lang=swift) |
| Zig | **17** | [Overview](../zig/index.md) | [Dashboard](../dashboard/?lang=zig) |

† In JavaScript, `simdjson` is optional (it needs a native addon). If that addon fails to build, the rest of the run still continues without it.

‡ C++ registers **40** on this machine when `ARROW_ROOT` points at Arrow 25.0.1. Without that prefix the five Arrow rows are skipped and `sbe` still registers (**35** here; Boost.Serialization is not installed). Fory is included in both counts.

**Log language ids** (the `Language` column in CSVs) use short names such as `csharp`, `python`, `rust`, `c`, `javascript`, `go`, `java`, `kotlin`, `php`, `cpp`, `swift`, `zig`, `mojo`, and `fortran`. Documentation folders sometimes differ (for example `docs/c-sharp/` for C#).

To refresh published numbers after a local run, pack Dashboard data with `python3 dashboard/scripts/sync-data.py`. Regeneration and claim levels: [Claims and replication](CLAIMS_AND_REPLICATION.md).

---

## One rule for fair comparison

Prefer:

> **Same language + same standard + same data set + same data type**

A chart that mixes standards is a number wearing a lab coat. It has not earned a ranking. Absolute times across languages (for example “Python vs C++”) mix runtimes, garbage collectors, and allocators. Those numbers can still be informative as a rough direction, but they are not a precise ranking. Details live under [methodology limitations](ANALYSIS_METHODOLOGY.md#limitations).
