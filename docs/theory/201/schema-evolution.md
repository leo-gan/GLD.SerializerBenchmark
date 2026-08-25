# Schema evolution

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/schema_evolution.ipynb)
**Lab notebook:** [Schema evolution lab](../notebooks/201/schema_evolution.ipynb)


## Problem

Services and data pipelines are seldom deployed as a single atomic unit. For a while you almost always have **older readers with newer writers**, **newer readers with older writers**, or both. A field rename that one team treats as “local” can break a consumer that was overlooked. Reuse of a Protocol Buffers field number can do the same. Removal of a JSON property without a defined default can break consumers or corrupt analytical results for a long time before anyone notices.

**Schema evolution** is the practice of changing a data contract over time without breaking systems that still use an older or newer version of that contract. Evolution is not a library feature you enable with one configuration flag. It is a **compatibility policy** together with encoding rules that make that policy feasible.

---

## Short answer

Safe evolution means defining what **writers may add, remove, or change** while **readers at a different version** still obtain a sufficiently correct view of the data.

In practice you prefer **additive** optional fields with explicit defaults. You never repurpose identifiers. Protocol Buffers field numbers, Avro names under a stated compatibility mode, and API property names without versioning are all identifiers in this sense. You document nullability and defaults as product semantics. When more than one team shares the contract, you enforce policy in continuous integration or a **schema registry**. A schema registry is a service that stores versioned schemas. It often checks whether a proposed change is compatible.

“Forward” and “backward” compatibility are **directional**. You need to know which direction matters before you delete fields. In other words: “compatible” is not a single yes/no property. It depends on who advances first.

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

If deployment cannot guarantee “all readers first” or “all writers first,” both directions must hold for a supported interval. Many schema registries call that **full** compatibility.

---

## How it works

### Directional compatibility (terminology)

| Term (common usage) | Meaning |
|---------------------|---------|
| **Backward-compatible** change | **New software can read old data**. Fields absent from old data receive defaults. |
| **Forward-compatible** change | **Old software can read new data**. Unknown fields are skipped or ignored. |
| **Full** compatibility | Both properties hold for a defined support window. |

Exact registry definitions vary. Project documentation should be authoritative. The engineering idea is stable: **which side advances first** constrains which changes are allowed.

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

If version 2 instead **renames** `total_cents` to `amount_cents` without a dual-field period, older readers stop seeing the amount. The old key is absent. Newer readers miss the key that older writers still send. The failure mode is often silent.

### Protocol Buffers–style evolution (field numbers)

In Protocol Buffers, field **identity on the wire** is a small integer number. It is not the human-readable name in the `.proto` file. The usual safe practices are:

- New fields receive **new numbers**. They are introduced as optional. Exact presence rules depend on language edition and toolchain.
- A field number must **never** be reused for a new meaning. Deleted numbers and names should be marked `reserved`.
- Renaming a field in the `.proto` source without changing its number is a source-level rename. The binary wire form may remain compatible. JSON mappings and human-facing APIs may not.
- Changing a field’s type in place is ordinarily a breaking change.

**Illustration — unsafe reuse:**

```text
  v1:  field 3 = total_cents (integer)
  v2:  field 3 = total (string decimal)   ← same number, new type/meaning
```

Readers compiled for v1 interpret string-shaped bytes (or a different wire type) incorrectly. Mixed fleets produce inconsistent accounts.

**Illustration — safer migration:**

```text
  v1:  field 3 = total_cents (integer)
  v2:  field 3 = total_cents (integer)   still written during migration
       field 4 = total_decimal (string)  new field
  later: stop writing field 3; reserve number 3
```

### Avro-style evolution (writer and reader schemas)

Protocol Buffers evolution is organized around **field numbers that stay on the wire forever**. Avro (and similar systems) organize evolution around **two schemas at read time**:

| Schema | Role |
|--------|------|
| **Writer schema** | Describes how the **bytes were encoded** when the record was produced (field names, types, order). |
| **Reader schema** | Describes how the **application wants to see** the record now (possibly a newer or older version of the model). |

The Avro runtime performs **schema resolution**: matching a writer’s schema to a reader’s schema by rules. It matches fields between writer and reader, primarily by **name**, with optional aliases. It applies documented rules for missing fields, extra fields, and limited type promotions.

The important beginner idea is this: **the payload need not carry field names on every record**. In the binary encoding they are implied by the writer schema. Yet the reader still needs a precise account of how the writer laid the values out. Alternatively, the reader needs a **schema id** that retrieves that account from a registry.

#### Minimal example: adding a field with a default

**Writer schema v1** (what older producers encode):

```text
  record Order {
      long   order_id;
      long   total_cents;
  }
```

**Reader schema v2** (what newer consumers expect):

```text
  record Order {
      long   order_id;
      long   total_cents;
      string currency_code = "USD";   // default when the writer did not store this field
  }
```

A record written with **v1** contains only two long values in the Avro binary layout. There are no `currency_code` bytes. A consumer using **reader schema v2** still obtains a complete logical record:

| Field | How the value is obtained |
|-------|---------------------------|
| `order_id` | Decoded from the writer’s bytes |
| `total_cents` | Decoded from the writer’s bytes |
| `currency_code` | **Not on the wire** → filled from the **default** in the reader schema (`"USD"`) |

That is **backward-compatible** evolution in the “new software reads old data” sense. The new reader understands old bytes because the new field has a default.

#### The opposite direction: new writer, old reader

**Writer schema v2** now includes `currency_code`. **Reader schema v1** does not.

| Field on the wire (v2 writer) | Old reader (v1) behaviour under resolution |
|-------------------------------|--------------------------------------------|
| `order_id`, `total_cents` | Decoded as usual |
| `currency_code` | **No matching field** in the reader schema → value is **skipped / discarded** for that application |

The old application never sees `currency_code`, but it continues to process the fields it knows. That supports **forward-compatible** change (old software reading new data) when the project’s compatibility rules allow the writer to add fields.

```text
  Writer v1 bytes  +  Reader schema v2  →  currency_code := default "USD"
  Writer v2 bytes  +  Reader schema v1  →  currency_code ignored; other fields OK
  Writer v2 bytes  +  Reader schema v2  →  currency_code read from the bytes
```

Both directions require that defaults and “ignore unknown field” behaviour are part of the **resolution rules**. Informal hope is not enough.

#### Why both schemas must be known

Suppose only the raw Avro binary for an `Order` is stored, with **no** writer schema and **no** schema id:

```text
  [ binary longs … ]     ← without a schema, field boundaries and types are ambiguous
```

A reader cannot know whether the second long is `total_cents` or something else. In practice one of the following is stored or transmitted with the data:

| Pattern | What travels with the bytes |
|---------|-----------------------------|
| **Object container file** (classic Avro files) | Writer schema (or enough metadata) in the file header; many records share it |
| **Schema registry** (common on event buses) | A small **schema id** (or fingerprint) per record or batch; the full writer schema is fetched from the registry |
| **Agreement outside the message itself** | Both sides are pinned to the same schema version by deployment process alone (fragile at scale). The schema is not carried in the payload; it lives elsewhere (for example a shared schema file). |

**Illustrative registry flow:**

```text
  Producer:  encode(record, writer_schema_v2)
             → bytes + schema_id=17
                    │
                    ▼
               schema registry:  id 17 ↔ writer_schema_v2 text
                    │
  Consumer:  fetch schema 17
             resolve(writer_schema_v2, reader_schema_v3)
             → application object
```

The consumer’s **reader schema** may be v3. Extra fields with defaults and renamed fields via aliases are examples of what v3 might add. Resolution is the step that makes “different versions” precise.

#### Rename via alias (sketch)

The writer still uses the old field name. The reader prefers a new name:

```text
  Writer schema:   long total_cents;
  Reader schema:   long amount_cents;   with alias "total_cents"
```

Resolution maps the writer’s `total_cents` bytes onto the reader’s `amount_cents` field. Without an alias or a dual-field period, a pure rename is a **break**. That is the same problem as JSON key renames.

#### Contrast with Protocol Buffers (same logical change)

| Concern | Protocol Buffers (typical) | Avro (typical) |
|---------|----------------------------|----------------|
| Field identity on the wire | **Numbers** (for example `total_cents = 3`) | **Names** in the schema; binary layout follows the writer schema |
| What the reader must know | Compiled message types / descriptors (numbers stay stable) | **Writer schema** (or id) **and** reader schema |
| New field | New number; old readers skip unknown numbers | New name plus a default for old data; old readers skip unknown names under resolution |
| Operational center of gravity | `.proto` ownership and reserved numbers | Schema registry and compatibility modes (BACKWARD / FORWARD / FULL, product-specific) |

Neither model removes the need for a **compatibility policy**. They implement that policy with different mechanisms. For analytical pipelines and lake-oriented formats, see also the [data science perspective](../101/data_science_perspective.md).

### JSON and schemaless binary formats

JSON and related “flexible” formats still need evolution discipline. The usual patterns are:

- **Additive** properties are the usual safe change. Consumers that need forward compatibility should ignore unknown keys.
- **Renames** fail silently. The old key is absent, and the new key is ignored by older clients.
- **Type changes** of an existing key are breaking. Changing a string to an object is one example.
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

- whether a missing field, an explicit null, and a numeric zero default mean different things;
- whether the value `0` is allowed to mean “unset” (usually a poor design).

Code generators and serializers differ. Tests should cover fixtures for **old payload × new reader** and **new payload × old reader**.

---

## Costs and constraints

| Axis | Consequence of weak evolution discipline | Benefit of disciplined practice |
|------|------------------------------------------|----------------------------------|
| Evolution risk | Service failures, corrupted stores, undeliverable messages | Updating services gradually so old and new versions run at the same time, without a single synchronized cutover day |
| Operability | Emergency reconstruction of schema history | Versioned schemas and clear ownership |
| Size / bandwidth | Optional fields kept forever slowly accumulate | Planned deprecation windows |
| Tooling | Informal documents that drift from reality | Registry, breaking-change checks, contract tests |
| Security / trust | Misinterpretation after silent type changes | Explicit validation of untrusted shapes |

---

## Illustrative scenario

A billing field `amount_cents` (integer) is “replaced” by `amount` (decimal string) by reusing the same JSON key or the same Protocol Buffers field number. Part of the deployment still expects integers. Part expects strings. Some components write both. Reconciliation fails for a subset of accounts.

A sound approach introduces a **new field** (or a versioned API). Dual-writes and dual-reads run during a migration window. Then the old field is retired with `reserved` markers or formal API deprecation. An in-place type substitution is not a sound approach.

---

## In this suite

Benchmark fixtures assume a **stable logical model** so that libraries remain comparable. The suite is not a schema-registry simulator. Use Serialization 201 and the perspective documents for evolutionary *judgment*. Use the **Dashboard** for encode and decode cost of a chosen codec once the contract is fixed.

When you evaluate schema-driven libraries on language overview pages, production use still requires your organization’s own compatibility process. The benchmark runner does not replace it.

---

## Common errors of practice

- Reusing Protocol Buffers field numbers or Avro names under incompatible modes.
- Deploying writers that emit a newly required field before all readers understand it.
- Renaming JSON properties without versioning or a dual-field period.
- Treating “optional in the interface description” as “optional in the product” without defaults.
- Omitting consumer tests against **reference payloads** from older versions.
- Deleting fields on the same day writers stop emitting them, with no drain interval.

---

## Key takeaways

- Evolution is a **policy together with encoding rules** when services are updated gradually (old and new versions run at the same time) and data lives for a long time.
- Decide whether older readers, older writers, or both must be supported during migration.
- Prefer additive optional fields with explicit defaults, and never repurpose identifiers.
- Flexibility of JSON does not remove the need for a compatibility strategy.
- Registry and continuous-integration enforcement scale more reliably than informal coordination alone.
- Dual-read and dual-write migration windows are preferable to simultaneous type changes.
- Test old×new and new×old payloads, not only matched-version paths.

---
