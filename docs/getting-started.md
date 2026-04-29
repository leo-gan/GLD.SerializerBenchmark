# Getting Started

Run the benchmarks locally or explore the pre-built results.

## Prerequisites

| Requirement | C# | Python |
|-------------|-----|--------|
| Docker | Recommended | Recommended |
| Alternative | .NET 8 SDK | Python 3.12 + uv |

## Quick Run (Docker)

### C# Benchmark

```bash
cd c-sharp
./scripts/run-benchmarks.sh smoke
```

### Python Benchmark

```bash
cd python
./scripts/run-benchmarks.sh smoke
```

## Execution Modes

| Mode | Command | Purpose |
|------|---------|---------|
| **Smoke** | `run-benchmarks.sh smoke` | Verify installation (1 repetition) |
| **Verify All** | `run-benchmarks.sh all-single` | Check compatibility (all serializers, 1 rep) |
| **Full** | `run-benchmarks.sh full` | Production results (100 repetitions) |
| **Custom** | `run-benchmarks.sh custom 50 "Json" "Person"` | Filtered run |

## Local Development (No Docker)

### C# (.NET 8)

```bash
cd c-sharp
dotnet build src/GLD.SerializerBenchmark.csproj -c Release
dotnet run --project src -c Release -- 10 "Json" "Person"
```

### Python (uv)

```bash
cd python
uv sync
uv run python -m benchmark.runner 10 "json" "Person"
```

## Results Location

After running, results appear in:

```
logs/
├── csharp/
│   ├── benchmark-log.csv      # Raw timing and size data
│   └── benchmark-errors.csv   # Failure details
└── python/
    ├── benchmark-log.csv
    └── benchmark-errors.csv
```

## Analyze Results

Generate reports from the logs:

```bash
cd analysis
uv run analyze-benchmarks --generate-dashboard --generate-summary
```

Output:
- `reports/dashboard/index.html` — Interactive charts
- `reports/BENCHMARK_SUMMARY.md` — Markdown tables

## View Pre-built Results

See the [Live Dashboard](./benchmark-results.md) for the latest benchmark results.

## Next Steps

- Read the [Methodology](./methodology.md) to understand the measurement approach
- Browse [Serializer Comparisons](./serializers/overview.md) to choose a format
- Explore [C#](./c-sharp/index.md) or [Python](./python/index.md) specific documentation
