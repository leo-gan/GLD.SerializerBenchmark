# Schema registries and compatibility modes

> After reading this page, one should be able to choose and enforce registry compatibility modes as an operating policy—not as a library feature checkbox.

## Problem

Event platforms and multi-team producers need a **control plane** for schemas: where the current schema lives, who may publish a new version, and which old reader/writer combinations remain legal. Without a registry (or equivalent), “we use Avro/Protobuf” becomes tribal knowledge and production breaks on the first incompatible field.

## Short answer

A **schema registry** (or monorepo + CI that plays the same role) stores versioned schemas and evaluates **compatibility** before a new version is accepted. Common modes—**BACKWARD**, **FORWARD**, **FULL** (and *transitive* variants)—encode which rolling-upgrade stories you support. Pick the mode from deploy topology; enforce it in CI/CD; never rely on human review alone at scale. Culture still matters ([two schema cultures](two-schema-cultures.md)): resolution-oriented stacks lean on registry modes; field-number stacks lean on IDL breaking-change detection—both need a gate.

Assumes 201 [schema evolution](../201/schema-evolution.md).

## Constraints that matter

| Mode (typical meaning) | Protects | Allows (illustrative) |
|------------------------|----------|------------------------|
| **BACKWARD** | New **readers** understand old data | Delete fields readers no longer need; add optional fields carefully per product rules |
| **FORWARD** | New **writers** understood by old readers | Add fields old readers skip; restrict removing what old readers need |
| **FULL** | Both directions | Strictest common intersection |
| **\*_TRANSITIVE** | Across **all** historical versions, not only N vs N-1 | Long retention / many live versions |

Exact rules differ by system (Confluent Avro, Protobuf policies, JSON Schema stores)—read *your* registry docs; do not memorize one vendor table as universal law.

## Decision frame

```text
  Must old consumers read new producers?  → need FORWARD-ish guarantees
  Must new consumers read old data (lag, replay)? → need BACKWARD-ish guarantees
  Both (common for shared topics)? → FULL or FULL_TRANSITIVE
  Single lockstep deploy of all parties? → still version schemas; mode may be looser
```

| Situation | Lean toward |
|-----------|-------------|
| Long retention, replay, many consumer versions | Transitive + BACKWARD or FULL |
| Short-lived topics, few consumers | BACKWARD may suffice |
| IDL monorepo, no registry product | Breaking-change CI + review = functional registry |
| No enforcement | You do not have a registry—you have a wiki |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Registry without auth/ACLs | Anyone publishes breaking schemas |
| Mode never set (default surprise) | First break is in production |
| Compatibility only N vs N-1 with long retention | Version N-5 still in data, breaks |
| Dual registries / dual subjects per event | Split brain |
| Treating registry as optional for “small” teams | Growth debt |

## Real-world sketch

A payments topic uses Avro with BACKWARD. A producer removes a field still read by a slow fraud consumer. Registry rejects the schema in CI; the team dual-writes or waits for consumer lag to drain. Without the gate, the break appears as cryptic deserialize errors at 02:00.

## In this suite

| Resource | Role |
|----------|------|
| **Results** | Codec cost only—not registry behavior |
| [Two schema cultures](two-schema-cultures.md) | Which control plane you run |
| [Case: event backbone](case-event-stream.md) | End-to-end recommendation |

## What this suite cannot tell you

- Which vendor registry to buy.  
- Exact mode matrix for your schema language.  
- How long dual-write must last.

## Common mistakes

- Enabling a registry but skipping CI checks (publish from laptops).  
- Using FULL when the org cannot meet it—then bypassing the registry.  
- Ignoring subject naming (per topic vs per record type).

## Key takeaways

- Registries encode **policy as automation**.  
- Modes follow **who upgrades first** and **how long data lives**.  
- Enforcement in the path of deploy matters more than dashboard green checks.  
- Suite timings do not replace compatibility testing.
