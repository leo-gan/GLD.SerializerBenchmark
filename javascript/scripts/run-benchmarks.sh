#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$JS_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/javascript}"
mkdir -p "$LOG_DIR"

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
  FILTER_SER="${FILTER_SER:-JSON}"
  FILTER_DATA="${FILTER_DATA:-Person}"
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"

cd "$JS_DIR"
if [[ ! -d node_modules ]]; then
  echo "[INFO] npm install..."
  npm install --no-fund --no-audit 2>&1 | tail -8
fi

export LOG_DIR
ARGS=("$REPS")
[[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
echo "[INFO] node src/runner.js ${ARGS[*]} (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)"
node src/runner.js "${ARGS[@]}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
ENV_JSON="${CSV%.csv}.environment.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Environment captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write environment.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] JS logs in $LOG_DIR"
