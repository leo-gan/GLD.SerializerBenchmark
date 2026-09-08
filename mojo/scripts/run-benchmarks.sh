#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOJO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$MOJO_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

if [[ -x "${HOME}/.pixi/bin/pixi" ]]; then
  export PATH="${HOME}/.pixi/bin:${PATH}"
fi

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/mojo}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event (smoke default: message)"
    exit 1
    ;;
esac

REPS="$(bench_mode_reps "$MODE")"
if [[ "$MODE" == "smoke" ]]; then
  FILTER_SER="${FILTER_SER:-EmberJson}"
  FILTER_DATA="${FILTER_DATA:-message}"
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_LANGUAGE=mojo

bench_export_run_config "$MODE"

if ! command -v pixi >/dev/null 2>&1; then
  echo "[ERROR] pixi not found. Run: ./scripts/install-host-requirements.sh mojo" >&2
  exit 1
fi

cd "$MOJO_DIR"
if [[ ! -d .pixi/envs/default ]]; then
  echo "[INFO] pixi install..."
  pixi install
fi

RESOLVED="$LOG_DIR/${BENCHMARK_TS}.resolved.json"
PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
  python3 "$PROJECT_ROOT/scripts/resolve_run_config.py" \
    "${BENCHMARK_RUN_CONFIG}" --seed "$BENCHMARK_SEED" > "$RESOLVED"
export BENCHMARK_RESOLVED_JSON="$RESOLVED"

INCLUDE=(-I src -I vendor/cbor_src -I vendor/pb_src -I vendor/toml_src -I vendor/ehsanmok_src)
export LOG_DIR
ARGS=("$REPS")
[[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
echo "[INFO] pixi run mojo run ${INCLUDE[*]} src/main.mojo -- ${ARGS[*]} (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)"
pixi run mojo run "${INCLUDE[@]}" src/main.mojo -- "${ARGS[@]}"

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

echo "[SUCCESS] Mojo logs in $LOG_DIR"
