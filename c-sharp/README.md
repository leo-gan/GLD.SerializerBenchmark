# .NET Serializer Benchmark

A highly extensible benchmarking suite designed to evaluate the performance (speed and size) of **38 different .NET serializers** across various complex data structures.

This project serves two purposes:
1. **Performance Insight**: Compare various serialization libraries to make informed architectural decisions.
2. **Implementation Guide**: Provide clean, copy-pasteable snippets for implementing these serializers in your own projects.

Serializer inventory: [docs/c-sharp/index.md](../docs/c-sharp/index.md).

---

## Key Features

- **Extensive Library Support**: Benchmarks for **37 serializers** registered in `Program.cs` (Json.NET, protobuf-net, Bond, Jil, SpanJson, Utf8Json, MemoryPack, Ceras, FlatSharp, Hyperion, and more). **Not** included: System.Text.Json, MessagePack-CSharp, Wire.
- **Diverse Test Data**: Data Model v2 type_ids (`message`, `document`, `telemetry`, `strings`, `event`) with POCO payload proxies.
- **Dual Mode Testing**: Every serializer is tested in both **String** and **Stream** serialization modes.
- **Detailed Reporting**: Generates raw metrics and error tracking in `.csv` format for deep analysis.
- **Fail-Fast Visibility**: Explicitly reports failures for serializers that cannot handle a given type (see `Supports` and `*.errors.csv`).

---

## Test Data Scenarios

| V2 type_id | Purpose & payload proxy |
| :--- | :--- |
| **message** / **event** | Flat mixed POCO (`SimpleObject` proxy). |
| **document** | Nested claims document (`EDI835` proxy). |
| **telemetry** | Numeric arrays (`TelemetryData` proxy). |
| **strings** | Bulk string list (`StringArrayObject` proxy). |

---

## Tech Stack

- **Framework**: .NET 8 (`net8.0`)
- **Language**: C#
- **Build Tools**: Docker / .NET SDK 8.0
- **Platforms**: Linux (Docker recommended), Windows, macOS

---

## Getting Started (Docker)

Modes match [`config/benchmark_config.yaml`](../config/benchmark_config.yaml).

### 1. Build and Verify
```bash
./scripts/run-benchmarks.sh smoke
```

### 2. Available Execution Modes

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Smoke** | `./scripts/run-benchmarks.sh smoke` | Short run (reps from config) on Data Model v2. |
| **Verify All** | `./scripts/run-benchmarks.sh all-single` | 10 repetitions of all serializers on all data. |
| **Full Run** | `./scripts/run-benchmarks.sh full` | 100 repetitions of all serializers. |
| **Research** | `./scripts/run-benchmarks.sh research` | 500 repetitions of all serializers. |
| **Custom** | `./scripts/run-benchmarks.sh custom 50 "Json" "message"` | Custom reps and name filters (v2 type_ids). |

### 3. Monitoring Progress
```bash
docker logs -f $(docker ps -lq)
```

### 4. Results
Benchmark logs are saved to the `logs/csharp/` directory:
- `2026-06-12-123415.csv` (timestamped): Performance metrics (times in **nanoseconds**). Each run creates a new file — results are never overwritten.
- `*.configs.json`: Run config / environment sidecar for that run.

---

## Local Development (Without Docker)

Ensure you have [.NET SDK 8.0](https://dotnet.microsoft.com/download) installed.

1. **Build**:
   ```bash
   dotnet build src/GLD.SerializerBenchmark.csproj -c Release
   ```
2. **Execute**:
   ```bash
   dotnet run --project src -c Release -- <repetitions> [serializerFilter] [dataFilter]
   ```

---

## Results & Analysis

- `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (timestamped): Raw timing (nanoseconds) and size (bytes) for each run.
- `logs/csharp/YYYY-MM-DD-HHMMSS.errors.csv`: Per-run failure details (same stem as the result CSV / `.environment.json`).

Analysis and docs snapshots: install `analysis/`, then `analyze-benchmarks` (all languages) or `analyze-benchmarks -l csharp` (see root README and [Benchmark architecture — Goals](../docs/analysis/architecture.md)). Optional log path: `--logs LANG=PATH`. Write published tables/plots into `docs/analysis/` and `docs/<lang>/results.md` locally and commit; CI does not regenerate them.

---

## How to Extend

### Add a New Serializer
1. Create a new class in the `Serializers/` directory.
2. Implement the `ISerDeser` interface.
3. Register your new class in `Program.cs` in the `serializers` list.
4. Document it in `docs/c-sharp/index.md` (serializer inventory table).

### Add New Test Data
1. Create a new class implementing `ITestDataDescription` in `TestData/`.
2. Define the schema and generation logic for your data.
3. Register the description in `Program.cs`.

---

## Important Note on Performance

Performance measurements can vary significantly based on implementation and hardware. These benchmarks use libraries in their **simplest, default configurations**. Many libraries offer performance tuning that could yield better results.

Use these results as a baseline, but always test with your own production data.

---

*Authored by Leonid Ganeline*
