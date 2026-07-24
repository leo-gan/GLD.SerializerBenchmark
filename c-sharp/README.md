# .NET Serializer Benchmark

Extensible suite evaluating **36 .NET serializers** (speed, size, fidelity) on shared suite fixtures.

Serializer inventory: [docs/c-sharp/index.md](../docs/c-sharp/index.md).

---

## Key Features

- **36 serializers** registered in `Program.cs` (Json.NET, protobuf-net, Bond, Jil, SpanJson, Utf8Json, System.Text.Json, MemoryPack, Ceras, FlatSharp, Hyperion, SharpSerializer, and more). **Not** included: MessagePack-CSharp, Wire; Apex.Serialization (net8 crash); FluentSerializer (unsuitable for suite graphs).
- **Suite data types**: Data Model v2 type ids `message`, `document`, `telemetry`, `strings`, `event` — domain POCOs in `TestData/V2/Models.cs`.
- **Dual mode**: **string** vs **Stream**. Text codecs use real text on the string path; **binary** codecs usually use **Base64** of bytes on the string path. Stream is **native** when the library writes the stream, or **adapted** when the harness wraps the string path — see [inventory honesty](../docs/c-sharp/index.md#string-mode-vs-stream-mode).
- **CSV logs** + optional `*.errors.csv` + `*.configs.json` sidecars.
- Most codecs use domain types (or codegen forms) on the timed path. **Exceptions:** ExtendedXmlSerializer and Migrant time a **JSON envelope** only — see [envelope codecs](../docs/c-sharp/index.md#envelope-codecs-not-native-domain-wire).

---

## Test data

Domain types live under `TestData/V2/` and match `schemas/data_catalog_v2.yaml` / `benchmark_v2.proto`.

| Type id | Domain type | Shape |
| :--- | :--- | :--- |
| **message** | `Message` | Flat mixed scalars + strings |
| **document** | `Document` | Nested meta + item list |
| **telemetry** | `Telemetry` | Source, timestamp, tags, numeric series |
| **strings** | `Strings` | String list |
| **event** | `Event` | Id/type/time/producer + attribute list |

For `N>1`, payloads use batch wrappers (`BatchMessage`, …) so codecs that need a single root object stay happy.

---

## Requirements

- **.NET SDK 8.0+** (host toolchain — prepare once):
  ```bash
  ../scripts/install-host-requirements.sh csharp
  ../scripts/check-host-requirements.sh csharp
  ```
- Optional: `python3` + analysis package for `configs.json` sidecars

---

## Running the benchmarks

Modes match [`config/benchmark_config.yaml`](../config/benchmark_config.yaml). Same layout as other language benchmark runners (native host run, no Docker).

```bash
cd c-sharp
./scripts/run-benchmarks.sh smoke
```

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Smoke** | `./scripts/run-benchmarks.sh smoke` | Short run (reps from config; default filter Json.Net / message). |
| **Verify All** | `./scripts/run-benchmarks.sh all-single` | 10 reps, all serializers. |
| **Full Run** | `./scripts/run-benchmarks.sh full` | 100 reps. |
| **Research** | `./scripts/run-benchmarks.sh research` | 500 reps. |
| **Custom** | `./scripts/run-benchmarks.sh custom 50 "Json" "message"` | Custom reps / filters. |

Direct `dotnet` (same env vars the script sets):

```bash
export BENCHMARK_RUN_CONFIG=$PWD/../config/library/smoke.yaml
export BENCHMARK_SEED=42
export LOG_DIR=$PWD/../logs/csharp
dotnet build src/GLD.SerializerBenchmark.csproj -c Release
dotnet run --project src -c Release -- <repetitions> [serializerFilter] [dataFilter]
```

Logs: `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (+ `.configs.json`; `.errors.csv` only on failures). Times in **nanoseconds**.

---

## Results & Analysis

```bash
analyze-benchmarks -l csharp
```

See root README and [Benchmark architecture](../docs/analysis/architecture.md).

---

## How to Extend

### Add a serializer

1. Class under `Serializers/` implementing `ISerDeser` / `SerDeser`.
2. Register in `Program.cs`.
3. Document in `docs/c-sharp/index.md`.

### Add a fixture type

1. Add a domain model + generator branch under `TestData/V2/`.
2. Wire `RunCells` / fallback descriptions; ensure `type_id` is in the run-config catalog.
3. Register any library-specific wire conversion only if the codec cannot serialize the domain type directly.

---

## Note on performance

Libraries run in **default configurations**. Use results as a baseline; always re-test with production payloads and tuning.

---

*Authored by Leonid Ganeline*
