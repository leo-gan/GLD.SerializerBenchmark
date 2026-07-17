# Case study: analytics lake on object storage

> Nightly and ad-hoc analytics must scan large histories efficiently. What belongs in the lake versus on the service bus?

## Context and goals

**Setting:** Product analytics and finance report on years of commerce data in object storage. Query engines in the Spark or DuckDB class scan a few columns over huge tables. Real-time services already emit events on a bus.

**Goals:** Cheap scans, reliable schema evolution for tables, and a clear separation from operational RPC.

## Non-goals and hard constraints

- This is not low-latency checkout RPC ([internal RPC case](case-internal-rpc.md)).
- This is not browser-facing REST ([public REST case](case-public-rest-api.md)).
- Analysts must not be forced to parse opaque service-only native blobs.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Columnar lake (Parquet/ORC) plus catalog** | Compact jobs turn events or database extracts into partitions |
| **B. Store Protobuf/JSON event files as the lake** | Land raw bus dumps forever |
| **C. One RPC codec for serve and lake** | “Everything is Protobuf files” |

## Trade-off matrix

| Axis | A. Columnar lake | B. Raw event dump | C. RPC codec as lake |
|------|------------------|-------------------|----------------------|
| Scan efficiency | High | Poor | Poor |
| Evolution | Table and file schema | Event culture only | Wrong tool |
| Operations | Compaction pipelines | Simple to land, hard to query | Simple to land, hard to query |
| Fit | Analytics | Temporary landing only | Anti-pattern |

## Recommendation (under these constraints)

**Prefer A:** keep operational events as row messages on the bus ([event backbone](case-event-stream.md)); **compact** them into columnar partitions with a catalog. Use B only as a **landing zone** with time-to-live, not as the system of record for analytics. **Reject C** ([row vs columnar](row-vs-columnar.md)).

## Experiments

**Question:** For the lake path and the stated query mix, how does a columnar analytical format compare with storing row event dumps?

### Setup

1. Representative analytical queries and data volume.
2. Candidates: Parquet, ORC, or Arrow versus raw JSON or Avro row dumps.
3. A cluster or local prototype with the same dataset.

### Procedure

1. Load the same data into row dumps and columnar tables.
2. Run the query set; record wall time and bytes read.
3. Measure storage footprint.
4. Confirm the ingest path still uses an appropriate **row** codec if needed.
5. Reject “use RPC Protobuf files as the lake.”

### Decision rule

- When scan queries dominate, choose columnar.
- When only point lookup of whole events is needed, a row store may suffice (rare for a true “lake”).

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Query wall time and bytes scanned** | **Primary** |
| Storage bytes | Cost |
| Ingest throughput | Pipeline fit |
| Suite row-codec metrics | Ingest hop only |
| Compression ratio | Secondary |

## What would change the answer

- Tiny data that fits in OLTP replicas can make a warehouse optional.
- Streaming SQL directly on the bus with acceptable cost still needs a plan for compacting history.

## Key takeaways

- Lakes want **columnar** storage; buses want **row events**.
- Compaction bridges them deliberately.
- This suite does not replace lake engine benchmarks.
