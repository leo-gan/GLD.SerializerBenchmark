#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$C_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/c}"
mkdir -p "$LOG_DIR" "$C_DIR/build"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES " in
  *" $MODE "*) ;;
  *) echo "Usage: $0 [smoke|all-single|full|research] [serializerFilter] [dataFilter]"; exit 1 ;;
esac

REPS="$(bench_mode_reps "$MODE")"
if [[ "$MODE" == "smoke" ]]; then
  FILTER_SER="${FILTER_SER:-cJSON}"
  FILTER_DATA="${FILTER_DATA:-Person}"
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"

echo "[INFO] Building C benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cmake -S "$C_DIR" -B "$C_DIR/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$C_DIR/build" -j"$(nproc 2>/dev/null || echo 2)"

export LOG_DIR
ARGS=("$REPS")
[[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
echo "[INFO] Running serializer_benchmark_c ${ARGS[*]}"
"$C_DIR/build/serializer_benchmark_c" "${ARGS[@]}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write configs.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] C logs in $LOG_DIR"
