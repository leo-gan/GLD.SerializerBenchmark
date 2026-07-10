# C# Data Model v2 bench (standalone)

The main `GLD.SerializerBenchmark` project may have root-owned `src/obj` from Docker builds.
This small `net8.0` project runs the v2 matrix with **System.Text.Json**.

```bash
export BENCHMARK_RUN_CONFIG=$PWD/../../config/library/smoke.yaml
export BENCHMARK_SEED=42
export LOG_DIR=$PWD/../../logs/c-sharp-v2
dotnet run -c Release -- 10
```

Full-matrix C# serializers still live under `src/` for `BENCHMARK_DATA_MODEL=v1`.
