#!/usr/bin/env bash
set -e

# First ensure C# data is exported if it doesn't exist
if [ ! -d "data" ] || [ -z "$(ls -A data)" ]; then
    echo "Exporting test data from C#..."
    dotnet run --project GLD.SerializerBenchmark export-data data
fi

echo "Running Python benchmarks locally..."
cd python
uv sync
./compile_protos.sh
uv run pytest benchmark.py
