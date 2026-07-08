# Case study: analytics lake on object storage

> Nightly and ad-hoc analytics must scan large histories efficiently—what belongs in the lake versus on the service bus?

## Context & goals

**Setting:** Product analytics and finance report on years of commerce data in object storage. Query engines (Spark/DuckDB-class) scan few columns over huge tables. Real-time services already emit events on a bus.

**Goals:** Cheap scans, reliable schema evolution for tables, clear separation from operational RPC.

## Non-goals / hard constraints

- Not low-latency checkout RPC ([internal RPC case](case-internal-rpc.md)).  
- Not browser-facing REST ([public REST case](case-public-rest-api.md)).  
- Must not force analysts to parse opaque service-only native blobs.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Columnar lake (Parquet/ORC) + catalog** | Compact jobs from events/DB into partitions |
| **B. Store Protobuf/JSON event files as the lake** | Land raw bus dumps forever |
| **C. One RPC codec for serve and lake** | “Everything is Protobuf files” |

## Trade-off matrix

| Axis | A. Columnar lake | B. Raw event dump | C. RPC codec as lake |
|------|------------------|-------------------|----------------------|
| Scan efficiency | High | Poor | Poor |
| Evolution | Table + file schema | Event culture only | Wrong tool |
| Ops | Compaction pipelines | Simple land, hard query | Simple land, hard query |
| Fit | Analytics | Temporary landing only | Anti-pattern |

## Recommendation (under these constraints)

**Prefer A:** keep operational events as row messages on the bus ([event backbone](case-event-stream.md)); **compact** into columnar partitions with a catalog. Use B only as a **landing zone** with TTL, not as the system of record for analytics. **Reject C** ([row vs columnar](row-vs-columnar.md)).

## How to validate

| Step | Where |
|------|--------|
| Event codec cost | Language **Results** for producers |
| Lake scan cost | Engine benchmarks **outside** this suite |
| Schema evolution of tables | Catalog + file metrics |
| Fair message comparisons | [Using this suite](using-this-suite.md) |

## What would change the answer

- Tiny data that fits in OLTP replicas → warehouse optional.  
- Streaming SQL directly on bus with acceptable cost → still plan compaction for history.

## Key takeaways

- Lakes want **columnar**; buses want **row events**.  
- Compaction bridges them deliberately.  
- This suite does not replace lake engine benchmarks.
