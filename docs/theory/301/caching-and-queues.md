# Caching and queues

## Problem

Redis, SQS, Kafka, and in-process caches all store **bytes**. Developers paste the fastest local serializer into the cache “temporarily.” Months later another language must read the key, or an attacker influences a value. The cache becomes a serialization and trust boundary that no one designed.

## Short answer

For **shared** caches and queues, use **portable** formats with an explicit schema or documented JSON contract ([trust boundaries](trust-boundaries.md), [polyglot estates](polyglot-estates.md)). Reserve language-native codecs for **single-binary, trusted, non-shared** state if the threat model allows. Separate **event log** design ([schema registries](schema-registries.md)) from **ephemeral cache** values, but do not lower the portability bar just because TTL is short. Size limits and poison-message handling matter as much as codec speed.

## Constraints that matter

| Store | Prefer | Avoid |
|-------|--------|-------|
| Cross-service Redis | JSON / MessagePack / Protobuf with schema | pickle / Java ser |
| Single-service memory cache | Native or struct OK if not shared | Accidentally exposing native via admin API |
| Durable bus | Schema culture + registry | Undocumented dual formats |
| Task queues | Portable job payloads; version field | Opaque blobs without reader |

## Decision frame

```text
  Can another process/language/version read this key?
    yes → portable + versioned contract
    no  → native optional under documented trust
```

| Concern | Practice |
|---------|----------|
| Poison messages | Dead-letter; do not infinite-retry bad payloads |
| Schema change | Version field or subject; dual-read |
| Large values | Pointer to object store + small metadata message |
| PII in queues | Retention and redaction ([payload surfaces](payload-surfaces.md)) |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| pickle in Redis “only we write” | Second service appears; or RCE |
| No max size | Memory blowups |
| Dual formats without version | Random consumers fail |
| Cache as system of record | Lost evolution story |
| Compressing without framing version | Deploy skew |

## Real-world sketch

Session cache stores MessagePack with a `v` field and a documented schema. Auth service (Go) and API (Python) share fixtures in CI. A proposal to switch to Python pickle for speed dies in review: a future Node edge worker cannot participate, and security rejects native deserialize from Redis.

## In this suite

| Resource | Role |
|----------|------|
| **Results** | Cost of candidate portable codecs in each language |
| Native entries | Cost of portability—not a green light for shared stores |
| [Using this suite](using-this-suite.md) | Local comparisons only |

## What this suite cannot tell you

- Redis eviction and hot-key design.  
- Exactly-once queue semantics.  
- Correct TTL for *your* sessions.

## Common mistakes

- “TTL is 60s so schema doesn’t matter.”  
- Storing entire user graphs per key.  
- Logging cache values that contain tokens.

## Key takeaways

- Shared stores are **interchange boundaries**.  
- Portable + versioned beats native speed on multi-service caches.  
- Queues need poison handling and contracts, not only throughput.  
- Suite picks libraries after the store’s trust model is fixed.
