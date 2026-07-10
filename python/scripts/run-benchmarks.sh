#!/usr/bin/env bash
# Native Python runner via uv (same pattern as go/rust/javascript/c — no Docker).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PY_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/python}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event"
    echo "  Requires: Python 3.12+ and uv (https://docs.astral.sh/uv/)"
    exit 1
    ;;
esac

if [[ "$MODE" == "custom" ]]; then
  REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}"
else
  REPS="$(bench_mode_reps "$MODE")"
  if [[ "$MODE" == "smoke" ]]; then
    FILTER_SER="${FILTER_SER:-json}"
    FILTER_DATA="${FILTER_DATA:-message}"
  fi
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_REPO_ROOT="${BENCHMARK_REPO_ROOT:-$PROJECT_ROOT}"
export BENCHMARK_DATA_MODEL=v2
export LOG_DIR

if [[ -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
  if [[ "$MODE" == "smoke" ]]; then
    export BENCHMARK_RUN_CONFIG="$PROJECT_ROOT/config/library/smoke.yaml"
  else
    export BENCHMARK_RUN_CONFIG="$PROJECT_ROOT/config/library/default.yaml"
  fi
fi

export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH:-}"
if ! command -v uv >/dev/null 2>&1; then
  echo "[ERROR] uv not found. Install: https://docs.astral.sh/uv/getting-started/installation/" >&2
  echo "        Or: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

echo "[INFO] Syncing Python deps (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cd "$PY_DIR"
uv sync

ARGS=("$REPS")
if [[ "$MODE" != "custom" ]]; then
  [[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
  [[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
else
  ARGS=("$REPS")
  [[ -n "${3:-}" ]] && ARGS+=("$3")
  [[ -n "${4:-}" ]] && ARGS+=("$4")
fi

# Package lives under src/ (not installed as an editable wheel).
export PYTHONPATH="$PY_DIR/src:$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}"
echo "[INFO] Running: uv run python -m benchmark.runner ${ARGS[*]}"
uv run python -m benchmark.runner "${ARGS[@]}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
if [[ ! -f "$CSV" && -f "$LOG_DIR/python/${BENCHMARK_TS}.csv" ]]; then
  CSV="$LOG_DIR/python/${BENCHMARK_TS}.csv"
fi
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write configs.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] Python logs in $(dirname "$CSV")"
