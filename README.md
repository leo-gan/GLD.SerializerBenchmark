# .NET Serializer Benchmark

A highly extensible benchmarking suite designed to evaluate the performance (speed and size) of over 30 different .NET serializers across various complex data structures.

This project serves two purposes:
1. **Performance Insight**: Compare various serialization libraries to make informed architectural decisions.
2. **Implementation Guide**: Provide clean, copy-pasteable snippets for implementing these serializers in your own projects.

---

## 🚀 Key Features

- **Extensive Library Support**: Benchmarks for 30+ popular serializers (Json.NET, Protobuf-net, Jil, MessagePack, Wire, etc.).
- **Diverse Test Data**: Realistic data structures including Telemetry, EDI documents, Object Graphs, and simple POCOs.
- **Dual Mode Testing**: Every serializer is tested in both **String** and **Stream** serialization modes.
- **Detailed Reporting**: Generates raw metrics in `.csv` format for deep analysis and `.tsv` for error tracking.
- **Analysis Ready**: Includes a Jupyter Notebook (`Analysis.ipynb`) for visualizing and interpreting the results.

---

## 🛠 Tech Stack

- **Framework**: .NET 6 (Modernized from .NET Framework 4.5)
- **Language**: C#
- **Build Tools**: Docker / .NET SDK 6.0
- **Platforms**: Linux (Docker recommended), Windows, macOS

---

## 🚀 Getting Started (Docker)

The recommended way to run the benchmarks is using Docker. This ensures a consistent environment and provides tiered execution modes.

### 1. Build and Verify
Run the master script to build the image and perform a core verification (smoke test):
```bash
./run-benchmarks.sh smoke
```

### 2. Available Execution Modes
Choose a mode based on your needs:

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Smoke** | `./run-benchmarks.sh smoke` | 1 repetition of `BinarySerializer` on `Person`. Use this to verify installation. |
| **Verify All** | `./run-benchmarks.sh all-single` | 1 repetition of **all** serializers on all data. Checks for compatibility issues. |
| **Full Run** | `./run-benchmarks.sh full` | 100 repetitions of all serializers. **Warning**: This can take a long time. |
| **Custom** | `./run-benchmarks.sh custom 50 "Json" "Person"` | Custom repetitions and name filtering (e.g., only Json serializers on Person). |

### 3. Monitoring Progress
You can see real-time progress by following the container logs in another terminal:
```bash
docker logs -f $(docker ps -lq)
```

### 4. Results
Benchmark logs are saved to the `logs/` directory:
- `SerializerBenchmark_Log.csv`: Performance metrics.
- `SerializerBenchmark_Errors.tsv`: Tracking any failures.

---

## 🛠 Local Development (Without Docker)

Ensure you have [.NET SDK 6.0](https://dotnet.microsoft.com/download) installed.

1. **Build**:
   ```bash
   dotnet build GLD.SerializerBenchmark/GLD.SerializerBenchmark.csproj -c Release
   ```
2. **Execute**:
   ```bash
   dotnet run --project GLD.SerializerBenchmark -c Release -- <repetitions> [serializerFilter] [dataFilter]
   ```

---

## 📊 Results & Analysis

The benchmark outputs two main files:
- `SerializerBenchmark_Log.csv`: Raw timing (ticks) and size (bytes) for each run.
- `SerializerBenchmark_Errors.tsv`: Detailed error reports for serializers that failed specific test cases.

For a deeper dive into the results, open `GLD.SerializerBenchmark/Analysis.ipynb` using Jupyter or the VS Code Interactive window.

---

## 🧩 How to Extend

### Add a New Serializer
1. Create a new class in the `Serializers/` directory.
2. Implement the `ISerDeser` interface:
   ```csharp
   public interface ISerDeser {
       string Name { get; }
       void Initialize(Type primaryType, List<Type> secondaryTypes);
       string Serialize(object obj);
       object Deserialize(string serialized);
       void Serialize(object obj, Stream stream);
       object Deserialize(Stream stream);
   }
   ```
3. Register your new class in `Program.cs` in the `serializers` list.

### Add New Test Data
1. Create a new class implementing `ITestDataDescription` in `TestData/`.
2. Define the schema and generation logic for your data.
3. Register the description in `Program.cs`.

---

## ⚠️ Important Note on Performance
Performance measurements can vary significantly based on your specific implementation and hardware. These benchmarks use libraries in their **simplest, default configurations**. Many libraries offer performance tuning (caching, specific serialization options) that could yield better results.

Use these results as a baseline, but always test with your own production data.

---

*Authored by Leonid Ganeline*
