# Test data

This page describes the **sample data** every language benchmark runner serializes: logical shapes, configuration knobs, run matrices, and generator rules.

Think of it as the **shared homework assignment**. Each language implements the same types so comparisons stay fair.

| Resource | Path |
|----------|------|
| Type catalog | [`schemas/data_catalog_v2.yaml`](../../schemas/data_catalog_v2.yaml) |
| Run configs | [`config/library/`](../../config/library/) |
| Wire schemas | [`schemas/v2/`](../../schemas/v2/) |
| Default matrix | [`config/library/default.yaml`](../../config/library/default.yaml) |
| Smoke matrix | [`config/library/smoke.yaml`](../../config/library/smoke.yaml) |

**Type ids:** `message` · `document` · `telemetry` · `strings` · `event`

How times are cleaned and summarized is separate: [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Learning goals

By the end of this page you should be able to:

1. Define **data type**, **run config**, **cell**, and **make_one** in one sentence each.
2. Sketch the five default data types and what each stresses.
3. Explain batching (`data_type_instance_count`) without confusing it with “how many repetitions.”

---

## Vocabulary

This suite uses a few fixed words. Prefer these over informal synonyms such as “fixture.”

| Term | Meaning | Examples |
|------|---------|----------|
| **data type** (also **type id**) | Which *kind* of sample object we serialize | `message`, `document`, `telemetry`, `strings`, `event` |
| **type config** | Size and shape knobs for **one** instance of that type | `field_count: 8`, `points: 32` |
| **instance** | One concrete object of a data type | one `message` record |
| **batch size** (`data_type_instance_count`) | How many instances go into **one** serialize/deserialize call | `1` or `100` |
| **cell** | One measured combination: data type + type config + batch size | `message` with N=100 |
| **type catalog** | File of type ids and default type configs | `schemas/data_catalog_v2.yaml` |
| **run config** | Which cells to measure in a run | `config/library/default.yaml` |
| **make_one** | Generator that builds a **single** instance | language-specific |

**CSV names (for readers of raw logs):**

| CSV column | Everyday name |
|------------|---------------|
| `TestDataName` | data type id |
| `DataTypeInstanceCount` | batch size `N` |
| `TypeConfigHash` | short hash of the resolved type config |

> **Note:** Older docs and some benchmark-runner code still say *fixture*. That almost always means **data type** (or one generated instance of it), not a separate concept.

Batch cells may appear on the Dashboard as **Data type · N instances** (for example Message · 100 instances), from `type_id` and `data_type_instance_count`.

---

## Two axes (shape × batch size)

```text
W = [ { type_id, type_config }, ... ]     # which shapes
C = [ n1, n2, ... ]                       # how many instances per call
cells = W × C                             # cartesian product
```

| Axis | Owns |
|------|------|
| `type_id` + `type_config` | Shape of **one** instance |
| `data_type_instance_count` | How many instances in **one** serialize/deserialize call (`1` = single object, `N` = batch) |
| `seed` | Within-language deterministic generation (master `reproducibility.random_seed`) |
| compression | Runner post-steps on encoded bytes (**not** part of `type_config`) |

**Do not put these keys inside `type_config`:**  
`seed`, `type_id`, `data_type_instance_count`, `instance_count`, `batch_size`, `n`, `return_array_even_for_1_instance`.

---

## Generator contract

```text
make_one(type_id, type_config_resolved, seed, instance_index) -> Instance
```

Benchmark runner pattern:

```text
instances = [make_one(..., i) for i in range(N)]
payload = instances[0] if N == 1 and adapter prefers a scalar else instances
```

### Determinism

- **Required:** same `(seed, type_id, type_config, instance_index)` → same instance **within one language** across runs.
- **Not required:** identical payloads or identical random streams **across** languages.
- Within-language comparisons are the suite default; cross-language absolute times are orientation only.

---

## The five default types

### message

A flat record of mixed primitives. **No** nested objects; **no** arrays of objects. Good baseline for “simple struct” cost.

| Field (logical) | Type | Notes |
|-----------------|------|--------|
| Keys `f0`…`f{field_count-1}` | cycled from `primitive_types` | Deterministic key names |
| Values | bool / int32 / int64 / float64 / utf8_string | From the resolved primitive set |

Default `type_config`: `field_count: 8`, `primitive_types: all_available`, `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`.

### document

A nested structure (id, status, meta map, list of line items). Scale is controlled by `children`, `fields_per_child`, and `max_depth`.

```text
Document {
  id: utf8_string
  status: int32
  meta: { region: string, version: int32 }
  items: [ { sku: string, qty: int32, price_minor: int64 }, ... ]  // length = children
}
```

Default: `children: 8`, `fields_per_child: 3`, `max_depth: 2`.

### telemetry

Mostly numeric sensor-style data.

```text
Telemetry {
  source: utf8_string
  ts: int64          // epoch milliseconds
  tags: [string, ...]  // length = tag_count
  values: [float64 or int64, ...]  // length = points
}
```

Default: `points: 32`, `number_type: float64`, `tag_count: 2`.

### strings

Text bulk only—useful for string encoding cost.

```text
Strings {
  items: [utf8_string, ...]  // length = count
}
```

Default: `count: 32`, `string_len: {min:3,max:16}`, `duplication: 0.1`.

### event

A stream-style envelope (one event instance; batch via `data_type_instance_count`).

```text
Event {
  event_id: utf8_string
  event_type: utf8_string
  occurred_at: int64     // epoch milliseconds
  producer: utf8_string
  attrs: map or list of {key, value} string pairs  // length = attr_count
}
```

Default: `attr_count: 4`, `include_payload_bytes: 0`.

---

## Primitives

Portable set (`all_available`):

```text
bool, int32, int64, float64, utf8_string
```

**Datetime:** logical model uses `int64` epoch milliseconds UTC (not ISO strings). Schema IDLs must use the same convention.

---

## Batch wire shape (schema codecs)

When `data_type_instance_count = N > 1` (and adapters need a sequence type):

```text
Batch_<Type> {
  repeated <Type> items = 1;   // length == N
}
```

Example: `Batch_message { repeated Message items = 1; }`.

Prefer this wrapper over a package-level stream of top-level `repeated` messages, so **one encode call** maps to **one** message. For `N = 1`, adapters may use a bare `Message` (optimal single path) or a batch of length one.

---

## Run configs

| File | Matrix |
|------|--------|
| [`config/library/smoke.yaml`](../../config/library/smoke.yaml) | `message`, `telemetry` × `[1]` |
| [`config/library/default.yaml`](../../config/library/default.yaml) | five types × `[1, 100]` |

Resolve a config to see the expanded cell list:

```bash
./scripts/resolve_run_config.py config/library/default.yaml --pretty
./scripts/resolve_run_config.py config/library/smoke.yaml --seed 42
```

---

## Compression

Compression is a **runner** concern, not part of `type_config`.

Modes: `none` | `size_only` | `timed` (timed path is post-MVP).

**size_only:** compute gzip/zstd sizes **once per cell** (not every timed repetition).

---

## Wall-clock budget

```text
soft_budget_seconds = 60 * ceil(n_serializers / 10)
```

If a run overruns, reduce repetitions from 100 to 50. Hard cap: **600 seconds** per language run.

---

## Schema sources

IDL and code generation: `schemas/v2/` and `scripts/schemas/generate-all.sh`.

Logical fields on this page must stay aligned with `.proto` / `.avsc` field sets.

---

## TypeConfigHash

SHA-256 of the canonical JSON (sorted keys, no whitespace variance) of the **resolved** `type_config`, then the first **12** hex characters, lowercase. This lets analysis detect when two runs used different knobs even if the type id is the same.
