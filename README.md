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

- **Framework**: .NET Framework 4.5
- **Language**: C#
- **Build Tools**: MSBuild / Visual Studio / Mono

---

## 📋 Supported Serializers

| Category | Serializers |
| :--- | :--- |
| **JSON** | Json.NET, Jil, FastJson, ServiceStack.Json, NetJSON, Nfx.Json, JavaScriptSerializer, etc. |
| **Binary** | Protobuf-net, MessagePack, Wire, Bond, FsPickler, SharpSerializer, SalarBois, etc. |
| **Standard** | XMLSerializer, DataContractSerializer, BinaryFormatter. |
| **Experimental** | Avro, MessageShark, etc. |

---

## 🚀 Getting Started

### Windows
1. Open `GLD.SerializerBenchmark.sln` in Visual Studio.
2. Restore NuGet packages (Automatic upon build).
3. Build the solution in **Release** mode.
4. Run the resulting executable from the command line:

```powershell
.\GLD.SerializerBenchmark.exe 100
```
*(Where `100` is the number of repetitions per test case)*

### Linux / macOS (using Mono)
Ensure you have [Mono](https://www.mono-project.com/download/stable/) and NuGet CLI installed.

1. **Restore Packages**:
   ```bash
   nuget restore GLD.SerializerBenchmark.sln
   ```
2. **Build**:
   ```bash
   msbuild /p:Configuration=Release GLD.SerializerBenchmark.sln
   ```
3. **Execute**:
   ```bash
   mono GLD.SerializerBenchmark/bin/Release/GLD.SerializerBenchmark.exe 100
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
