#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# First ensure C# data is exported if it doesn't exist
cd "$PROJECT_ROOT"
if [ ! -d "data" ] || [ -z "$(ls -A data)" ]; then
    echo "Exporting test data from C#..."
    dotnet run --project c-sharp/GLD.SerializerBenchmark export-data data
fi

echo "Running Python benchmarks locally..."
cd "$PROJECT_ROOT/python"
uv sync
./scripts/compile_protos.sh
uv run pytest benchmark.py
