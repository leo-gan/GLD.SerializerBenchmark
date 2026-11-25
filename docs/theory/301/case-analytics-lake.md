# Case 4: Analytics Lake on Object Storage

> **Design brief:** Finance and product analytics run daily and ad-hoc aggregations over years of commerce history stored in S3-class object storage using Spark and DuckDB, while operational services already emit real-time events on a message bus.

---

## Scenario and Hard Constraints

- **Workload shape:** Wide tables (tens to hundreds of columns) spanning billions of historical rows; typical analytical queries touch 3–8 columns filtered by date range and region.
- **Infrastructure:** Object storage for durable retention; distributed/embedded analytical engines (Spark, DuckDB, Trino) for queries.
- **Hard constraints:**
  - Low-latency transactional serving remains separate ([Case 2](case-internal-rpc.md) and [Case 3](case-event-stream.md)).
  - Analysts and query engines must read an open, portable format—never opaque service-native blobs.

---

## Candidate Options and Trade-Offs

| Dimension | A. Compacted Columnar Lake (Parquet/ORC + Catalog) | B. Raw Row Event Archives (Protobuf/JSON Files) | C. Unified RPC Format Everywhere |
|---|---|---|---|
| **Scan I/O & query latency** | Minimal (column pruning, min/max predicate pushdown, columnar compression) | High (reads and parses every unused column) | Poor (anti-pattern for analytics) |
| **Object-store overhead** | Low (compacted 64–512 MB partitioned files) | Severe small-file listing and open overhead | Severe small-file overhead |
| **Table schema evolution** | Managed via table catalog (Iceberg/Delta/Hive) + file footers | Per-message schema only; no table snapshots | Wrong abstraction |
| **Operational complexity** | Requires compaction & catalog maintenance | Trivial landing, expensive queries forever | Trivial landing, unacceptable analytics cost |

---

## Recommended Architecture

1. **Choose Option A (two-hop row-to-columnar pipeline):** Keep operational events in a schema-driven row format (Avro or Protobuf) on the event bus, and run a scheduled or streaming **compaction pipeline** that writes date-partitioned **Parquet** (or ORC) files registered in an open table catalog ([3.5 Row vs. columnar](row-vs-columnar.md)).
2. **Restrict Option B to a short-TTL landing zone:** Raw event dumps on object storage are useful as a replayable staging buffer (e.g., 7–30 days), never as the primary analytical query table.
3. **Reject Option C:** Unifying serving RPC and analytical lake storage onto one encoding penalizes one workload severely.

---

## Verification Plan and Suite Limits

- **Within this suite:** Compare row codecs on `Suite` types only for the *ingestion* path; inspect `Columnar` data types (`table`, `table_project`, `nested_table`) on the [Dashboard](../../dashboard/index.html) solely to understand single-node columnar projection and library variance (e.g., `parquet` vs. `parquet-uncompressed` vs. `arrow-ipc`).
- **Outside this suite:** Prototype representative analytical SQL queries on realistic multi-gigabyte datasets comparing compacted Parquet against raw row archives; measure **bytes scanned**, **wall-clock query time**, **storage bytes**, and **compaction compute cost**.
- **What would change the answer:** Small datasets fitting comfortably inside an OLTP read replica do not justify building a lake compaction pipeline; very small row counts ($N = 1$) lose columnar advantages to footer and metadata overhead.

---

## Discussion Prompts

1. Why does dumping raw Kafka events straight into S3 as 10 KB Parquet files every second still yield poor Spark/DuckDB query performance?

??? note "Guidance"
    Parquet relies on large row groups (tens to hundreds of megabytes) for effective dictionary/RLE compression and amortized object-store `GET`/footer reads. Writing 10 KB files per second creates millions of tiny objects where S3 metadata/listing latency and per-file footer reads dominate query time. Compaction into properly sized files is essential.

2. When is Apache Arrow IPC preferred over Apache Parquet inside this analytics platform?

??? note "Guidance"
    Use **Parquet** for durable on-disk object storage (compact page compression and statistics) and **Arrow IPC** for transient in-memory data exchange between analytical engines, UDF workers, or notebooks where zero-copy buffer sharing matters more than on-disk compression ratio.
