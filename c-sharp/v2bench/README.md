# C# lightweight bench (System.Text.Json)

Small `net8.0` project for a quick matrix with **System.Text.Json** when the main suite build artifacts are inconvenient (e.g. root-owned `src/obj` from Docker).

The full multi-serializer suite is `c-sharp/src/` (`Program.cs`).

```bash
export BENCHMARK_RUN_CONFIG=$PWD/../../config/library/smoke.yaml
export BENCHMARK_SEED=42
export LOG_DIR=$PWD/../../logs/csharp
dotnet run -c Release -- 10
```
