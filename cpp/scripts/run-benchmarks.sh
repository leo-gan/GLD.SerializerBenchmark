#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$CPP_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/cpp}"
mkdir -p "$LOG_DIR" "$CPP_DIR/build"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event (smoke default: message)"
    exit 1
    ;;
esac

if [[ "$MODE" == "custom" ]]; then
  REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}"
else
  REPS="$(bench_mode_reps "$MODE")"
  if [[ "$MODE" == "smoke" ]]; then
    FILTER_SER="${FILTER_SER:-nlohmann_json}"
    FILTER_DATA="${FILTER_DATA:-message}"
  fi
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_REPO_ROOT="${BENCHMARK_REPO_ROOT:-$PROJECT_ROOT}"
export BENCHMARK_LANGUAGE=cpp

# Library run config from master config (data_model_v2.smoke_run_config / default_run_config).
# Caller may override with BENCHMARK_RUN_CONFIG=...
bench_export_run_config "$MODE"

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

export LOG_DIR
ARGS=("--reps" "$REPS" "--log-dir" "$LOG_DIR")
[[ -n "$FILTER_SER" ]] && ARGS+=("--serializer" "$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("--data" "$FILTER_DATA")
echo "[INFO] Running serializer_benchmark_cpp ${ARGS[*]}"
"$CPP_DIR/build/serializer_benchmark_cpp" "${ARGS[@]}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" BENCHMARK_LANGUAGE=cpp \
      PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write configs.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] C++ logs in $LOG_DIR"
