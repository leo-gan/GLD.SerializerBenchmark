# Caching and queues

## Problem

Redis, SQS, Kafka, and in-process caches all store **bytes**. Developers paste the fastest local serializer into the cache “temporarily.” Months later another language must read the key. Or an attacker influences a value. The cache becomes a serialization and trust boundary that no one designed.

In plain language: a cache or queue is not “just memory for us.” It is a store that other processes may open. Other languages may open it. Future versions of your service may open it. Design it that way from the start.

---

## Short answer

For **shared** caches and queues, use **portable** formats. Use an explicit schema or a documented JSON contract. See [trust boundaries](trust-boundaries.md) and [multi-language systems (polyglot estates)](polyglot-estates.md). Reserve language-native codecs for **single-binary, trusted, non-shared** state. That is only if the written security assumptions allow it.

Separate **event log** design from **ephemeral cache** values. See [schema registries](schema-registries.md) for event logs. Do not lower the portability bar just because time-to-live (TTL) is short. **TTL** is how long a key or message is allowed to live before automatic expiry. Size limits and poison-message handling matter as much as codec speed.

A **poison message** is a payload that repeatedly fails processing. It may be corrupt, too large, or schema-invalid. Without quarantine, it can crash a consumer loop forever.

---

## Constraints that matter

| Store | Prefer | Avoid |
|-------|--------|-------|
| Cross-service Redis | JSON, MessagePack, or Protobuf with a schema | pickle or Java serialization |
| Single-service memory cache | Native encoding or plain structs are OK if not shared | Accidentally exposing native values via an admin API |
| Durable bus | Schema culture plus a registry | Undocumented dual formats |
| Task queues | Portable job payloads with a version field | Opaque blobs with no documented reader |

This matters because “only our service writes Redis today” often becomes “three services read it next quarter.”

---

## Decision frame

```text
  Can another process, language, or version read this key?
    yes → portable + versioned contract
    no  → native is optional under documented trust
```

| Concern | Practice |
|---------|----------|
| Poison messages | Send them to a dead-letter queue; do not infinite-retry bad payloads |
| Schema change | Use a version field or subject; dual-read during transition |
| Large values | Store a pointer to object storage plus a small metadata message |
| PII in queues | Apply retention and redaction ([payload surfaces](payload-surfaces.md)) |

In other words, short TTL reduces how long a bad encoding lives. It does not make an unsafe format safe while it lives.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| pickle in Redis “only we write” | A second service appears later, or remote code execution becomes possible |
| No maximum size | Memory blowups |
| Dual formats without a version | Random consumers fail |
| Cache used as system of record | The evolution story is lost |
| Compressing without a framing version | Deploy skew between writers and readers |

---

## Real-world sketch

A session cache stores MessagePack with a `v` version field and a documented schema. The auth service (Go) and the API (Python) share fixtures in continuous integration. A proposal to switch to Python pickle for speed dies in review. A future Node edge worker could not participate. Security also rejects native deserialize from Redis.

---

## In this suite

| Resource | Role |
|----------|------|
| **Dashboard** | Cost of candidate portable codecs in each language |
| Native entries | Cost of portability—not a green light for shared stores |
| [Using this suite](using-this-suite.md) | Local comparisons only |

---

## Experiments

**Question:** Are shared **cache and queue** payloads portable, versioned, and safe for every consumer that can read them?

### Setup

1. List cache keys or topics and all reader services and languages.
2. Note the current encoding. Often it is native or ad hoc JSON.
3. Record TTL, poison-message handling, and dead-letter queue behavior.

### Procedure

1. Apply the trust-boundary test. Multi-service or multi-language readers require a portable format.
2. Encode a golden fixture. Consume it from each reader. Check logical equality.
3. Deploy a compatible schema change. Confirm old readers still work.
4. Inject a poison payload. Confirm quarantine rather than crash loops.
5. Use the suite for size and speed among allowed portable codecs. Measure against the payload budget.

### Decision rule

- Any cross-service reader plus native encoding means migrate to portable.
- No poison handling means fix operations before chasing serialize benchmarks.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Reader language and service count** | **Primary** portability driver |
| Interop matrix pass rate | Correctness |
| Poison and DLQ rate | Operational safety |
| Payload size at p95 versus broker or cache limits | Capacity |
| Schema evolution success | Longevity |
| Suite size and deserialize time | Cost among portable options |

**Conclusion style:** “The Redis blob is portable Protobuf; native cache encoding has been removed.”

---

## What this suite cannot tell you

- Redis eviction policy and hot-key design.
- Exactly-once queue semantics.
- The correct TTL for *your* sessions.

---

## Common mistakes

- “TTL is 60 seconds, so schema doesn’t matter.”
- Storing entire user graphs per key.
- Logging cache values that contain tokens.

---

## Key takeaways

- Shared stores are **interchange boundaries**.
- Portable and versioned formats beat native speed on multi-service caches.
- Queues need poison handling and contracts. Throughput alone is not enough.
- The suite picks libraries after the store’s trust model is fixed.
