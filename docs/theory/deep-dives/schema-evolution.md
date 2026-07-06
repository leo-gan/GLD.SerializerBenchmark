# Schema evolution that does not break readers

> After reading this page, one should be able to plan additive changes so that older and newer producers and consumers can coexist, and to state the rules that make informal “we shall update the client later” strategies fail.

---

## Problem

Services and data pipelines are seldom deployed as a single atomic unit. For a period of time one invariably observes **older readers with newer writers**, **newer readers with older writers**, or both. A field rename regarded as “local to one team,” reuse of a Protocol Buffers field number, or removal of a JSON property without a defined default can break a consumer that was overlooked—or corrupt analytical results for an extended period before the defect is noticed.

Evolution is not a library feature that can be enabled with a single configuration flag. It is a **compatibility policy** together with encoding rules that make that policy feasible.

---

## Short answer

Safe evolution means defining what **writers may add, remove, or change** while **readers at a different version** still obtain a sufficiently correct view of the data. In practice one prefers **additive** optional fields with explicit defaults; one never repurposes identifiers (Protocol Buffers field numbers; Avro names under a stated compatibility mode; API property names without versioning); one documents nullability and defaults as product semantics; and one enforces policy in continuous integration or a schema registry when more than one team shares the contract. “Forward” and “backward” compatibility are **directional**—the required direction must be known before fields are deleted.

---

## Mental model

```text
  Time ──────────────────────────────────────────────────────────►

  Writer v1 ──message──► Reader v1   (matched versions)
  Writer v2 ──message──► Reader v1   (older reader must ignore unknown fields)
  Writer v1 ──message──► Reader v2   (newer reader must default missing fields)

  Breaking patterns include:
    · same identifier, new meaning
    · newly required field without a migration window
    · in-place type change of an existing field
```

If deployment cannot guarantee “all readers first” or “all writers first,” both directions must hold for a supported interval (**full** compatibility in the terminology of many schema registries).

---

## How it works

### Directional compatibility (terminology)

| Term (common usage) | Meaning |
|---------------------|---------|
| **Backward-compatible** change | **New software can read old data** (fields absent from old data receive defaults). |
| **Forward-compatible** change | **Old software can read new data** (unknown fields are skipped or ignored). |
| **Full** compatibility | Both properties hold for a defined support window. |

Exact registry definitions vary; project documentation should be authoritative. The engineering idea is stable: **which side advances first** constrains admissible changes.

### Beginner example: adding a field

Version 1 of a logical record:

| Field | Meaning |
|-------|---------|
| `order_id` | integer identifier |
| `total_cents` | integer amount |

Version 2 adds `currency_code` (string), default `"USD"` when absent.

| Interaction | Required behaviour |
|-------------|--------------------|
| Writer v2 → Reader v1 | Reader v1 must **ignore** `currency_code` if unknown, and still process `order_id` and `total_cents`. |
| Writer v1 → Reader v2 | Reader v2 must treat missing `currency_code` as **`"USD"`** (or another documented default), not as an error—unless the product deliberately requires a hard cut-over. |

If version 2 instead **renames** `total_cents` to `amount_cents` without a dual-field period, older readers stop seeing the amount (key absent) and newer readers miss older writers’ key. The failure mode is often silent.

### Protocol Buffers–style evolution (field numbers)

- New fields receive **new numbers**; they are introduced as optional (exact presence rules depend on language edition and toolchain).  
- A field number must **never** be reused for a new meaning; deleted numbers and names should be marked `reserved`.  
- Renaming a field in the `.proto` source without changing its number is a source-level rename; the binary wire form may remain compatible while JSON mappings and human-facing APIs may not.  
- Changing a field’s type in place is ordinarily a breaking change.

**Illustration — unsafe reuse:**

```text
  v1:  field 3 = total_cents (integer)
  v2:  field 3 = total (string decimal)   ← same number, new type/meaning
```

Readers compiled for v1 interpret string-shaped bytes (or a different wire type) incorrectly; mixed fleets produce inconsistent accounts.

**Illustration — safer migration:**

```text
  v1:  field 3 = total_cents (integer)
  v2:  field 3 = total_cents (integer)   still written during migration
       field 4 = total_decimal (string)  new field
  later: stop writing field 3; reserve number 3
```

### Avro-style evolution (writer and reader schemas)

Avro’s strength is **schema resolution**: a reader schema and a writer schema may differ under documented rules (for example, defaults for fields the writer omitted). Event platforms often attach a **schema identifier** to each record and fix compatibility modes in a **schema registry**. That practice is a different operational culture from “field numbers retained indefinitely,” not an automatically superior one. For analytical pipelines, see the [data science perspective](../data_science_perspective.md).

### JSON and schemaless binary formats

- **Additive** properties are the usual safe change; consumers that require forward compatibility should ignore unknown keys.  
- **Renames** fail silently (old key absent; new key ignored by older clients).  
- **Type changes** of an existing key (for example, string to object) are breaking.  
- Without automated validation, “compatibility” is only as strong as the weakest client.

**Minimal JSON examples:**

```json
// v1
{"order_id": 10, "total_cents": 1999}

// v2 additive (generally safer)
{"order_id": 10, "total_cents": 1999, "currency_code": "EUR"}

// rename without dual write (generally unsafe under mixed versions)
{"order_id": 10, "amount_cents": 1999}
```

### Defaults, presence, and null

Wire formats cannot invent product meaning. Designers must decide explicitly:

- missing field versus explicit null versus a numeric zero default;  
- whether the value `0` is allowed to mean “unset” (usually a poor design).

Code generators and serializers differ; tests should cover fixtures for **old payload × new reader** and **new payload × old reader**.

---

## Costs and constraints

| Axis | Consequence of weak evolution discipline | Benefit of disciplined practice |
|------|------------------------------------------|----------------------------------|
| Evolution risk | Service failures; corrupted stores; undeliverable messages | Rolling deployments without synchronized flag days |
| Operability | Emergency reconstruction of schema history | Versioned schemas and clear ownership |
| Size / bandwidth | Optional fields retained indefinitely accumulate | Planned deprecation windows |
| Tooling | Informal documents that drift from reality | Registry, breaking-change checks, contract tests |
| Security / trust | Misinterpretation after silent type changes | Explicit validation of untrusted shapes |

---

## Illustrative scenario

A billing field `amount_cents` (integer) is “replaced” by `amount` (decimal string) by reusing the same JSON key or the same Protocol Buffers field number. Part of the deployment still expects integers; part expects strings; some components write both. Reconciliation fails for a subset of accounts. A sound approach introduces a **new field** (or a versioned API), dual-writes and dual-reads during a migration window, then retires the old field with `reserved` markers or formal API deprecation—not an in-place type substitution.

---

## In this suite

Benchmark fixtures assume a **stable logical model** so that libraries remain comparable; the suite is not a schema-registry simulator. Use these deep dives and the perspective documents for evolutionary *judgment*; use **Results** for encode and decode cost of a chosen codec once the contract is fixed.

When evaluating schema-driven libraries on language overview pages, production use still requires an organization’s own compatibility process—the harness does not replace it.

---

## Common errors of practice

- Reusing Protocol Buffers field numbers or Avro names under incompatible modes.  
- Deploying writers that emit a newly required field before all readers understand it.  
- Renaming JSON properties without versioning or a dual-field period.  
- Treating “optional in the interface description” as “optional in the product” without defaults.  
- Omitting consumer tests against **reference payloads** from older versions.  
- Deleting fields on the same day writers stop emitting them (no drain interval).

---

## Key takeaways

- Evolution is a **policy together with encoding rules** under rolling deployment and long-lived data.  
- Determine whether older readers, older writers, or both must be supported during migration.  
- Prefer additive optional fields with explicit defaults; never repurpose identifiers.  
- Flexibility of JSON does not remove the need for a compatibility strategy.  
- Registry and continuous-integration enforcement scale more reliably than informal coordination alone.  
- Dual-read and dual-write migration windows are preferable to simultaneous type changes.  
- Test old×new and new×old payloads, not only matched-version paths.

---
