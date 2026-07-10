#!/usr/bin/env bash
# Local convenience wrapper (no Docker). Prefer ./scripts/run-benchmarks.sh for full runs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

cd "$PROJECT_ROOT/python"
if command -v uv >/dev/null 2>&1; then
  uv sync
else
  echo "[WARN] uv not found; assuming dependencies already installed"
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_DATA_MODEL=v2
export LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs}"
export BENCHMARK_RUN_CONFIG="${BENCHMARK_RUN_CONFIG:-$PROJECT_ROOT/config/library/default.yaml}"

REPS="${1:-$(bench_mode_reps all-single)}"
shift || true
echo "[INFO] Local Python v2 run: reps=$REPS seed=$BENCHMARK_SEED args=$*"
# Package entry (delegates to runner_v2; same as Docker image)
if command -v uv >/dev/null 2>&1; then
  uv run python -m benchmark.runner "$REPS" "$@"
else
  PYTHONPATH=src${PYTHONPATH:+:$PYTHONPATH} python3 -m benchmark.runner "$REPS" "$@"
fi
