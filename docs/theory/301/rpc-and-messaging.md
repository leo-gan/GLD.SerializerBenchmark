# 3.7 RPC, Messaging, Caches, and Queues

## Problem Statement

Operational teams frequently reuse a single bloated domain object across synchronous RPCs, asynchronous event buses, Redis caches, and background task queues. That conflation triggers two recurring pathologies:

1. **Payload shape mismatch:** Synchronous high-QPS RPCs serialize unused analytics subgraphs, while fan-out event topics ship megabyte payloads that cause consumer lag.
2. **Undesigned storage boundaries:** Engineers place a fast language-native serializer (such as `pickle` or Java serialization) into Redis or a task queue as a "temporary internal optimization," only to create a security vulnerability and lock out future services written in other languages.

Before selecting a serialization library, architects must design the **payload shape** for the communication pattern and treat every shared cache or queue as a **cross-process interchange boundary**.

---

## Synchronous RPC vs. Asynchronous Messaging

RPC (request/response) and asynchronous messaging (publish/subscribe event streams) optimize for different failure modes and cost curves:

| Dimension | Synchronous RPC | Asynchronous Messaging / Event Stream |
|---|---|---|
| **Primary metric** | Per-request tail latency ($p_{99}$) and timeout budget | Consumer lag, throughput, durable replay, and evolution |
| **Payload shape** | Narrow **data-transfer object (DTO)** containing only fields needed for the decision | Self-contained business fact plus entity IDs; stable across years |
| **Amplification risk** | Network RTT from chatty fine-grained calls | **Fan-out amplification:** $K$ independent consumers multiply wire bytes and CPU by $K \cdot S$ |
| **Large binary attachments** | Stream or return signed URL | **Claim-check pattern:**[^1] store blob in object storage; publish pointer + metadata |
| **Semantic guarantees** | Caller observes immediate success/error | At-least-once delivery is typical; consumers must enforce **idempotency** via stable keys |

### Payload Shape Rules

```text
  Synchronous decision path (high QPS, tight p99)?
        → narrow, flat RPC DTO; avoid embedding unrelated nested aggregates
  Asynchronous topic with K independent consumers?
        → distinct, versioned event types per domain fact (avoid a single "god struct")
  Payload includes large blobs (PDFs, images, multi-MB arrays)?
        → apply the Claim-Check pattern (object-store URI + digest + small metadata event)
```

Two common misconceptions deserve explicit correction:

- **Format optimization cannot fix a bloated DTO.** Switching a 50 KB "god struct" from JSON to Protocol Buffers saves less CPU and bandwidth than splitting it into a 300-byte authorization DTO and an asynchronous detail query.
- **Deterministic encoding does not provide exactly-once delivery.** Encoding the same command into identical wire bytes does not prevent duplicate execution under network retries or broker redelivery. Idempotency requires explicit deduplication keys and transactional state management at the consumer.[^2]

---

## Shared Caches and Queues {#caching-and-queues}

!!! note "Rule: Shared Infrastructure Is an Interchange Boundary"
    Any Redis key, Memcached entry, SQS queue, or Kafka topic that can be read by another process, another language, or a future deployment of the same service is an **interchange boundary**. It requires a **portable, versioned format** and falls under the trust rules of [3.1 Trust boundaries](trust-boundaries.md).

Treating a shared cache or queue as "private memory" fails in four predictable ways:

1. **The short-TTL myth:** A 60-second time-to-live (TTL) bounds how long a corrupt or hostile value *persists*, not whether an unsafe deserializer executes arbitrary code during those 60 seconds. Nor does short TTL prevent rolling-deployment skew when version $v_1$ and version $v_2$ share the same cache keys simultaneously.
2. **Poison messages without quarantine:** A single malformed, oversized, or schema-incompatible task in a queue can crash a consumer in an infinite retry loop, stalling the entire partition. Every queue requires bounded retries and a **Dead-Letter Queue (DLQ)**[^1] to isolate poison payloads for inspection.
3. **Unversioned cache blobs:** Changing a cached struct's layout or enabling compression without a key namespace or format version tag (e.g., `user:v2:{id}` or an explicit header byte) causes silent decode failures during rolling deploys.
4. **Unredacted secrets in queues and caches:** Session tokens, PII, and credentials written into shared stores inherit the store's backup, snapshot, and replication exposure (see [3.2 Untrusted input and payload surfaces](untrusted-input.md#payload-surfaces)).

| Store Class | Recommended Encoding | Operational Safeguards |
|---|---|---|
| **Cross-service Redis / Memcached** | Portable binary (Protobuf, MessagePack) or schema-documented JSON | Key-version prefix (`v2:`), maximum value size cap, no native codecs |
| **Strictly in-process memory cache** | Plain language structs (no serialization needed) | Never expose raw native dumps across admin or debug endpoints |
| **Background task queues (SQS, RabbitMQ, Celery)** | Versioned portable JSON or Protobuf job envelope | Explicit `schema_version`, idempotency key, max-retry cap + DLQ |
| **Durable event logs (Kafka, Pulsar)** | Avro or Protobuf + enforced Schema Registry | Compatibility modes ([3.3 Schema cultures](two-schema-cultures.md)), retention & PII policy |

---

## Verification Checklist and Benchmark Limits

Before deploying a new RPC, event, cache, or queue contract:

1. **Audit payload shape and fan-out:** Measure $p_{95}$ payload size against broker/cache limits and multiply by consumer fan-out $K$ to estimate aggregate decode CPU and network egress.
2. **Enforce versioned keys or envelopes:** Verify that rolling upgrades (old writer $\leftrightarrow$ new reader and new writer $\leftrightarrow$ old reader) read or cleanly cache-miss without throwing unhandled exceptions.
3. **Fault-inject poison payloads:** Push a truncated, oversized, and schema-invalid message into a staging queue and confirm it moves to the DLQ after the configured retry limit without halting healthy traffic.
4. **Shortlist portable codecs on the Dashboard:** Once shape, trust, and versioning are fixed, compare candidate portable implementations for your runtime and record shape on the [Dashboard](../../dashboard/index.html).

**Limits of this benchmark suite:** Codec timings measure serialize/deserialize cost for a fixed shape; they do not evaluate service boundaries, Kafka partition-key skew, Redis eviction policies, broker backpressure, or transactional outbox/idempotency implementations.

---

## Exercises

1. **Fan-out amplification:** An `OrderPlaced` event currently embeds a 40 KB product-catalog snapshot required by only 1 of 12 downstream consumers, at 2,000 events/second. Without the snapshot, the event is 1 KB. Compute the excess aggregate consumer ingress bandwidth caused by the god struct, and propose the structural fix.

??? note "Solution"
    - **With snapshot:** $12 \times 40\text{ KB} \times 2{,}000\text{/s} = 960\text{ MB/s}$ aggregate consumer ingress.
    - **Without snapshot:** $12 \times 1\text{ KB} \times 2{,}000\text{/s} = 24\text{ MB/s}$ — removing **936 MB/s** of unnecessary network transfer and decode CPU across the 11 unaffected consumers.
    - **Fix:** Emit a narrow 1 KB `OrderPlaced` event carrying item IDs (or an object-store claim-check pointer), and let the single consumer that needs catalog details fetch or join them independently.

2. **Rolling-deploy cache skew:** A Python service currently caches user sessions in Redis using `pickle` with a 120-second TTL. The team argues `pickle` is acceptable because "only our service accesses Redis and keys expire in two minutes." Give two distinct reasons why this design should be rejected.

??? note "Solution"
    1. **Trust and RCE exposure:** Any Redis misconfiguration, SSRF, or compromised sibling process with Redis write access achieves immediate remote code execution in the Python service regardless of the 120-second TTL.
    2. **Rolling-deploy and polyglot lock-in:** Class refactors during rolling deployments break `pickle` deserialization between old and new replicas, and any future Go or TypeScript edge service cannot read the session store. Replace with version-prefixed portable JSON or MessagePack/Protobuf.

3. **Poison-message resilience:** A queue consumer decodes incoming JSON task payloads and crashes on `KeyError` whenever a malformed job arrives, causing the broker to redeliver the same job immediately. What two operational controls are missing?

??? note "Solution"
    1. **Boundary schema validation and structured error classification:** Distinguish permanent deserialization/validation errors (non-retryable) from transient downstream failures (retryable).
    2. **Bounded retries with a Dead-Letter Queue (DLQ):** Route malformed payloads directly to a monitored DLQ after failing validation so the consumer continues processing valid jobs.

---

## References

[^1]: Hohpe, G., & Woolf, B. (2003). *Enterprise Integration Patterns* (Claim Check; Dead Letter Channel). Addison-Wesley.
[^2]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 11 (*Stream Processing*). O'Reilly Media.
