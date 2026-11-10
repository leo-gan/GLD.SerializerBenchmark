#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$CPP_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner cpp nlohmann_json "$@"
mkdir -p "$CPP_DIR/build"

if ! command -v cmake >/dev/null 2>&1; then
  echo "[ERROR] cmake not found. Run: ./scripts/install-host-requirements.sh cpp" >&2
  exit 1
fi
if ! command -v g++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then
  echo "[ERROR] C++ compiler not found (g++/clang++)" >&2
  exit 1
fi

echo "[INFO] Building C++ benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cmake -S "$CPP_DIR" -B "$CPP_DIR/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$CPP_DIR/build" -j"$(nproc 2>/dev/null || echo 2)" --target serializer_benchmark_cpp

CPP_ARGS=("--reps" "$REPS" "--log-dir" "$LOG_DIR")
[[ -n "$FILTER_SER" ]] && CPP_ARGS+=("--serializer" "$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && CPP_ARGS+=("--data" "$FILTER_DATA")
echo "[INFO] Running serializer_benchmark_cpp ${CPP_ARGS[*]}"
"$CPP_DIR/build/serializer_benchmark_cpp" "${CPP_ARGS[@]}"

bench_finish_runner "C++"
