# .NET Serializer Benchmark

Extensible suite evaluating **37 .NET serializers** (speed, size, fidelity) on shared suite fixtures.

Serializer inventory: [docs/c-sharp/index.md](../docs/c-sharp/index.md).

---

## Key Features

- **37 serializers** registered in `Program.cs` (Json.NET, protobuf-net, Bond, Jil, SpanJson, Utf8Json, MemoryPack, Ceras, FlatSharp, Hyperion, SharpSerializer, and more). **Not** included: System.Text.Json, MessagePack-CSharp, Wire.
- **Suite fixtures**: `message`, `document`, `telemetry`, `strings`, `event` (POCO payload shapes under `TestData/`).
- **Dual mode**: string (base64 buffer) and Stream for every capable serializer.
- **CSV logs** + optional `*.errors.csv` + `*.configs.json` sidecars.
- **Supports(type_id)** skips codecs that cannot handle a fixture (no silent crash).

---

## Test data

| Type id | Purpose & payload shape |
| :--- | :--- |
| **message** / **event** | Flat mixed POCO (`SimpleObject`). |
| **document** | Nested claims document (`EDI835`). |
| **telemetry** | Numeric measurements (`TelemetryData`). |
| **strings** | String list (`StringArrayObject`). |

---

## Tech Stack

- **Framework**: .NET 8 (`net8.0`)
- **Build**: Docker / .NET SDK 8.0
- **Platforms**: Linux (Docker recommended), Windows, macOS

---

## Getting Started (Docker)

Modes match [`config/benchmark_config.yaml`](../config/benchmark_config.yaml).

```bash
./scripts/run-benchmarks.sh smoke
```

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Smoke** | `./scripts/run-benchmarks.sh smoke` | Short run (reps from config). |
| **Verify All** | `./scripts/run-benchmarks.sh all-single` | 10 reps, all serializers. |
| **Full Run** | `./scripts/run-benchmarks.sh full` | 100 reps. |
| **Research** | `./scripts/run-benchmarks.sh research` | 500 reps. |
| **Custom** | `./scripts/run-benchmarks.sh custom 50 "Json" "message"` | Custom reps / filters. |

Logs: `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (+ `.configs.json`; `.errors.csv` only on failures). Times in **nanoseconds**.

---

## Local Development (Without Docker)

```bash
dotnet build src/GLD.SerializerBenchmark.csproj -c Release
dotnet run --project src -c Release -- <repetitions> [serializerFilter] [dataFilter]
```

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

1. Description under `TestData/` (or `TestData/V2/`) implementing `ITestDataDescription`.
2. Register in `Program.cs`.
3. Add catalog / run-config cells if part of the multi-lang matrix.

---

## Note on performance

Libraries run in **default configurations**. Use results as a baseline; always re-test with production payloads and tuning.

---

*Authored by Leonid Ganeline*
