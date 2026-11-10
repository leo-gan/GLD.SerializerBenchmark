#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$JS_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner javascript JSON "$@"

cd "$JS_DIR"
if [[ ! -d node_modules ]]; then
  echo "[INFO] npm install..."
  npm install --no-fund --no-audit 2>&1 | tail -8
fi

echo "[INFO] node src/runner.js ${ARGS[*]} (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)"
node src/runner.js "${ARGS[@]}"

bench_finish_runner JS
