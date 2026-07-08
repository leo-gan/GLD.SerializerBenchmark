# Row vs columnar at system scale

## Problem

The same organization often runs:

- **Services** exchanging whole records (user profile, order command, device event).  
- **Analytics** scanning billions of rows but only a few columns (revenue by day, feature columns for training).

Teams collapse both onto one encoding—“everything is Protobuf” or “everything is Parquet”—and pay either impossible scan costs or impossible per-message overhead. The 101 axis *row vs columnar* becomes a **system boundary** question at 301 scale.

## Short answer

Use **row-oriented** messages (JSON objects, Protobuf messages, Avro records, MessagePack maps) when the unit of work is **whole records** with low-latency point access or per-event processing. Use **columnar** layouts (Parquet, ORC, Arrow tables) when the unit of work is **bulk scan/aggregate over few columns** on large datasets. Crossing the streams is occasional glue (export jobs), not a default architecture. Do not pick columnar because it compresses well in a blog chart if every request needs the full row in under a millisecond.

Assumes 101 row/columnar axis; this page owns **workload architecture**.

## Constraints that matter

| Axis | Row-oriented messages | Columnar tables / files |
|------|----------------------|-------------------------|
| **Access** | Get one entity; process one event | Scan column subsets over partitions |
| **I/O shape** | Whole record contiguous | Column chunks; predicate pushdown |
| **Latency** | Often µs–ms per message | Throughput-oriented batch/stream jobs |
| **Evolution** | Per-message schema/IDL culture | Table schema + file footers + catalog |
| **Compression** | Per message or stream framing | Column stats, dictionary, page compression |
| **Typical home** | API, RPC, queues, OLTP-style paths | Lakes, warehouses, feature stores, ML batch |

## Decision frame

| Workload | Default encoding class | Poor default |
|----------|------------------------|--------------|
| Public or internal RPC | Row (JSON / schema-driven / schemaless binary) | Parquet files per request |
| Kafka-style event processing (per event) | Row (Avro/Protobuf/JSON) | Columnar unless micro-batch deliberately |
| Nightly lake on object storage | Columnar (Parquet/ORC) | Millions of tiny Protobuf files as the lake |
| Interactive notebook on large tables | Arrow / columnar engines | Nested JSON lines as sole store |
| Feature training over wide tables | Columnar | Row RPC dumps without projection |
| Cache get-by-id | Row | Columnar file open per key |

```text
  Do we mostly read ALL fields of FEW records?
        yes → row-oriented message codecs
  Do we mostly read FEW fields of MANY records?
        yes → columnar storage / Arrow-class interchange
```

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Protobuf lake** | Tiny files, no column prune, ops nightmare |
| **Parquet RPC** | Catastrophic per-call overhead; wrong mutability story |
| **One format to rule them all** | Either analytics or services becomes second-class |
| **Ignoring partition design** | Columnar without partition/predicate strategy still scans the world |
| **Confusing Arrow with Parquet** | Arrow ≈ in-memory/interchange; Parquet ≈ on-disk columnar—related, not identical jobs |

## Real-world sketch

A metrics pipeline ingests events as Protobuf (good: row, low latency). Analysts dump the same Protobuf messages as the lake format. Queries that need two fields open every message fully. Moving the **serving path** to remain Protobuf while a **batch compact job** writes Parquet partitions by day cuts scan cost without changing the real-time contract. The suite may show excellent Protobuf decode rates; that does not make Protobuf a lake format.

## In this suite

| Resource | Role |
|----------|------|
| Language harnesses | Predominantly **row-oriented message** codecs and fixtures |
| [Test data configuration](../../analysis/test_data_configuration.md) | Record-shaped fixtures (`Person`, `Telemetry`, …) |
| [Serialization categories](../../analysis/serialization_categories.md) | Families for message codecs—not a Parquet engine benchmark |
| [Using this suite](using-this-suite.md) | How to read message-level Results |

**Important:** this suite is **not** a columnar engine benchmark. Absence of Parquet/Arrow from a language Results page means “not measured here,” not “irrelevant for lakes.”

## What this suite cannot tell you

- Scan cost of Parquet vs ORC on your warehouse.  
- Arrow zero-copy handoff between two specific engines.  
- Optimal partition/layout for your lake.  
- Whether micro-batch columnar encoding of events is worth the complexity.

## Common mistakes

- Citing message-codec Results to justify lake format choice.  
- Forcing analytics to query an operational RPC log format forever.  
- Using columnar “because compression” on chatty ultra-small RPCs.

## Key takeaways

- **Access pattern** chooses row vs columnar more than fashion.  
- Services ↔ row messages; lakes/analytics ↔ columnar (with deliberate bridges).  
- Suite Results inform **message codec** choice inside a language—not lake architecture.  
- Dual paths (row for serve, columnar for analyze) are normal, not failure.
