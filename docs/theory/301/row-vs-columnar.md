# Row vs columnar at system scale

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/row_vs_columnar.ipynb)
**Lab notebook:** [Row vs columnar experiment](../notebooks/301/row_vs_columnar.ipynb)

## Problem

The same organization often runs two very different workloads:

- **Services** that exchange whole records. Examples include a user profile, an order command, or a device event.
- **Analytics** that scan billions of rows but only a few columns. Examples include revenue by day or feature columns for training.

In a **row-oriented** layout, all fields of one record sit together. That is natural when you usually need the whole record. In a **columnar** layout, values from the same field across many records sit together. That is natural when you usually need a few fields across huge tables.

Teams collapse both onto one encoding. They say “everything is Protobuf” or “everything is Parquet.” Then they pay either impossible scan costs or impossible per-message overhead. The 101 axis *row versus columnar* becomes a **system boundary** question at Serialization 301 scale.

---

## Short answer

Use **row-oriented** messages when the unit of work is **whole records**. Those messages include JSON objects, Protobuf messages, Avro records, and MessagePack maps. They fit low-latency point access and per-event processing. Use **columnar** layouts when the unit of work is a **bulk scan or aggregate over few columns** on large datasets. Those layouts include Parquet, ORC, and Arrow tables.

A **data lake** is a large store of historical data. It often lives on object storage. It is designed for analytics rather than for single-record API responses.

Crossing the streams is occasional glue. Export jobs are one example. Crossing the streams is not a default architecture. Do not pick columnar because it compresses well in a blog chart. That choice is wrong if every request needs the full row in under a millisecond. A columnar layout pays off when the row count is large. At one row, headers and alignment padding dominate both size and time.

This page assumes the 101 row and columnar axis. Here we own **workload architecture**.

---

## Constraints that matter

| Axis | Row-oriented messages | Columnar tables and files |
|------|----------------------|---------------------------|
| **Access** | Get one entity; process one event | Scan column subsets over partitions |
| **I/O shape** | Whole record stored contiguously | Column chunks; predicate pushdown can skip data |
| **Latency** | Often microseconds to milliseconds per message | Throughput-oriented batch or stream jobs |
| **Evolution** | Per-message schema or IDL culture | Table schema, file footers, and a catalog |
| **Compression** | Per message or stream framing | Column statistics, dictionaries, page compression |
| **Typical home** | APIs, RPC, queues, OLTP-style paths | Lakes, warehouses, feature stores, machine-learning batch |

**Predicate pushdown** means the storage engine uses filters to avoid reading irrelevant files or column chunks. One filter example is “date = yesterday.” **OLTP** means online transaction processing. That style uses many small, interactive updates and reads.

In other words, row and columnar optimize for different questions. They are not two brands of the same tool.

---

## Decision frame

| Workload | Default encoding class | Poor default |
|----------|------------------------|--------------|
| Public or internal RPC | Row (JSON, schema-driven, or schemaless binary) | Opening Parquet files per request |
| Kafka-style event processing (one event at a time) | Row (Avro, Protobuf, or JSON) | Columnar unless you deliberately micro-batch |
| Nightly lake on object storage | Columnar (Parquet or ORC) | Millions of tiny Protobuf files as the lake |
| Interactive notebook on large tables | Arrow or other columnar engines | Nested JSON Lines as the sole store |
| Feature training over wide tables | Columnar | Row RPC dumps without projection |
| Cache get-by-id | Row | Opening a columnar file per key |

```text
  Do we mostly read ALL fields of FEW records?
        yes → row-oriented message codecs
  Do we mostly read FEW fields of MANY records?
        yes → columnar storage or Arrow-class interchange
```

This matters because a format that is excellent for service RPC can be a terrible lake format. The reverse is also true.

---

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Protobuf lake** | Tiny files, no column pruning, operations nightmare |
| **Parquet RPC** | Catastrophic per-call overhead and the wrong mutability story |
| **One format to rule them all** | Either analytics or services becomes second-class |
| **Ignoring partition design** | Columnar storage without partitions or predicates still scans the world |
| **Confusing Arrow with Parquet** | Arrow is mainly in-memory interchange; Parquet is mainly on-disk columnar—related jobs, not identical ones |

For example, storing years of events as millions of tiny Protobuf files is expensive. Every analytical query must open and fully parse records. Many of those records contain fields the query does not need.

---

## Real-world sketch

A metrics pipeline ingests events as Protobuf. That is a good row-oriented, low-latency choice. Analysts then dump the same Protobuf messages as the lake format. Queries that need two fields open every message fully.

A better design keeps the **serving path** on Protobuf. It adds a **batch compact job** that writes Parquet partitions by day. Scan cost drops without changing the real-time contract. The suite may show excellent Protobuf decode rates. That does not make Protobuf a lake format.

---

## In this suite

| Resource | Role |
|----------|------|
| Language benchmark runners | `all@all` stays the five Suite types. `table`, `table_project`, `nested_table`, and `signal` are their own Dashboard data types |
| [Test Data](../../analysis/test_data_configuration.md) | Those nine type ids |
| [Columnar run config](../../../config/library/columnar.yaml) | The four columnar types. Timed for the new serializers and a short peer list |
| [Serialization categories](../../analysis/serialization_categories.md) | Columnar is its own teaching family. SBE stays schema-driven. Its data set is Columnar. Its standard is SBE. |
| [Using this suite](using-this-suite.md) | How to read Dashboard numbers. Compare inside one language, one standard, one data set, and one data type. |

**Important:** `all@all`, `all@1`, and `all@100` stay the five Suite types (`message`, `document`, `telemetry`, `strings`, `event`). The four Columnar types are separate data types. Their groups come from a `columnar.yaml` run appended by `dashboard/scripts/splice-columnar-stats.py`. The five-type groups are the earlier published snapshot and were not recomputed.

SBE (Simple Binary Encoding) is measured on `signal`, `table`, and `table_project`. Each record is one stride: the bytes from the start of that record to the start of the next. Variable-length fields change that distance. SBE is not a columnar file format like Parquet. On `table_project`, every codec in this comparison writes the full row and reads only `f_float_0`.

Spliced columnar serializers (peers measured in that same run also appear on those data types):

| Language | Columnar serializers in the snapshot |
|----------|--------------------------------------|
| Python (50 repetitions; the run hit the 600s cap) | `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed` |
| C++ | `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed`, `sbe` |
| Rust | `arrow-ipc`, `parquet`, `parquet-uncompressed`, `sbe` |
| Go | `arrow-ipc`, `parquet`, `parquet-uncompressed`, `sbe` |
| Java | `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed`, `sbe` |
| C# | `arrow-ipc`, `parquet`, `parquet-uncompressed` |
| JavaScript | `arrow-ipc`, `parquet`, `parquet-uncompressed` |
| Kotlin | `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed`, `sbe` |

C++, Rust, Go, Java, C#, JavaScript, and Kotlin used 100 repetitions. Do not rank `arrow-ipc` on `table_project` against a JSON row on `message`. A language missing from the table is not in this snapshot. That absence does not mean the format is irrelevant for lakes.

---

## Experiments

**Question:** Is this path **row/RPC-shaped** or **analytical/columnar**, and are we using the wrong codec class for the system?

### Setup

1. Describe the access pattern. Mark point lookups and RPC versus scan aggregates over many rows.
2. Estimate selectivity. Note few columns versus wide rows. Estimate data volume.
3. List candidate stacks. Include row JSON, Protobuf, and Avro. Include Parquet, ORC, and Arrow-class.

### Procedure

1. Classify the primary workload using the decision frame.
2. If the path is analytical, prototype scan time and compression on a columnar layout. Compare that with dumping RPC rows.
3. If the path is RPC, measure per-message latency with row codecs. Do not put lake formats on the code path that runs on every request under load.
4. Treat `all@all` as the five Suite types. Read `table`, `table_project`, `nested_table`, and `signal` for Arrow, Parquet, and ORC. Read `signal`, `table`, and `table_project` for SBE. SBE has no `nested_table` row. Do not rank a Columnar row against a Suite codec on `message`. On `table_project`, deserialize reads only `f_float_0`.
5. Document a two-hop design if both patterns exist. Use row events on the bus. Use columnar data in the lake.

### Decision rule

- Scan-heavy lake path means a columnar system format. RPC suite winners are irrelevant.
- Hot RPC means a row message or a schema-driven message layout. Columnar files such as Parquet are not substitutes. SBE can still be a message layout. It is not a lake file.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Query shape** (point versus scan; columns touched) | **Primary** classifier |
| Scan time and bytes read for the analytical job | Columnar effectiveness |
| RPC 99th-percentile latency (*p99*) per message | Row-path reliability target |
| Compression ratio on lake files | Storage economics |
| Suite `total_median_ns` and `median_size_bytes` | Row-codec orientation on a row data type. Columnar orientation on `table`, `table_project`, `nested_table`, and `signal` |
| Cross-paradigm “winner” charts | Misleading for this decision |

**Conclusion style:** “Ingest RPC uses Protobuf rows; the lake uses Parquet; we do not dual-use one codec for both jobs.”

---

## What this suite cannot tell you

- Scan cost of Parquet versus ORC on your warehouse.
- Arrow zero-copy handoff between two specific engines.
- Optimal partition and layout design for your lake.
- Whether micro-batch columnar encoding of events is worth the complexity.
- Columns whose values use fewer than eight bits, such as model weights stored that way, and whether a wider hardware bus changes the cost of encoding. See [Bit width is not bus width](../201/bit-width-and-bus-width.md).

---

## Common mistakes

- Citing message-codec Dashboard numbers to justify a lake format choice.
- Forcing analytics to query an operational RPC log format forever.
- Using columnar “because compression” on chatty, ultra-small RPCs.

---

## Key takeaways

- **Access pattern** chooses row versus columnar more than fashion.
- Services want row messages. Lakes and analytics want columnar storage. Use deliberate bridges between them.
- Dashboard `all@all` informs message codec choice inside a language. Arrow, Parquet, and ORC on the Columnar data types inform scan layouts. SBE on those types is still one record per stride. None of those rows designs lake architecture.
- Dual paths are normal. Use row for serve and columnar for analyze. That is not a design failure.
