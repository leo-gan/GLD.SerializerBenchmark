#!/usr/bin/env bash
# Native Python runner via uv (same pattern as go/rust/javascript/c — no Docker).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PY_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

export BENCHMARK_DATA_MODEL=v2
bench_init_runner python json "$@"

if ! command -v uv >/dev/null 2>&1; then
  echo "[ERROR] uv not found. Run: ./scripts/install-host-requirements.sh python" >&2
  echo "        Or: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

echo "[INFO] Syncing Python deps (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cd "$PY_DIR"
uv sync

# Package lives under src/ (not installed as an editable wheel).
export PYTHONPATH="$PY_DIR/src:$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}"
echo "[INFO] Running: uv run python -m benchmark.runner ${ARGS[*]}"
uv run python -m benchmark.runner "${ARGS[@]}"

bench_finish_runner Python
