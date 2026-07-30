# Method

This section explains **how this project measures serializers**, not the theory of formats themselves. On the site it lives under the **Method** tab. Live interactive results live under the **Dashboard** tab.

If Learn / Serialization 101 answers *“what is serialization?”*, Method answers *“how do we time it fairly, and what do the numbers mean?”*

You do not need to be a performance engineer to read these pages. They are written for introductory computer science students and for anyone who wants a clear picture of the suite before diving into tables and plots.

---

## Learning goals

After reading this section you should be able to:

1. Say what a **benchmark** is measuring here (serialize and deserialize time, size, and correctness).
2. Find the right page for layout, modes, statistics, metrics, test data, or published results.
3. Compare serializers **within one language** (and ideally one category) instead of treating absolute times as a global ranking.
4. Open a language **Overview** (what libraries we measure) and its **Results** (the measured numbers) under the **Languages** tab.
5. Open the **Dashboard** for interactive charts and comparisons of the same analysis story.

For the ideas behind formats, start with [Serialization 101](../theory/101/index.md) under **Learn**.

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
       ├──► docs/<language>/results.md   (tables)
       └──► docs/analysis/plots/…        (charts)
```

---

## Contribute

| Task | Guide |
|------|--------|
| Add **one library** to an existing language | [Adding a serializer](ADDING_A_SERIALIZER.md) |
| Add a **new language** tree | [Adding a language](ADDING_A_LANGUAGE.md) |

---

## Shared terms (quick)

| Say this | Not this | Means |
|----------|----------|--------|
| **data type** | “fixture” | One of `message`, `document`, `telemetry`, `strings`, `event` |
| **benchmark runner** | “harness” | Per-language program that times serializers and writes the CSV |
| **batch size N** | — | How many instances in one serialize call (`1` or `100`) |
| **category / family** | — | JSON, schemaless binary, schema-driven, language-native |
| **I/O mode** (bytes / stream) | — | How the library was called (buffer vs stream), **not** payload size |
| **run mode** (smoke / full / …) | — | How heavy the experiment is (repetitions / intent) |

Full mode guide: [Modes](modes.md). Data-type glossary: [Test data — vocabulary](test_data_configuration.md#vocabulary).

---

## How to read this section

| Page | What you will learn | Start here if you want… |
|------|---------------------|-------------------------|
| **[Architecture](architecture.md)** | How the repository is organized and how timing works | The measurement design |
| **[Modes](modes.md)** | I/O modes (bytes/stream) and run modes (smoke…research) | Why Results have two mode columns; which run preset to use |
| **[Categories](serialization_categories.md)** | Four families of serializers (JSON, binary, schema-driven, native) | Fair “apples to apples” groups |
| **[Test data](test_data_configuration.md)** | The five sample data types and how sizes are chosen | What we serialize |
| **[Methodology](ANALYSIS_METHODOLOGY.md)** | Warmup, outliers, confidence intervals, effect sizes, exploratory ranks | How CSVs become published numbers |
| **[Metrics](METRICS.md)** | Names and meanings of every reported measurement | “What does this column mean?” |
| **[Claims and replication](CLAIMS_AND_REPLICATION.md)** | L1 / L2 / L3: what you may claim from one run vs many | Honest generalization language |
| **[Adding a language](ADDING_A_LANGUAGE.md)** | Checklist to plug in a new language benchmark runner | Extending the suite |
| **[Results summary](BENCHMARK_SUMMARY.md)** | Links to each language’s numbers and how to regenerate them | The published snapshots |

Theory tracks: [101](../theory/101/index.md) · [201](../theory/201/index.md) · [301](../theory/301/index.md) · [401](../theory/401/index.md).

---

## Languages in this suite

Each language has two documentation pages:

- **Overview** — which serializers are registered, how they are grouped, and any caveats. This is the hand-written source of truth for *what we measure*.
- **Results** — generated tables and latency charts from a real run on a particular machine. Numbers can change when you re-run elsewhere.

| Language | Serializers (registered) | Overview | Results |
|----------|--------------------------|----------|---------|
| C# | **36** | [Overview](../c-sharp/index.md) | [Results](../c-sharp/results.md) |
| Python | **16** | [Overview](../python/index.md) | [Results](../python/results.md) |
| Rust | **15** | [Overview](../rust/index.md) | [Results](../rust/results.md) |
| C | **20** | [Overview](../c/index.md) | [Results](../c/results.md) |
| JavaScript | **20** † | [Overview](../javascript/index.md) | [Results](../javascript/results.md) |
| Go | **19** | [Overview](../go/index.md) | [Results](../go/results.md) |
| Java | **18** | [Overview](../java/index.md) | [Results](../java/results.md) |
| C++ | **27+** | [Overview](../cpp/index.md) | [Results](../cpp/results.md) |
| Swift | **14** | [Overview](../swift/index.md) | [Results](../swift/results.md) |

† In JavaScript, `simdjson` is optional (it needs a native addon). If that addon fails to build, the rest of the run still continues without it.

**Log language ids** (the `Language` column in CSVs) use short names such as `csharp`, `python`, `rust`, `c`, `javascript`, `go`, `java`, `cpp`, and `swift`. Documentation folders sometimes differ (for example `docs/c-sharp/` for C#).

To regenerate tables and plots after a local run, see [Results summary — regenerating snapshots](BENCHMARK_SUMMARY.md#regenerating-language-snapshots).

---

## One rule for fair comparison

Prefer:

> **Same language + same [category](serialization_categories.md) + same data type + same I/O mode**

Absolute times across languages (for example “Python vs C++”) mix runtimes, garbage collectors, and allocators. Those numbers can still be informative as a rough direction, but they are not a precise ranking. Details live under [methodology limitations](ANALYSIS_METHODOLOGY.md#limitations).
