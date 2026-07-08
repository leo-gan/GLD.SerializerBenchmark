# RPC and messaging payload design

## Problem

Teams reuse the same payload for synchronous RPC, fan-out events, and UI refresh. The result is chatty RPCs carrying analytics blobs, or events so large that consumers collapse. Serialization format debates hide a prior question: **what is the unit of work, and who needs which fields?**

## Short answer

Design **message shape** from access pattern: small, stable records for high-QPS RPC; explicit event types for async backbones; projections or separate APIs for “wide” reads. Prefer **narrow messages** plus references (ids) over embedding entire aggregates on every hop. Partial reads and zero-copy help only when the layout matches the access pattern (201 [zero-copy](../201/zero-copy.md), [zero-copy in production](zero-copy-in-production.md)). Idempotency and ordering are product properties—codecs do not invent them.

## Constraints that matter

| Pattern | Payload bias |
|---------|----------------|
| **Request/response RPC** | Minimal fields for the decision; low allocation |
| **Async event** | Fact + ids + enough context for consumers; stable evolution |
| **Fan-out** | One event, many consumers → avoid single-consumer bloat |
| **Streaming partial** | Chunking / pagination; not one multi-MB JSON |
| **Idempotent command** | Stable command id; dedupe keys outside pure codec choice |

## Decision frame

```text
  Sync decision path? → thin RPC DTO, schema-driven often
  Multiple independent consumers? → event types, not “god struct”
  Need most fields rarely? → split messages or query API
```

| Smell | Redesign |
|-------|----------|
| RPC returns entire customer graph “just in case” | Field masks / separate resources |
| Event embeds PDF bytes | Object-store pointer + metadata event |
| Same proto for UI list and fraud pipeline | Separate contracts or views |
| Mutation of shared buffer across threads | Copy or freeze policy |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| God message | Every change breaks everyone |
| Chatty fine-grained RPC without batching | Latency death by RTT |
| Huge events on the hot bus | Consumer lag |
| Relying on codec for exactly-once | False safety |
| Mixing command and event semantics | Replay nightmares |

## Real-world sketch

Checkout RPC needs auth result and risk score—tens of fields. Marketing wants full cart contents on `OrderPlaced`. One Protobuf is forced to carry both. Fraud p99 suffers; marketing still joins to a catalog service. Split: thin `AuthorizePayment` RPC; `OrderPlaced` event with line-item ids; marketing consumer loads details asynchronously.

## In this suite

| Resource | Role |
|----------|------|
| Fixtures | Record shapes for codec cost—not architecture proof |
| **Results** | Cost of encoding a *given* shape |
| [Row vs columnar](row-vs-columnar.md) | Batch analytics path |
| [Using this suite](using-this-suite.md) | Same fixture when comparing libs |

## What this suite cannot tell you

- Correct service boundaries.  
- Kafka partition key design.  
- Whether field masks are supported in your RPC stack.

## Common mistakes

- Optimizing codec while messages stay bloated.  
- “We’ll filter in the consumer” as a permanent design.  
- Ignoring idempotency keys because Protobuf is deterministic.

## Key takeaways

- **Shape first, codec second.**  
- RPC and messaging want different payload economics.  
- Fan-out punishes god structs.  
- Suite measures encode cost of the shape you already chose.
