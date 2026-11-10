#!/usr/bin/env bash
# Native .NET 10 runner (same pattern as go/rust/javascript/c — no Docker).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$CS_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner csharp Json.Net "$@"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "[ERROR] dotnet not found. Run: ./scripts/install-host-requirements.sh csharp" >&2
  echo "        Or install .NET SDK 10.0+: https://dotnet.microsoft.com/download" >&2
  exit 1
fi

echo "[INFO] Building C# benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cd "$CS_DIR"
bash "$SCRIPT_DIR/fetch-gld-kiln.sh"
dotnet build src/GLD.SerializerBenchmark.csproj -c Release --nologo -v q

export PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}"
echo "[INFO] Running: dotnet run --project src -c Release --no-build -- ${ARGS[*]}"
dotnet run --project src/GLD.SerializerBenchmark.csproj -c Release --no-build -- "${ARGS[@]}"

bench_finish_runner "C#"
