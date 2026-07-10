# Test data

Normative description of suite **fixtures**, logical shapes, config axes, and generator conventions for all language harnesses.

| Resource | Path |
|----------|------|
| Type catalog | [`schemas/data_catalog_v2.yaml`](../../schemas/data_catalog_v2.yaml) |
| Run configs | [`config/library/`](../../config/library/) |
| Wire schemas | [`schemas/v2/`](../../schemas/v2/) |
| Default matrix | [`config/library/default.yaml`](../../config/library/default.yaml) |
| Smoke matrix | [`config/library/smoke.yaml`](../../config/library/smoke.yaml) |

**Type ids:** `message` · `document` · `telemetry` · `strings` · `event`

This page does **not** replace language Results methodology ([ANALYSIS_METHODOLOGY](ANALYSIS_METHODOLOGY.md)).

---

## Vocabulary

| Term | Meaning |
|------|---------|
| **type catalog** | `type_id` definitions + default `type_config` |
| **run config** | One matrix: types (W) × `data_type_instance_count` (C) + compression/execution |
| **cell** | `(type_id, type_config_resolved, data_type_instance_count)` |
| **make_one** | Generator that builds a **single** instance |

CSV: `TestDataName` = `type_id`, `DataTypeInstanceCount` = N, `TypeConfigHash` = hash of resolved `type_config`.  
Batch cells may appear on Results as `type@n=<N>` (e.g. `message@n=100`).

---

## Axes

```text
W = [ { type_id, type_config }, ... ]
C = [ n1, n2, ... ]   # data_type_instance_count
cells = W × C
```

| Axis | Owns |
|------|------|
| `type_id` + `type_config` | Shape of **one** instance |
| `data_type_instance_count` | How many instances in **one** ser/deser call (`1` = single, `N` = batch) |
| `seed` | Within-language deterministic generation (master `reproducibility.random_seed`) |
| compression | Runner post-steps on encoded bytes (not `type_config`) |

**Forbidden in `type_config`:** `seed`, `type_id`, `data_type_instance_count`, `instance_count`, `batch_size`, `n`, `return_array_even_for_1_instance`.

---

## Generator contract

```text
make_one(type_id, type_config_resolved, seed, instance_index) -> Instance
```

Harness:

```text
instances = [make_one(..., i) for i in range(N)]
payload = instances[0] if N == 1 and adapter.prefers_scalar else instances
```

### Determinism

- **Required:** same `(seed, type_id, type_config, instance_index)` → same instance **within one language** across runs.
- **Not required:** identical payloads or PRNG streams across languages.
- Within-language comparisons are the suite default; cross-language absolute times are orientation only.

---

## Default types (five)

### message

Single-level mixed primitives. **No** nested objects; **no** arrays of objects.

| Field (logical) | Type | Notes |
|-----------------|------|--------|
| Keys `f0`…`f{field_count-1}` | cycled from `primitive_types` | Deterministic key names |
| Values | bool / int32 / int64 / float64 / utf8_string | From resolved primitive set |

Default `type_config`: `field_count: 8`, `primitive_types: all_available`, `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`.

### document

Nested structure. Scale of nest controlled by `children`, `fields_per_child`, `max_depth`.

```text
Document {
  id: utf8_string
  status: int32
  meta: { region: string, version: int32 }
  items: [ { sku: string, qty: int32, price_minor: int64 }, ... ]  // len = children
}
```

Default: `children: 8`, `fields_per_child: 3`, `max_depth: 2`.

### telemetry

Mostly numeric.

```text
Telemetry {
  source: utf8_string
  ts: int64          // epoch ms
  tags: [string, ...]  // len = tag_count
  values: [float64 or int64, ...]  // len = points
}
```

Default: `points: 32`, `number_type: float64`, `tag_count: 2`.

### strings

Text bulk only.

```text
Strings {
  items: [utf8_string, ...]  // len = count
}
```

Default: `count: 32`, `string_len: {min:3,max:16}`, `duplication: 0.1`.

### event

Stream envelope (one event instance; batch via `data_type_instance_count`).

```text
Event {
  event_id: utf8_string
  event_type: utf8_string
  occurred_at: int64     // epoch ms
  producer: utf8_string
  attrs: map or list of {key, value} string pairs  // len = attr_count
}
```

Default: `attr_count: 4`, `include_payload_bytes: 0`.

---

## Primitives

Portable set (`all_available`):

```text
bool, int32, int64, float64, utf8_string
```

**Datetime:** `int64` epoch milliseconds UTC (not ISO strings on the logical model).  
Schema IDLs must use the same convention.

---

## Batch wire shape (schema codecs)

For `data_type_instance_count = N > 1` (and adapters that need a sequence type):

```text
Batch_<Type> {
  repeated <Type> items = 1;   // length == N
}
```

Example: `Batch_message { repeated Message items = 1; }`.  
Prefer this over top-level `repeated` only in a package-level stream, so one encode call maps to one message.

For `N = 1`, adapters may use bare `Message` (optimal single path) or `Batch` with one element.

---

## Run configs

| File | Matrix |
|------|--------|
| [`config/library/smoke.yaml`](../../config/library/smoke.yaml) | message, telemetry × `[1]` |
| [`config/library/default.yaml`](../../config/library/default.yaml) | five types × `[1, 100]` |

Resolve:

```bash
./scripts/resolve_run_config.py config/library/default.yaml --pretty
./scripts/resolve_run_config.py config/library/smoke.yaml --seed 42
```

---

## Compression

Runner-only. Modes: `none` | `size_only` | `timed` (timed post-MVP).  
**size_only:** compute gzip/zstd sizes **once per cell** (not every timed rep).  
Do not put compression in `type_config`.

---

## Wall-clock budget

```text
soft_budget_seconds = 60 * ceil(n_serializers / 10)
```

If needed: reduce reps 100 → 50. Hard cap: **600 seconds** per language run.

---

## Schema sources

IDL and codegen: `schemas/v2/` + `scripts/schemas/generate-all.sh`.  
Logical fields on this page must stay aligned with `.proto` / `.avsc` field sets.

---

## TypeConfigHash

SHA-256 of canonical JSON (sorted keys, no whitespace variance) of **resolved** `type_config`, first **12** hex characters, lowercase.
