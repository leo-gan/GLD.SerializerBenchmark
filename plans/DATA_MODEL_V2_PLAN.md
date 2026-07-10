# Suite data model — implementation plan (historical)

**Status:** historical design record; the suite **only** measures the five type ids (`message`, `document`, `telemetry`, `strings`, `event`). There is no separate legacy data plane.
**Audience:** maintainers  
**Scope:** greenfield **data types / generators / catalog** + runner measurement extensions; **not** a rewrite of serializer libraries, Docker, or analysis math  
**Related:** `docs/analysis/test_data_configuration.md` / `data_model_v2.md`, `docs/theory/201/compression-is-not-a-format.md`, `config/benchmark_config.yaml`

---

## 0. Vocabulary (use these terms only)

| Term | Meaning |
|------|---------|
| **type catalog** | Definitions of `type_id`s and default `type_config` schemas (`schemas/data_catalog_v2.yaml`) |
| **run config** | One named document describing a full matrix to measure: types (W), `data_type_instance_count` list (C), compression, execution knobs |
| **config library** | Directory of **run config** files (use cases + experiments), selected by path or `id` + content hash |
| **cell** | One expanded workload: `(type_id, type_config_resolved, data_type_instance_count)` |
| **master config** | `config/benchmark_config.yaml` — languages, serializers, analysis, library root |

**Do not say “profile”** for run configs (old plan mixed “catalog profiles” with “library entries”).  
Modes like `smoke` / `full` in master config remain **execution modes** (repetition counts only), not data matrices.

CSV / config names (kept as agreed):

- YAML/JSON: `data_type_instance_count`  
- CSV column: `DataTypeInstanceCount`

---

## 1. Goal

Replace the v1 fixture set (`Person`, `Integer`, `Telemetry`, `SimpleObject`, `StringArray`, `EDI_835`, `ObjectGraph`) with a clean **data plane**:

| Concept | Meaning |
|---------|---------|
| **type_id** | Catalog family / generator selector |
| **type_config** | `**kwargs` for one **instance** shape (resolved defaults allowed) |
| **data_type_instance_count** | How many instances are inputs to **one** serialize/deserialize call (`1` = single, `N` = batch) |
| **seed** | Per-language reproducibility for generation (not a product axis) |
| **compression** | Optional **run-workflow** steps after ser / before deser (not generator kwargs) |
| **run config** | Versioned/pinned document selecting W × C (+ compression, execution) |

Historical v1 CSV logs remain valid archives but are **not comparable** to v2 Results.

---

## 2. MVP vs full vision

### 2.1 MVP (must ship for first v2 cutover)

| Item | MVP |
|------|-----|
| Types | Exactly five: `message`, `document`, `telemetry`, `strings`, `event` |
| Type catalog | Defaults + JSON-schema-ish kwargs validation |
| Run configs | Files only: e.g. `smoke.yaml`, `default.yaml` under `config/library/` (or `config/runs/`) |
| Version pin | Path + **content_sha256** in sidecar (no semver registry required yet) |
| Generators | `make_one` per type; harness builds batch |
| Single vs batch | Runner/adapters choose optimal API |
| Compression | `none` in MVP timing path; optional **size_only once per cell** (gzip/zstd sizes) |
| Cross-language | Same type_ids + type_config **schema**; **no** PRNG parity requirement |
| Languages | Pilot (Python) E2E first; others port incrementally |
| Schema codecs (Protobuf/Avro/…) | **In scope:** shared `schemas/v2/` + **codegen scripts** for all artifacts — see §3.6 |
| Analysis | Group includes `DataTypeInstanceCount` + `TypeConfigHash` when needed |
| v1 | Remove after all default paths use v2 |

### 2.2 Deferred (after MVP)

- Catalog-only types: `scalar`, `row`, `tree`, `map`, `graph`, `blob`, `custom`  
- Config library `index.yaml`, semver `id@version`, `inherits` deep-merge  
- Timed compression matrix / `TimeE2E`  
- Multi-group W×C products  
- Bit-identical multi-language generation  
- Optional extra IDL families beyond the agreed core set (if any)

---

## 3. Design summary (normative)

### 3.1 Two generator axes (data plane)

```text
W = [ { type_id, type_config | defaults }, ... ]   # what one instance is
C = [ count₁, count₂, ... ]                        # data_type_instance_count values

cells = W × C
```

Each cell:

```text
(type_id, type_config_resolved, data_type_instance_count, seed)
```

**Expansion:** list of type rows × shared `instance_counts` (cartesian).  
Parameter sweeps on instance shape = more rows in W.  
**No `inherits` in MVP** — copy a run config file to fork an experiment.

### 3.2 Generator API (simplified)

Generators produce **one instance** only. Batch packing and scalar-vs-list call shape are **harness / adapter** concerns.

```text
make_one(type_id, type_config_resolved, seed, instance_index) -> Instance

# harness:
instances = [ make_one(..., i) for i in range(data_type_instance_count) ]
if data_type_instance_count == 1 and adapter.prefers_scalar:
    payload = instances[0]
else:
    payload = instances    # sequence of length N
```

| Rule | Detail |
|------|--------|
| `type_config` | Instance shape kwargs only |
| Must **not** contain | `seed`, `data_type_instance_count`, `type_id` |
| No | `return_array_even_for_1_instance` in user config |

### 3.3 Serializer call policy

Suite rule: **call each serializer as effectively as possible**.

| Workload | Harness |
|----------|---------|
| `data_type_instance_count == 1` and adapter prefers scalar | Single-object API |
| `N > 1` or adapter requires sequence | Batch / repeated / wrapper API |

Adapters declare capability (conceptually): `prefers_scalar`, `supports_batch`. Unsupported cells → skip or `ErrorFlag` (match existing harness norms).

### 3.4 Default types (exactly five for MVP)

| type_id | Role | Dominance |
|---------|------|-----------|
| **message** | Single-level mixed primitives | No nested objects; no arrays of objects |
| **document** | Nested structure | Structure dominates |
| **telemetry** | Mostly numeric bulk | Thin tags OK |
| **strings** | Text bulk | Homogeneous strings |
| **event** | Stream envelope | id/type/ts/attrs; batch via `data_type_instance_count` |

**document vs strings:** nested structure vs flat text pile.  
Exact default field lists and default `type_config` values are frozen in Phase 0 (normative tables in `docs/analysis/test_data_configuration.md`).

Empty `type_config: {}` ⇒ catalog defaults for that `type_id`.

### 3.5 Determinism (within language only)

| Requirement | Level |
|-------------|--------|
| Same `(seed, type_id, type_config, instance_index)` → same instance **within one language** across runs | **Required** |
| Same bytes / PRNG stream across languages | **Not required** |

**Rationale:** suite compares serializers **within one language**. Cross-language absolute times are already discouraged (see theory / using-this-suite).

**Documentation (required in generator instructions / ADDING_A_LANGUAGE):**

> Generators must be deterministic across runs in the same language/runtime.  
> Cross-language payload identity is **not** guaranteed (PRNG, float formatting, map iteration, string pools differ).  
> Do not treat multi-language Results as the same physical objects.  
> Optional later: shared golden payloads for fidelity CI — not a gate for language GA.

### 3.6 Schema-driven serializers — schemas + codegen (in scope)

Codecs that need a shared IDL (Protobuf, Avro, FlatBuffers, …) require **versioned schema sources** and **generated language artifacts**. This is a planned workstream, not an afterthought.

#### Goals

1. One **canonical logical model** for the five default `type_id`s (aligned with catalog + generators).  
2. **Checked-in schema sources** under `schemas/v2/` (human-edited SoT for wire layout).  
3. **Scripts** that regenerate **all** language-specific artifacts (codegen outputs, descriptors, etc.).  
4. Harnesses consume **generated** code only (no hand-maintained duplicate message classes for schema codecs).  
5. CI can verify artifacts are **up to date** (`generate` then `git diff --exit-code` or checksum manifest).

#### Layout (illustrative)

```text
schemas/v2/
  README.md                 # how to regenerate; tool versions
  MANIFEST.yaml             # list of sources, outputs, tool pins (optional)
  protobuf/
    benchmark_v2.proto      # message, document, telemetry, strings, event
                            # + Batch_* wrappers or repeated fields for N>1
  avro/
    message.avsc
    document.avsc
    ...
  flatbuffers/              # if/when used
    benchmark_v2.fbs
  # future: thrift, bond, … as needed by registered serializers

scripts/schemas/            # or scripts/generate-schemas.sh entrypoint
  generate-all.sh           # orchestrates all generators
  generate-protobuf.sh
  generate-avro.sh
  generate-flatbuffers.sh
  check-generated.sh        # CI: regenerate dry-run / verify no drift
  tool-versions.env         # protoc, flatc, etc. pins
```

Language output paths (existing style; adjust per tree):

```text
python/generated/v2/…
go/gen/v2/…
rust/src/generated/v2/…     # or build.rs output
javascript/…/generated/v2/
c/…/generated/v2/
c-sharp/…/Generated/V2/…
```

Prefer **one entrypoint**:

```text
./scripts/schemas/generate-all.sh
# reads schemas/v2/*, writes all language artifacts
```

#### What the scripts must produce

| Family | Inputs | Outputs (all languages that use it) |
|--------|--------|-------------------------------------|
| **Protobuf** | `*.proto` | `protoc` stubs (py, go, rs via prost/tonic build, js, c nanopb/protobuf-c, csharp, …) as required by each harness |
| **Avro** | `*.avsc` | Checked-in schemas copied or codegen where the stack uses it; document “schema as data” vs codegen per language |
| **FlatBuffers / others** | IDL | `flatc` (or equivalent) outputs per language |

Also generate or document:

- **Batch / repeated** shapes for `data_type_instance_count > 1` (wrapper messages vs `repeated T` — freeze in Phase 0).  
- Optional **JSON Schema** of logical instances for validation of generators (not a wire codec).  
- **MANIFEST** or checksums of generated files for drift detection.

#### Source of truth order

```text
1. docs/analysis/test_data_configuration.md + data_catalog_v2.yaml   (logical fields, types)
2. schemas/v2/*.proto (etc.)                              (wire field numbers / layout)
3. scripts/schemas/generate-all.sh                        (artifacts)
4. language generators (make_one)                         (runtime values fitting the model)
```

When the logical model changes: update catalog/docs → update IDL → **re-run generate-all** → commit sources + generated artifacts (or generate in CI/build if a language prefers build-time codegen—document which).

#### Policy during rollout

| Stage | Expectation |
|-------|-------------|
| Phase 0–1 | Logical field tables frozen; draft `.proto` / `.avsc` for five types + batch |
| Phase 1b / early PR | `scripts/schemas/generate-all.sh` works for **at least pilot language** |
| Each language port | Wire that language’s schema codecs to **v2 generated** artifacts; drop v1 Person/EDI schemas when cut over |
| Default Results | Schema-driven serializers included **when** their artifacts exist for that language |
| Temporary gap | If a language port lands generators before protoc wiring, Overview may note “schema codecs pending generate”; track as checklist item, not permanent |

#### Tooling pins

Record in `schemas/v2/README.md` or `tool-versions.env`:

- `protoc` version  
- plugins (`protoc-gen-go`, `grpc_tools`, nanopb, …)  
- `flatc`, Avro tools as needed  

Docker-based generate (optional) keeps CI and laptops aligned—reuse language Docker images where practical.

#### Relationship to v1

- Replace `schemas/benchmark_data.proto` (Person/EDI/…) with `schemas/v2/…` after cutover.  
- Do not extend v1 protos with v2 type names; **new tree** avoids mixed field numbers.

### 3.7 Cell identity (analysis)

| CSV field | Content |
|-----------|---------|
| `TestDataName` | `type_id` |
| `DataTypeInstanceCount` | N |
| `TypeConfigHash` | Short hash of **resolved** `type_config` (always emit; stable empty-default hash for `{}`) |

Group key:

```text
(Language, SerializerName, TestDataName, TypeConfigHash, DataTypeInstanceCount, StringOrStream)
# + CompressionAlgo when timed compression is enabled (post-MVP)
```

Sidecar holds full resolved `type_config` and run config pin (path + content hash).

### 3.8 Wall-clock budget (flexible)

Target for a **default** run config on one language:

```text
soft_budget_seconds = 60 * ceil(n_serializers / 10)
```

Examples: 10 serializers → 1 min soft; 16 → 2 min soft; 19 → 2 min soft.

**Adaptation ladder** (runner or operator policy):

1. Start with configured reps (e.g. full = 100).  
2. If soft budget likely exceeded (or mid-run overrun policy triggers): **drop reps 100 → 50**.  
3. Continue to completion regardless of soft budget, but **hard stop at 10 minutes** wall time (emit partial CSV + error note / flag; do not hang CI forever).  

Tune default `type_config` bulk and default `data_type_instance_count` list so that **typical** default runs stay under soft budget at 50–100 reps without hitting the hard cap.

**Default matrix starting point** (adjust after pilot measurement):

| Knob | Initial default |
|------|-----------------|
| types | five |
| `data_type_instance_count` | `[1, 100]` (prefer over `[1, 1000]` until measured) |
| io_modes | `bytes` only in default run config until soft budget proven with stream |
| type_config bulk | modest (freeze numbers in Phase 0) |

### 3.9 Compression (measurement plane)

```text
generate → serialize → [optional compress] → [optional decompress] → deserialize
```

| Property | Decision |
|----------|----------|
| In `type_config`? | **No** |
| Serializer wrappers? | **Unchanged** — runner only |
| MVP | `none`, or **size_only once per cell** (not every timed rep) |
| Timed compress | Deferred run config (e.g. `compress.yaml`) |

| Metric | Meaning |
|--------|---------|
| `Size` | Raw serialize output |
| `SizeGzip` / `SizeZstd` | Optional; from size_only once per cell |
| `TimeSer` / `TimeDeser` | Codec only |

### 3.10 Configuration layers

```text
1. Master          config/benchmark_config.yaml
2. Type catalog    schemas/data_catalog_v2.yaml
3. Run configs     config/library/*.yaml   (config library)
```

**MVP library layout** (flat, simple):

```text
config/library/
  README.md
  smoke.yaml
  default.yaml
  # later: compress.yaml, experiments/…
```

Each run config file includes:

```yaml
id: default
description: "Publication default matrix"
data_model_version: 2

types:
  - { type_id: message, type_config: {} }
  - { type_id: document, type_config: {} }
  - { type_id: telemetry, type_config: {} }
  - { type_id: strings, type_config: {} }
  - { type_id: event, type_config: {} }

data_type_instance_count: [1, 100]    # list expands axis C

compression:
  mode: size_only    # none | size_only | timed (timed post-MVP)
  algorithms: [gzip_6, zstd_3]

execution:
  mode: full         # maps to master modes.*.repetitions unless overridden
  io_modes: [bytes]
```

**Pinning:** CLI `--config config/library/default.yaml` (or short name resolved via master).  
Sidecar stores path + `content_sha256` of file as read + fully resolved cells.

**Later (not MVP):** `id@version`, `index.yaml`, immutable semver copies, `inherits`.

### 3.11 Shared resolver (recommended)

Implement **one** resolver (Python CLI or library) used by all languages:

```text
resolve-run-config config/library/default.yaml
  → stdout JSON: { cells: [...], seed, compression, content_sha256, ... }
```

Harnesses load that JSON (or call the tool in `run-benchmarks.sh`). Avoids six YAML merge implementations.

### 3.12 Portable primitives

```text
bool, int32, int64, float64, utf8_string
# datetime: freeze one convention in Phase 0 (e.g. int64 epoch ms)
```

`primitive_types: all_available` resolves to this set.

### 3.13 Seed

From master `reproducibility.random_seed` (default 42) unless run config overrides.  
Used only by that language’s `make_one` PRNG.

---

## 4. What is kept vs replaced

| Layer | Action |
|-------|--------|
| Serializer libraries & adapters | **Keep**; extend single/batch selection |
| Timing loop, modes (`bytes`/`stream`), reps | **Keep**; budget ladder may reduce reps |
| CSV writer / analysis stats | **Keep**; new columns & group keys |
| v1 types & generators | **Replace** after cutover |
| v1 `test_data_config.json` / master type list | **Replace** |
| IDL Person/EDI (`schemas/benchmark_data.proto`, …) | **Replace** with `schemas/v2/` + generate scripts |
| Historical v1 logs | **Archive**; do not convert |

---

## 5. Run loop (conceptual)

```text
run_cfg = resolve(path)   # shared resolver → cells, hash, compression
for cell in run_cfg.cells:
  instances = [make_one(cell.type_id, cell.type_config, seed, i)
               for i in range(cell.data_type_instance_count)]
  for serializer in serializers:
    payload = pack_for_adapter(serializer, instances)
    ser_bytes = time(serialize)
    # size_only once per (cell, serializer): record SizeGzip/SizeZstd
    obj2 = time(deserialize(ser_bytes))
    fidelity(instances or payload, obj2)
```

---

## 6. CSV and analysis

| Column | v2 |
|--------|-----|
| `TestDataName` | `type_id` |
| `DataTypeInstanceCount` | N |
| `TypeConfigHash` | hash of resolved type_config |
| Timing / Size | unchanged meaning (codec) |
| Optional SizeGzip / SizeZstd | size_only |

Sidecar: `run_config` path + content hash, resolved cells, seed, `data_model_version: 2`, environment, serializers.

Results: prefer publishing runs pinned to `config/library/default.yaml` (hash noted on page).

---

## 7. CI / prepare-pr / Results (best effort)

| Stage | Policy |
|-------|--------|
| **Smoke CI** | `--config config/library/smoke.yaml`, short reps; fail on crash / fidelity, not on soft budget |
| **prepare-pr** | Run v2 default when language data plane is migrated; keep v1 only for unmigrated langs during transition |
| **Transition** | Per-language flag or detection: v2 if generators present; document dual period in prepare-pr skill/scripts |
| **Hard cap** | 10 minutes per language job; partial log + non-zero exit or explicit timeout artifact |
| **Published Results** | Only from pinned default run config hash (or explicit allowlist); experiments stay under `logs/` without overwriting main Results |
| **Baseline / regression** | New v2 baseline file; compare under same `content_sha256` of run config + same `TypeConfigHash` set |
| **Dashboard** | Ingest v2 columns; ignore or separate v1 series |

Do not require rewriting prepare-pr before Phase 3; update scripts when pilot lands, then generalize per language port.

---

## 8. Phased delivery

### Phase 0 — Spec freeze

- Approve this plan  
- Normative `docs/analysis/test_data_configuration.md`: field lists for five types, default type_config, primitives, datetime, generator determinism note (within-language only), budget ladder  
- Freeze **batch wire shape** for schema codecs (`repeated T` vs wrapper message)  
- No harness code required  

### Phase 1 — Catalog + run configs + resolver

- `schemas/data_catalog_v2.yaml`  
- `config/library/smoke.yaml`, `default.yaml`  
- Python `resolve-run-config` → cells JSON + content hash  
- Validate unknown keys / forbidden type_config keys  

### Phase 1b — Schema sources + generate scripts

- Author `schemas/v2/` IDL for five types (+ batch) for each schema family used by the suite (start with **Protobuf**; Avro/FlatBuffers as required by registered serializers)  
- Implement `scripts/schemas/generate-all.sh` (+ per-family scripts)  
- Generate artifacts for **pilot language** at minimum; extend outputs as languages port  
- `check-generated.sh` for drift  
- Document tool versions and how to regenerate  

### Phase 2 — Reference generators (pilot language)

- `make_one` for five types (logical model matches IDL field sets)  
- Determinism tests **within language** (seed stability)  
- Map `make_one` output → schema codec messages (pilot) using **generated** stubs  

### Phase 3 — Pilot harness E2E

- Runner uses resolver output  
- Single vs batch adapter selection (including schema batch wrappers)  
- CSV columns + sidecar  
- size_only once per cell (optional)  
- Measure budget ladder; tune default matrix  
- Schema-driven serializers on pilot language use **v2 generated** code  

### Phase 4 — Language ports

Order: Python → Go → Rust → JS → C → C#  
Each: generators + runner wire-up + sidecar  
Extend `generate-all.sh` (or language `build.rs` / msbuild hooks) for that language’s schema artifacts  
Point schema serializers at v2 generated code  
Instructions: determinism within language; no cross-lang PRNG requirement; “run schema generate before build”  

### Phase 5 — Analysis & docs

- Group key with `DataTypeInstanceCount` + `TypeConfigHash`  
- Results / plots / dashboard  
- Replace test_data_configuration docs; document schema regenerate workflow  
- prepare-pr + baseline v2 (include schema check in CI where cheap)  

### Phase 6 — Delete v1 data plane

- Remove Person/EDI/… models **and** v1 protos/schemas when all languages default to v2  
- Grep-clean; remove obsolete `compile_protos.sh` paths that only target v1

---

## 9. PR sequence

| PR | Scope |
|----|--------|
| PR1 | Plan + Phase 0 normative doc + catalog skeleton + default/smoke run configs |
| PR2 | Resolver CLI + validation tests |
| PR3 | `schemas/v2` sources + `scripts/schemas/generate-all.sh` + pilot-language artifacts + check-generated |
| PR4 | Generators + within-lang determinism tests (pilot); map to generated schema types |
| PR5 | Pilot runner E2E + CSV/sidecar + budget ladder + schema codecs on generated code |
| PR6 | size_only compression metrics (once per cell) |
| PR7… | Per-language ports (generators + generate-all outputs + schema wiring) |
| PR-analysis | Group key, Results, prepare-pr, baseline, CI schema drift check |
| PR-cleanup | Delete v1 fixtures and v1 schema sources |

---

## 10. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Soft budget overrun | Ladder: 100→50 reps; tune type_config / N; hard cap 10 min |
| Schema codegen drift / tool versions | `generate-all` + `check-generated` in CI; pin tools in `tool-versions.env` |
| Language missing from generate-all | Checklist item on language port PR; block “schema serializer enabled” until artifacts exist |
| Single vs batch bugs | Adapter tests N=1 and N&gt;1 |
| Cross-lang confusion | Explicit docs; no fake parity claim |
| type_config collisions in pivots | `TypeConfigHash` in group key |
| size_only too slow | Once per cell only; or mode `none` in default |
| Dual v1/v2 during port | Per-language migration; prepare-pr detection |

---

## 11. Success criteria (MVP release bar)

1. Soft budget formula honored in normal cases; hard cap 10 min enforced.  
2. Default run config uses only five types.  
3. `make_one` deterministic across runs **within each language**.  
4. `type_config` vs `data_type_instance_count` separation respected.  
5. Optimal single vs batch paths where adapters exist.  
6. Compression optional; serializers unchanged.  
7. Sidecar: resolved cells + run config path + content hash.  
8. Analysis groups: `TestDataName`, `TypeConfigHash`, `DataTypeInstanceCount`.  
9. Run configs selectable as files; experiments = new files (copy).  
10. `schemas/v2/` + `scripts/schemas/generate-all.sh` produce artifacts used by schema-driven serializers; CI can detect drift.  
11. v1 removed from default path after Phase 6.  

---

## 12. Open decisions (Phase 0 — remaining)

1. Exact default `type_config` field lists and numeric defaults for five types.  
2. Datetime representation (recommend int64 epoch ms).  
3. Default `data_type_instance_count`: confirm `[1, 100]` after first timing.  
4. Default compression: `none` vs `size_only` once per cell.  
5. Batch wire shape for schema codecs (`repeated T` vs wrapper message) — **required before Phase 1b**.  
6. Which schema families in v2 MVP beyond Protobuf (Avro, FlatBuffers, …) — driven by registered serializers.  
7. Generated code: commit to git vs build-time only (per language; document in MANIFEST).  
8. Pilot language (Python assumed).  
9. Library directory name: `config/library` vs `config/runs`.  
10. `TypeConfigHash` algorithm (e.g. sha256 of canonical JSON of resolved config, first 12 hex chars).  

---

## 13. Review decisions log

| Critique # | Decision |
|------------|----------|
| Naming `data_type_instance_count` / `DataTypeInstanceCount` | **Keep** |
| Vocabulary “profile” vs run config | **run config only**; modes = reps only |
| Generator array flag / dual return | **`make_one` + harness pack** |
| Cross-lang PRNG parity | **Not required**; within-lang determinism + docs warning |
| Schema codecs | **In scope:** `schemas/v2/` + generate-all scripts + CI drift check |
| Cell identity | `TestDataName` + **`TypeConfigHash`** + `DataTypeInstanceCount` |
| Budget | Soft: **1 min per 10 serializers**; reps 100→50; hard **&lt;10 min** |
| inherits / heavy library | **No inherits in MVP**; file + content hash |
| Catalog-only types | **Deferred** |
| size_only frequency | **Once per cell** |
| CI / prepare-pr | Best-effort policy in §7 |
| Plan structure | **MVP section + simplified phases** |

---

## 14. Document history

| Date | Note |
|------|------|
| 2026-07-09 | Initial plan from design discussion |
| 2026-07-09 | Config library § added |
| 2026-07-09 | Review: MVP slice, make_one, budget ladder, TypeConfigHash, within-lang determinism, vocabulary cleanup |
| 2026-07-09 | Schema workstream: schemas/v2 + generate-all scripts + Phase 1b (not “partial forever”) |
