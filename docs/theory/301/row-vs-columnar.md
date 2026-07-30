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

Crossing the streams is occasional glue. Export jobs are one example. Crossing the streams is not a default architecture. Do not pick columnar because it compresses well in a blog chart. That choice is wrong if every request needs the full row in under a millisecond.

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
| Language benchmark runners | Predominantly **row-oriented message** codecs and fixtures |
| [Test Data](../../analysis/test_data_configuration.md) | Record-shaped fixtures (`message`, `document`, `telemetry`, and others) |
| [Serialization categories](../../analysis/serialization_categories.md) | Families for message codecs—not a Parquet engine benchmark |
| [Using this suite](using-this-suite.md) | How to read message-level Results |

**Important:** this suite is **not** a columnar engine benchmark. Absence of Parquet or Arrow from a language Results page means “not measured here.” It does not mean “irrelevant for lakes.”

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
4. Treat suite Results as **row** codec orientation only. Do not treat them as lake rankings.
5. Document a two-hop design if both patterns exist. Use row events on the bus. Use columnar data in the lake.

### Decision rule

- Scan-heavy lake path means a columnar system format. RPC suite winners are irrelevant.
- Hot RPC means a row or schema-driven family. Columnar files are not substitutes.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Query shape** (point versus scan; columns touched) | **Primary** classifier |
| Scan time and bytes read for the analytical job | Columnar effectiveness |
| RPC 99th-percentile latency (*p99*) per message | Row-path reliability target |
| Compression ratio on lake files | Storage economics |
| Suite `total_median_ns` and `median_size_bytes` | Row-codec orientation only |
| Cross-paradigm “winner” charts | Misleading for this decision |

**Conclusion style:** “Ingest RPC uses Protobuf rows; the lake uses Parquet; we do not dual-use one codec for both jobs.”

---

## What this suite cannot tell you

- Scan cost of Parquet versus ORC on your warehouse.
- Arrow zero-copy handoff between two specific engines.
- Optimal partition and layout design for your lake.
- Whether micro-batch columnar encoding of events is worth the complexity.

---

## Common mistakes

- Citing message-codec Results to justify a lake format choice.
- Forcing analytics to query an operational RPC log format forever.
- Using columnar “because compression” on chatty, ultra-small RPCs.

---

## Key takeaways

- **Access pattern** chooses row versus columnar more than fashion.
- Services want row messages. Lakes and analytics want columnar storage. Use deliberate bridges between them.
- Suite Results inform **message codec** choice inside a language. They do not design lake architecture.
- Dual paths are normal. Use row for serve and columnar for analyze. That is not a design failure.
