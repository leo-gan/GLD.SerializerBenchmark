# Benchmark modes

This page explains the two different meanings of **mode** in this project. Both show up in docs, scripts, and the Dashboard Mode filter. Mixing them up is a common source of confusion.

| Name | Question it answers | Example values |
|------|---------------------|----------------|
| **I/O mode** | *How* did we call the serializer? | bytes (or string) · stream |
| **Run mode** | *How long / how heavy* was the experiment? | smoke · all-single · full · research |

A third related idea is **batch size N** (1 vs 100 instances in one call). That is **not** a “mode”; it lives under [Test data](test_data_configuration.md).

---

## Learning goals

After this page you should be able to:

1. Tell I/O mode and run mode apart in one sentence each.
2. Explain why the Dashboard Mode filter shows **bytes** and **stream** side by side.
3. Choose a run mode for a quick check vs a publishable snapshot.
4. Avoid unfair comparisons (different modes, or “adapted” stream vs a real stream API).

---

## Picture: three knobs on one experiment

```text
  Run mode          → how many times we repeat the timed loop (and which matrix)
  I/O mode          → buffer/string API  vs  stream API
  Data type + N     → e.g. message with N=1 or N=100

  One CSV row = one language + one serializer + one data type + one N + one I/O mode + one repetition
```

You can change any knob independently. Changing run mode does **not** change what “stream” means.

---

## Part 1 — I/O modes (how we call the library)

### Why two paths?

Real programs use serializers in more than one way:

- **In memory:** “Turn this object into a byte array (or string), then later turn those bytes back into an object.” Common for caches, small RPC bodies, tests.
- **Through a stream:** “Write the encoded form into a stream” / “Read it from a stream.” Common for files, sockets, and large payloads where you do not want one giant string in memory first.

This suite measures **both call shapes** when the language runner supports them, so rankings are not tied to only one API style.

### What the labels mean

On the **Dashboard** Mode filter you usually see:

| Label on Dashboard | Everyday meaning | Typical CSV value (`StringOrStream`) |
|------------------|------------------|--------------------------------------|
| **bytes mode** | In-memory buffer (or language equivalent) | `bytes`, `buffer`, or C# **`string`** |
| **stream mode** | Stream-style write/read | `stream` or `Stream` |

**Important:** these names describe the **programming interface**, not the **size** of the data. “Bytes mode” does **not** mean “small payload.” “Stream mode” does **not** mean “large payload.”

### What is timed

For **each** I/O mode, the stopwatch covers:

1. Serialize using that mode’s API  
2. Deserialize using that mode’s API  

Setup (schemas, maps, buffer pools) stays **outside** the stopwatch. Details: [Architecture — what we measure](architecture.md#measurement-model).

### C# special case: “string” instead of “bytes”

Most languages log the in-memory path as `bytes`. **C#** often logs it as **`string`**, because many .NET libraries expose `Serialize` / `Deserialize` that return or take a `string`.

| Language family | In-memory path in CSV | Dashboard label |
|-----------------|----------------------|---------------|
| Python, Rust, Go, Java, C, C++, JS, Swift | `bytes` (or similar) | **bytes mode** |
| C# | `string` | still shown as **bytes mode** in multi-language tables for consistency |

On C#, for **binary** libraries, that string is often **Base64** text of the real binary payload. So:

- The **string** path times Base64 encode/decode as well as the library.  
- The **stream** path may write raw binary without Base64.  
- **Sizes** on the string path can look larger than stream sizes for the same object — that can be Base64, not a different object.

C#-specific notes: [C# overview — string vs stream](../c-sharp/index.md#string-mode-vs-stream-mode).

### Three levels of “stream” honesty {#three-levels-of-stream-honesty}

Not every “stream mode” row is a deep, true streaming API.

| Kind | What the runner does | How to read the Dashboard |
|------|----------------------|---------------------|
| **Native stream** | Calls the library’s real stream (or reader/writer) API | Best evidence for “stream performance” of that library |
| **Text writer on a stream** | Library writes text through a writer attached to a stream (common for JSON/YAML) | Still a real library path; not the same as binary stream APIs |
| **Adapted stream** | Builds the full in-memory result first, then dumps it to a stream (or the reverse) | Times often **close to** the in-memory path; do **not** treat as proof of incremental I/O |

#### CSV `StreamMode` (required on new stream rows)

Machine-readable honesty on **stream** I/O rows (`StringOrStream` = `stream` / C# `Stream`):

| CSV value | Meaning |
|-----------|---------|
| `native` | Timed **serialize and deserialize** both use the library’s real stream/reader/writer APIs |
| `text_on_stream` | Library text writer/reader on a stream (JSON/YAML/XML style) |
| `adapted` | Full in-memory encode/decode plus dump to / load from a stream (or equivalent wrapper) |

Rules:

- Bytes/string rows may leave `StreamMode` empty.
- Do **not** label `native` if either timed half is still the bytes API.
- If the timed stream path is **identical** to bytes (label-only “stream”), the benchmark runner must **not emit stream rows** for that language/codec.

The Dashboard shows a **stream honesty** chip next to Mode from these labels. See [Metrics — StreamMode](METRICS.md).

If stream and bytes (or string) times are almost the same, check the language **Overview** and the banner. Many suites mark adapted paths there. Methodology also notes that stream is not always incremental: [Analysis methodology — limitations](ANALYSIS_METHODOLOGY.md#limitations).

### How I/O mode appears in the pipeline

| Place | What you see |
|-------|----------------|
| Raw CSV | Column `StringOrStream` |
| Analysis groups | Part of the group key: language + serializer + data type + **I/O mode** |
| Dashboard | Mode filter **bytes** / **stream** |
| Fair ranking | Compare serializers in the **same** language, same data type, same **I/O mode** |

### Fair comparison checklist (I/O)

- Same **language**  
- Same **category** when possible (JSON with JSON, …)  
- Same **data type** and same **batch size N**  
- Same **I/O mode** (do not crown a winner from stream vs someone else’s bytes path)  
- If stream ≈ bytes, prefer the language Overview’s honesty notes before drawing API conclusions  

---

## Part 2 — Run modes (how heavy the experiment is) {#part-2-run-modes-how-heavy-the-experiment-is}

### Why several run modes?

A full matrix (many serializers × data types × N × two I/O modes × many repetitions) takes a long time. The suite offers **presets** so you can:

- smoke-test a change in minutes, or  
- collect publication-quality samples overnight.

Run modes are defined in `config/benchmark_config.yaml` under `modes:`. Scripts should **read** those values (via `bench_mode_reps`), not invent their own counts.

### The four standard run modes

| Run mode | Repetitions (default) | Intent | Typical use |
|----------|----------------------|--------|-------------|
| **smoke** | 2 | Smallest useful run | “Does this still work?” CI, local quick check |
| **all-single** | 10 | Short full matrix | Fast multi-serializer pass before a long run |
| **full** | 100 | Publication-quality | Numbers you pack into the Dashboard / the site |
| **research** | 500 | High sample count | Statistics papers, tight confidence intervals |

Exact repetition counts live in config; if config changes, this table should be updated to match.

### What a run mode does *not* change

| Unchanged by run mode | Controlled instead by |
|-----------------------|------------------------|
| Which serializers exist | Language registration / Overview |
| Data type shapes | [Test data](test_data_configuration.md) / `config/library/` |
| Whether both I/O modes run | Language runner design |
| Warmup policy | Analysis drops repetition index 0; runners still log it |
| Fairness rules | Same CSV contract for all modes |

So: **smoke** is not “a different I/O mode.” It is “fewer timed repetitions (and often a smaller data matrix if the script’s config says so).”

### Which run mode should I pick?

| Goal | Prefer |
|------|--------|
| I changed one serializer and want a quick green light | `smoke` |
| I want a full matrix without waiting forever | `all-single` |
| I will publish or commit Dashboard data | `full` |
| I need strong statistical power | `research` |

Example:

```bash
./scripts/run-all-benchmarks.sh --mode smoke --lang python
./scripts/run-all-benchmarks.sh --mode full --lang rust
```

### Warmup and repetitions

- The runner logs **every** successful repetition, including the first (`RepetitionIndex = 0`).  
- Analysis treats the first as **warmup** and drops it from averages by default.  
- So `full` with 100 logged reps yields about **99** samples in summaries when warmup exclusion is on.

Details: [Architecture — run modes](architecture.md#run-modes-how-many-repetitions) · [Methodology — warmup](ANALYSIS_METHODOLOGY.md).

---

## Part 3 — How modes show up together

### One example CSV row (idea)

```text
Language=python, StringOrStream=bytes, TestDataName=message,
DataTypeInstanceCount=100, SerializerName=orjson, RepetitionIndex=3, ...
```

Read as: Python, **bytes** I/O mode, data type **message**, batch **N=100**, library **orjson**, 4th timed try (index 3).

### Dashboard tables

- **Overview** ranks the current data-type and Mode slice (usually the in-memory path).  
- Switch the Mode filter to compare **bytes** and **stream** for the same fixture.  
- **Details** breaks out median / std / P95 / P99 so you can see which workload matters.

If stream and bytes look almost equal, open [stream honesty](#three-levels-of-stream-honesty) before concluding the library’s stream API is “free.”

### Dashboard and regenerate

- Published numbers come from a chosen run (often `full`), packed via `dashboard/scripts/sync-data.py`.  
- Regeneration and claim levels: [Claims and replication](CLAIMS_AND_REPLICATION.md).  
- Metrics names: [Metrics catalog](METRICS.md) (`StringOrStream`).

---

## Quick reference

| If you hear… | It means… |
|--------------|-----------|
| “bytes mode” / “string mode” | In-memory API path (C# uses string) |
| “stream mode” | Stream API path (native, text-on-stream, or adapted) |
| “smoke / full / research” | How heavy the **run** is (repetitions / matrix intent) |
| “message @ n=100” | Data type + batch size — **not** an I/O mode |
| “modes in config” | Usually **run** modes under `modes:` in YAML |

---

## Related pages

| Topic | Page |
|-------|------|
| Suite layout and timing rules | [Architecture](architecture.md) |
| How CSVs become numbers | [Methodology](ANALYSIS_METHODOLOGY.md) |
| Column dictionary | [Metrics](METRICS.md) |
| Data types and batch size N | [Test data](test_data_configuration.md) |
| C# string / Base64 / envelopes | [C# overview](../c-sharp/index.md) |
| Fair format families | [Categories](serialization_categories.md) |


## Timed-trial order (serializers)

Within each data type and I/O mode, serializers are **reshuffled each repetition** by default (`block_shuffle`) so wall-clock position does not systematically favor early registration order. Details: [architecture — schedule](architecture.md#timed-trial-schedule).
