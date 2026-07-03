# Test data types

**Job of this page:** shared conceptual fixtures (`TestDataName` values), why each exists, and where size/seed knobs live. Not serializer categories ([Serialization categories](serialization_categories.md)) and not harness timing ([architecture](architecture.md)).

Conceptual fixtures every language harness implements as language-native models. Definitions are the suite SoT in [`config/benchmark_config.yaml`](../../config/benchmark_config.yaml) under `test_data.types`. Shape/size knobs and seed live in [`schemas/test_data_config.json`](../../schemas/test_data_config.json) (`test_data.config_file`).

Compare serializers on the **same** `TestDataName` values in CSV logs and on language **Results** pages.

## Types (`test_data.types`)

| Name | Category | Circular? | Description |
|------|----------|-----------|-------------|
| **Person** | `nested_object` | No | Nested POCO with enums, strings, and arrays |
| **Integer** | `primitive` | No | Primitive throughput baseline |
| **Telemetry** | `numeric_arrays` | No | Numeric arrays testing binary efficiency |
| **SimpleObject** | `minimal` | No | Minimal object overhead |
| **StringArray** | `memory_pressure` | No | GC/memory pressure via large string arrays |
| **EDI_835** | `real_world` | No | Deeply nested healthcare remittance document |
| **ObjectGraph** | `circular` | **Yes** | Circular references (only graph-capable serializers pass) |

### Person (`nested_object`)

Nested object graph with mixed scalars, enums, strings, and small collections (e.g. police-style records). Exercises general-purpose object mapping, field names in text formats, and moderate nesting—not pure array throughput.

Collection sizing (e.g. police-record count) comes from `CollectionOptions` in `test_data_config.json`.

### Integer (`primitive`)

Smallest practical payload: a primitive (or trivial wrapper) used as a **throughput baseline**. Isolates fixed per-call overhead from large-structure costs.

### Telemetry (`numeric_arrays`)

Payload dominated by **numeric arrays** (e.g. many floating-point measurements). Stresses dense binary packing vs text number formatting and allocation of large homogeneous collections.

Default measurement count: `TelemetryMeasurementsCount` in `test_data_config.json`.

### SimpleObject (`minimal`)

A **minimal object** (few fields) to expose fixed serializer overhead with little payload work—useful contrast to Person / EDI_835.

### StringArray (`memory_pressure`)

Large **string arrays** to pressure GC/allocator and text codecs (escaping, interning, buffer growth). Complements Telemetry’s numeric focus.

Default length: `StringArrayCount` in `test_data_config.json`.

### EDI_835 (`real_world`)

**Deeply nested** document shaped after healthcare remittance (EDI 835–style claims/lines). Exercises real-world nesting depth and many small related records—not a synthetic micro-benchmark.

Default complexity: `EdiClaimsCount` / `EdiLinesPerClaimCount` in `test_data_config.json`.

### ObjectGraph (`circular`)

Object graph with **circular references**. Only serializers that support cycles (or explicit graph modes) should succeed; others skip or fail fidelity and are omitted or marked failed in harness logs. Use this fixture when evaluating graph-capable / language-native codecs—not when comparing pure tree formats.

## Generation parameters (`schemas/test_data_config.json`)

Shared across languages so conceptual sizes stay aligned (PRNG compatibility still matters for bit-identical payloads).

| Area | Role |
|------|------|
| **StringOptions** | Word/phrase/ID length ranges; `DuplicationFactor` (0–1) chance to reuse a prior string (dedup / sharing behavior) |
| **CollectionOptions** | Counts for Person records, Telemetry measurements, StringArray length, EDI claims/lines |
| **RandomSeed** | Fixed seed (also `reproducibility.random_seed` in master config, default **42**) for reproducible generation |

## Design intent

- **Same conceptual fixtures** in every harness so `TestDataName` rows are comparable within a language and readable across languages.
- **Categories** (`primitive`, `minimal`, `nested_object`, …) document *why* each type exists—not a second taxonomy of serializers ([Serialization Categories](serialization_categories.md)).
- **ObjectGraph** is optional capacity: graph-incapable libraries are not “slower,” they are out of scope for that fixture.
- Tunables stay in JSON so runners do not hardcode diverging sizes.

When changing types or descriptions, update `test_data.types` in `config/benchmark_config.yaml` and keep this page in sync.
