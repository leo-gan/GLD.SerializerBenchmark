# Schema registries and compatibility modes

## Problem

Event platforms and multi-team producers need a **control plane** for schemas: where the current schema lives, who may publish a new version, and which old reader and writer combinations remain legal.

Without a **schema registry** (or an equivalent process), “we use Avro” or “we use Protobuf” becomes tribal knowledge, and production breaks on the first incompatible field. In plain language, a registry is a catalog of allowed message shapes, with automation that rejects illegal changes before they reach production.

---

## Short answer

A **schema registry** (or a monorepo plus continuous integration that plays the same role) stores versioned schemas and evaluates **compatibility** before a new version is accepted. Common modes—**BACKWARD**, **FORWARD**, **FULL**, and their *transitive* variants—encode which rolling-upgrade stories you support.

**Compatibility** means “this combination of old and new software can still exchange data correctly.” The mode you pick is a product decision about deploy order and data lifetime, not a universal ranking of formats.

Pick the mode from your deploy topology. Enforce it in CI/CD. Never rely on human review alone once more than a handful of teams publish schemas.

Culture still matters ([two schema cultures](two-schema-cultures.md)). Resolution-oriented stacks lean on registry modes. Field-number stacks lean on IDL breaking-change detection. Both need a gate in the deploy path.

This page assumes 201 [schema evolution](../201/schema-evolution.md).

---

## Constraints that matter

| Mode (typical meaning) | Protects | Allows (illustrative) |
|------------------------|----------|------------------------|
| **BACKWARD** | New **readers** still understand old data | Delete fields that readers no longer need; add optional fields carefully per product rules |
| **FORWARD** | New **writers** are still understood by old readers | Add fields that old readers skip; restrict removing fields that old readers still need |
| **FULL** | Both directions at once | The strictest common intersection of BACKWARD and FORWARD |
| **\*_TRANSITIVE** variants | Compatibility across **all** historical versions, not only version N versus N−1 | Long retention windows and many live schema versions |

In other words:

- **BACKWARD** answers: “Can the new consumer still read yesterday’s messages?”
- **FORWARD** answers: “Can the old consumer still read today’s messages?”
- **FULL** answers: “Both of the above, during the support window.”
- **Transitive** modes also check older historical versions, not only the previous version.

Exact rules differ by system (Confluent Avro, Protobuf policies, JSON Schema stores, and others). Read *your* registry documentation. Do not memorize one vendor’s table as universal law.

---

## Decision frame

```text
  Must old consumers read new producers?
        → you need FORWARD-style guarantees
  Must new consumers read old data (lag, replay)?
        → you need BACKWARD-style guarantees
  Both (common for shared topics)?
        → FULL or FULL_TRANSITIVE
  Single lockstep deploy of all parties?
        → still version schemas; the mode may be looser
```

| Situation | Lean toward |
|-----------|-------------|
| Long retention, replay, many consumer versions | Transitive checks plus BACKWARD or FULL |
| Short-lived topics with few consumers | BACKWARD may suffice |
| IDL monorepo without a registry product | Breaking-change CI plus review acts as a functional registry |
| No enforcement at all | You do not have a registry—you have a wiki |

This matters because a green “registry is running” dashboard is not the same as “incompatible schemas cannot ship.”

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Registry without authentication or access-control lists (ACLs) | Anyone can publish breaking schemas |
| Compatibility mode never set (default surprise) | The first break happens in production |
| Compatibility checked only for N versus N−1 while retention is long | Version N−5 still exists in the data and breaks readers |
| Dual registries or dual subjects per event | Split brain about which schema is canonical |
| Treating the registry as optional for “small” teams | Growth debt that appears when the team is no longer small |

For example, if messages live for six months but you only check “new schema versus previous,” an old consumer replaying month-old data can still fail.

---

## Real-world sketch

A payments topic uses Avro with BACKWARD compatibility. A producer removes a field that a slow fraud consumer still reads. The registry rejects the schema in CI. The team either dual-writes for a while or waits for consumer lag to drain. Without that gate, the break appears as cryptic deserialize errors at 02:00.

---

## In this suite

| Resource | Role |
|----------|------|
| **Results** | Codec cost only—not registry behavior |
| [Two schema cultures](two-schema-cultures.md) | Which control plane you are running |
| [Case: event backbone](case-event-stream.md) | End-to-end recommendation under rolling deploy |

---

## Experiments

**Question:** Which **compatibility mode** and registry workflow should govern this subject, and does a dry-run change pass?

### Setup

1. Identify the subject or subjects, the registry product, and the producer/consumer deploy order.
2. Draft a realistic schema evolution: add an optional field, then attempt a known break.
3. Ensure access to the registry API or a CI check that calls the compatibility endpoint.

### Procedure

1. Set the proposed mode (for example BACKWARD for a consumer-first deploy order).
2. Register the new schema in a **dev** subject and confirm that accept/reject matches intent.
3. Try a known-breaking change and confirm a **reject**.
4. Roll a canary producer or consumer and watch lag and errors. A **canary** is a small fraction of production traffic used to validate a change safely.
5. Document the mode and who is allowed to register.

### Decision rule

- The mode must match deploy order (see the decision frame).
- If the registry cannot reject breaks, you do not have registry-enforced compatibility—fix the process or the tool.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Compatibility check result** (pass or fail) | **Primary** experiment outcome |
| Chosen mode (BACKWARD / FORWARD / FULL / NONE) | Policy variable |
| Time to detect an incompatible schema in production | Safety lag |
| Consumer error rate on the canary | Empirical validation |
| Registration ACL violations | Process hygiene |
| Suite serialize/deserialize metrics | Irrelevant to mode choice |

**Conclusion style:** “Subject `orders.v1` stays on BACKWARD; the breaking change is rejected in CI.”

---

## What this suite cannot tell you

- Which vendor registry to buy.
- The exact mode matrix for your schema language.
- How long a dual-write period must last in your estate.

---

## Common mistakes

- Enabling a registry but skipping CI checks so people publish from laptops.
- Using FULL when the organization cannot meet it—and then bypassing the registry.
- Ignoring subject naming conventions (per topic versus per record type).

---

## Key takeaways

- Registries encode **policy as automation**.
- Modes follow **who upgrades first** and **how long data lives**.
- Enforcement in the deploy path matters more than a green dashboard check.
- Suite timings do not replace compatibility testing.
