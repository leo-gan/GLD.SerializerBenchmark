# RPC and messaging payload design

## Problem

Teams often reuse the same payload for synchronous RPC (remote procedure call), fan-out events, and user-interface refresh. The result is chatty RPCs that carry analytics blobs, or events so large that consumers fall behind. Serialization format debates hide a prior question: **what is the unit of work, and who needs which fields?**

## Short answer

Design **message shape** from the access pattern. Use small, stable records for high-QPS (high requests-per-second) RPC. Use explicit event types for async backbones. Use projections or separate APIs for “wide” reads. Prefer **narrow messages** plus references (identifiers) over embedding entire aggregates on every hop.

Partial reads and zero-copy help only when the layout matches the access pattern (see 201 [zero-copy](../201/zero-copy.md) and [zero-copy in production](zero-copy-in-production.md)). Idempotency and ordering are product properties—codecs do not invent them.

## Constraints that matter

| Pattern | Payload bias |
|---------|----------------|
| **Request/response RPC** | Minimal fields for the decision; keep allocations low |
| **Async event** | The fact, identifiers, and enough context for consumers; stable evolution |
| **Fan-out** | One event, many consumers—avoid bloating the event for a single consumer |
| **Streaming partial results** | Chunking or pagination; not one multi-megabyte JSON blob |
| **Idempotent command** | Stable command identifier; dedupe keys live outside pure codec choice |

## Decision frame

```text
  Sync decision path?
        → thin RPC data-transfer object; schema-driven is often a good fit
  Multiple independent consumers?
        → distinct event types, not one “god struct”
  Need most fields only rarely?
        → split messages or add a query API
```

| Smell | Redesign |
|-------|----------|
| RPC returns the entire customer graph “just in case” | Field masks or separate resources |
| Event embeds PDF bytes | Object-store pointer plus a small metadata event |
| Same proto for the UI list and the fraud pipeline | Separate contracts or views |
| Mutation of a shared buffer across threads | Copy or freeze policy |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| God message that carries everything | Every change breaks everyone |
| Chatty fine-grained RPC without batching | Latency death by network round-trip time (RTT) |
| Huge events on the hot bus | Consumer lag |
| Relying on the codec for exactly-once delivery | False safety |
| Mixing command and event semantics | Replay nightmares |

## Real-world sketch

Checkout RPC needs an authorization result and a risk score—tens of fields. Marketing wants full cart contents on `OrderPlaced`. One Protobuf is forced to carry both. Fraud p99 (99th-percentile latency) suffers, and marketing still has to join a catalog service.

A better split: a thin `AuthorizePayment` RPC; an `OrderPlaced` event with line-item identifiers; and a marketing consumer that loads details asynchronously.

## In this suite

| Resource | Role |
|----------|------|
| Fixtures | Record shapes for codec cost—not architecture proof |
| **Results** | Cost of encoding a *given* shape |
| [Row vs columnar](row-vs-columnar.md) | Batch analytics path |
| [Using this suite](using-this-suite.md) | Same fixture when comparing libraries |

## Experiments

**Question:** Should this payload be optimized as **sync RPC** (latency, small messages) or **async messaging** (throughput, fan-out, evolution)?

### Setup

1. Measure or estimate requests per second, fan-out, maximum acceptable p99, and message retention.
2. Note whether consumers tolerate lag.
3. List candidate families for each style.

### Procedure

1. Classify the hop with the decision frame.
2. For RPC-like hops: use the suite plus a load test on encode/decode latency and size.
3. For messaging: prioritize schema evolution, registry health, and consumer lag under burst—not only mean serialize time.
4. Reject designs that use chatty RPC patterns on bulk fan-out topics (or the reverse).
5. Document payload size budgets per pattern.

### Decision rule

- Strict sync service-level objectives with request/response traffic call for an RPC-shaped codec and size budget.
- Multi-consumer durable streams are dominated by messaging evolution and backlog metrics.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **RPC p99 and timeout budget** | **Primary** for sync hops |
| Message size at p95 | Network and serialize cost |
| Suite `ser_median_ns`, `deser_median_ns`, and size | Codec shortlist |
| Consumer lag and throughput | **Primary** for async hops |
| Schema-change failure rate | Messaging evolution health |
| Fan-out factor | Amplification of size and CPU |

**Conclusion style:** “User RPC uses small Protobuf messages; the audit topic uses Avro plus a registry; each path has its own size budget.”

## What this suite cannot tell you

- Correct service boundaries for your domain.
- Kafka partition key design.
- Whether field masks are supported in your RPC stack.

## Common mistakes

- Optimizing the codec while messages stay bloated.
- Treating “we’ll filter in the consumer” as a permanent design.
- Ignoring idempotency keys because Protobuf encoding is deterministic.

## Key takeaways

- **Shape first, codec second.**
- RPC and messaging want different payload economics.
- Fan-out punishes god structs.
- The suite measures encode cost of the shape you already chose.
