#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$C_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner c cJSON "$@"
mkdir -p "$C_DIR/build"

if [[ ! -f "$C_DIR/third_party/_prefix/lib/libjansson.a" || ! -f "$C_DIR/third_party/gld-kiln-c/build/libkiln.a" ]]; then
  echo "[INFO] C third_party deps missing; running fetch-and-build-deps.sh (first run may take several minutes)..."
  "$C_DIR/scripts/fetch-and-build-deps.sh"
fi

echo "[INFO] Building C benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cmake -S "$C_DIR" -B "$C_DIR/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$C_DIR/build" -j"$(nproc 2>/dev/null || echo 2)"

echo "[INFO] Running serializer_benchmark_c ${ARGS[*]}"
"$C_DIR/build/serializer_benchmark_c" "${ARGS[@]}"

bench_finish_runner C
