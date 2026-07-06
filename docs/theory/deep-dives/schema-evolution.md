# Schema evolution that doesn’t break readers

> After this page you can plan additive changes so old and new producers/consumers can coexist—and name the rules that make “we’ll fix the client” fail.

---

## Problem

Services and data pipelines rarely deploy as a single atomic unit. For a while you always have **old readers + new writers**, **new readers + old writers**, or both. A field rename that “only our team uses,” a reused Protobuf field number, or a removed JSON key without a default can break a consumer you forgot—or corrupt analytics for a week before anyone notices.

Evolution is not a library feature you turn on. It is a **compatibility policy** plus encoding rules that make that policy possible.

---

## Short answer

Safe evolution means defining what **writers may add, remove, or change** while **readers with a different version** still obtain a correct-enough view. In practice: prefer **additive** optional fields with defaults; never repurpose identifiers (Protobuf field numbers, Avro field names under a compatibility mode, API property names without versioning); document nullability and defaults as product semantics; enforce policy in CI or a schema registry when more than one team shares the contract. “Forward” and “backward” compatibility are directional—know which way you need before you delete anything.

---

## Mental model

```text
  Time ──────────────────────────────────────────────►

  Writer v1 ──msg──► Reader v1   (happy)
  Writer v2 ──msg──► Reader v1   (old reader must ignore/skip new fields)
  Writer v1 ──msg──► Reader v2   (new reader must default missing fields)

  Breaking: same identifier, new meaning; required field appears; type changes in place
```

If your deployment cannot guarantee “all readers first” or “all writers first,” you need both directions for a period of time (**full** compatibility in registry jargon).

---

## How it works

### Directional compatibility (vocabulary)

| Term (common usage) | Meaning |
|---------------------|---------|
| **Backward compatible** change | **New code can read old data** (missing new fields → defaults) |
| **Forward compatible** change | **Old code can read new data** (unknown fields skipped / ignored) |
| **Full** | Both, for a supported window |

Exact registry definitions vary; align with your platform’s docs. The engineering idea is stable: **who moves first** constrains what you may change.

### Protobuf-style (field numbers)

- New fields get **new numbers**; mark them optional (proto3 presence rules vary by edition/feature—know your toolchain).
- **Never reuse** a field number for a new meaning; use `reserved` for deleted numbers and names.
- Renaming a field in the `.proto` without changing the number is a source-level rename; the wire may stay compatible while JSON mappings and human APIs may not.
- Changing a field’s type in place is usually a break.

### Avro-style (writer/reader schemas)

Avro’s strength is **schema resolution**: a reader schema and writer schema can differ under documented rules (defaults for fields the writer omitted, etc.). Event platforms often store a **schema id** with each record and pin compatibility modes in a **schema registry**. That is a different culture from Protobuf’s “field numbers forever,” not a strictly better one—see a future deep dive on two schema cultures; for data pipelines start from the [data science perspective](../data_science_perspective.md).

### JSON and schemaless binary

- **Additive** properties are the usual safe move; consumers should ignore unknown keys if you need forward compatibility.
- **Renames** break silently (old key absent, new key ignored by old clients).
- **Type changes** of an existing key (string → object) are breaks.
- Without a validator, “compatibility” is only as good as the worst client.

### Defaults, presence, and null

Wire formats cannot invent product meaning. Decide explicitly:

- Missing field vs explicit null vs default zero.
- Whether “0” means “unset” (usually a design smell).

Codegen and serializers differ; tests should cover **old payload × new reader** and **new payload × old reader** fixtures.

---

## Costs & constraints

| Axis | What changes with poor evolution | What discipline buys |
|------|----------------------------------|----------------------|
| Evolution risk | Outages, corrupt stores, poison messages | Rolling deploys without flag days |
| Operability | Schema archaeology under pressure | Versioned schemas and clear owners |
| Size / bandwidth | “Optional forever” fields accumulate | Periodic, planned deprecation windows |
| Tooling | Ad-hoc wiki contracts | Registry, `buf`/breaking-change CI, contract tests |
| Security / trust | Confused deputies from type changes | Explicit validation of untrusted shapes |

---

## Real-world example

A billing field `amount_cents` (int) is “replaced” by `amount` (decimal string) by reusing the same JSON key or the same Protobuf number. Half the fleet understands ints; half understands strings; a few write both. Reconciliation fails for a subset of accounts. The fix is a **new field** (or a versioned API), dual-write/dual-read for a migration window, then retire the old field with `reserved` or API deprecation—not an in-place type swap.

---

## In this suite

The benchmark fixtures assume a **stable logical model** so libraries are comparable; the suite is not a schema-registry simulator. Use deep dives and lens docs for evolution *judgment*; use **Results** for encode/decode cost of a chosen codec once the contract is fixed.

When evaluating schema-driven libraries in language overviews, assume production use still needs your compatibility process—the harness does not replace it.

---

## Common mistakes

- Reusing Protobuf field numbers or Avro names under incompatible modes.
- Deploying writers that emit a new required field before all readers understand it.
- Renaming JSON properties without versioning or dual fields.
- Treating “optional in the IDL” as “optional in the product” without defaults.
- No consumer tests against **golden payloads** from older versions.
- Deleting fields the same day you stop writing them (no drain window).

---

## Key takeaways

- Evolution is a **policy + encoding** problem under rolling deploys and long-lived data.
- Know whether you need old readers, old writers, or both during migration.
- Prefer additive optional fields with explicit defaults; never repurpose identifiers.
- JSON flexibility does not remove the need for a compatibility story.
- Registry/CI enforcement scales better than hope across teams.
- Dual-read/dual-write migration windows beat big-bang type changes.
- Test old×new and new×old payloads, not only the happy same-version path.

---
