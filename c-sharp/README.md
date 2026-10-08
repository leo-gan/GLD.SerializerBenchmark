# .NET Serializer Benchmark

Extensible suite evaluating **50 .NET serializers** (speed, size, fidelity) on shared suite fixtures.

Serializer inventory: [docs/c-sharp/index.md](../docs/c-sharp/index.md).

---

## Key Features

- **50 serializers** registered in `Program.cs` (was 47, plus `arrow-ipc`, `parquet`, `parquet-uncompressed`). Also Json.NET, protobuf-net, LightProto, Bond, SpanJson, Utf8Json, System.Text.Json, MemoryPack, MessagePack-CSharp, Amazon.IonDotnet, Nerdbank.MessagePack, ShapeShift, Ceras, FlatSharp, Apache.Avro, Hyperion, SharpSerializer, and more. **Not** included: Wire; Jil (incompatible with .NET 10); Apex.Serialization (net8 crash); FluentSerializer (unsuitable for suite graphs); **sbe** (no NuGet `Org.SbeTool.Sbe.Dll` on the 1.40.2 line); ORC; ParquetSharp.
- **Suite data types**: Data Model v2 type ids `message`, `document`, `telemetry`, `strings`, `event`, plus columnar `table`, `table_project`, `nested_table`, `signal` — domain POCOs in `TestData/V2/Models.cs`. The new Arrow/Parquet rows support only those four ids. Older rows still default `Supports` to true, so a columnar config must pass a comma-separated exact-name allow-list.
- **Dual mode**: **string** vs **Stream**. Text codecs use real text on the string path; **binary** codecs usually use **Base64** of bytes on the string path. Stream is **native** when the library writes the stream, or **adapted** when the benchmark runner wraps the string path — see [inventory honesty](../docs/c-sharp/index.md#string-mode-vs-stream-mode).
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
| **table** / **table_project** | `TableRow` | 16 doubles, 4 longs, two strings. `table_project` deserialize returns `FFloat0` only (length N) |
| **nested_table** | `NestedRow` | Id, status, meta, child items |
| **signal** | `Signal` | Scalars, symbol, venue, legs (`leg_pad` is 0) |

For `N>1`, payloads use batch wrappers (`BatchMessage`, `BatchTable`, `BatchNestedRow`, `BatchSignal`, …) so codecs that need a single root object stay happy.

### Columnar rows

`arrow-ipc` is Apache.Arrow **23.0.0** (net8.0 asset, consumed from `net10.0`; no net10-specific lib). `parquet` and `parquet-uncompressed` are Parquet.Net **6.1.0** (explicit `net10.0`). `parquet` uses the library default, Snappy. `parquet-uncompressed` sets `CompressionMethod.None`.

The timed call is the **string** path: Base64 of the IPC stream or Parquet bytes. There is no compliance decoder. The stream path is adapted (the same buffer written to the harness `Stream`), not a native streaming writer. Arrow and Parquet project `FFloat0` inside `table_project` deserialize. System.Text.Json, Google.Protobuf, FlatSharp, and Apache.Avro full-decode, then slice that column.

**sbe** was not registered. sbe-tool 1.40.2 accepts `schemas/v2/sbe/signal.xml`, but no NuGet package provides `Org.SbeTool.Sbe.Dll` at 1.40.2. NuGet `sbe-tool` 1.23.1.1 is an older `SBE.dll` (`net45` / `netstandard2.0`). The generated namespace would also collide with Google.Protobuf's `Benchmark.V2`.

A filter with **no comma** is a case-insensitive substring. A **comma-separated** filter is case-insensitive exact names. `json` matches many JSON libraries; `json,` matches none. `protobuf,` matches only `ProtoBuf`.

Columnar smoke (does not replace the default smoke path):

```bash
cd c-sharp
BENCHMARK_RUN_CONFIG=../config/library/columnar-smoke.yaml \
  ./scripts/run-benchmarks.sh custom 2 \
  "arrow-ipc,parquet,parquet-uncompressed,System.Text.Json,Google.Protobuf,FlatSharp,Apache.Avro"
```

`./scripts/run-benchmarks.sh smoke` still uses `config/library/smoke.yaml` (message + telemetry) and the Json.Net / message filter. In-process checks: `dotnet run --project src -c Release -- selfcheck`.

---

## Requirements

- **.NET SDK 10.0+** (host toolchain — prepare once). The project targets **net10.0** because the ShapeShift packages require it. This also satisfies LightProto’s source generator requirement (Roslyn 4.14+).
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

Full suite checklist (all languages, PR expectations, honesty rules):
**[Adding a serializer](../docs/analysis/ADDING_A_SERIALIZER.md)**.

C# short path:

1. PackageReference in `src/GLD.SerializerBenchmark.csproj`.
2. Class under `src/Serializers/` implementing `ISerDeser` / `SerDeser` (`Name` is the CSV `SerializerName`).
3. Register in `src/Program.cs`.
4. Map `Name` → NuGet assembly simple name in `src/SerializerVersionRegistry.cs` (fills CSV `SerializerVersion`).
5. Domain attributes / maps only if the library needs them (`TestData/V2/Models.cs`, `Maps/`, `Contracts/`).
6. Document in `docs/c-sharp/index.md`; bump serializer counts (this README, root README, `config/benchmark_config.yaml` comment).
7. Smoke, then full + analyze:

```bash
./scripts/run-benchmarks.sh custom 5 YourName message
cd ..
./scripts/run-all-benchmarks.sh --mode full --lang csharp --analyze
python3 dashboard/scripts/sync-data.py
```

Review and commit `dashboard/public/data/csharp_latest.json.gz` with the PR when publishing refreshed C# dashboard results. Do not normally commit the timestamped raw files under `logs/`.

If the library uses a **source generator**, ensure the host **.NET SDK** is new enough for that generator (see Requirements above). CI must install the same SDK.

### Add a fixture type

1. Add a domain model + generator branch under `TestData/V2/`.
2. Wire `RunCells` / fallback descriptions; ensure `type_id` is in the run-config catalog.
3. Register any library-specific wire conversion only if the codec cannot serialize the domain type directly.

---

## Note on performance

Libraries run in **default configurations**. Use results as a baseline; always re-test with production payloads and tuning.

---

*Authored by Leonid Ganeline*
