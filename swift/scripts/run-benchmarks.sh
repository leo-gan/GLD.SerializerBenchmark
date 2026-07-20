#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SWIFT_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

# Prefer user-local Swift toolchain when present.
if [[ -x "${HOME}/.local/swift/usr/bin/swift" ]]; then
  export PATH="${HOME}/.local/swift/usr/bin:${PATH}"
fi
if [[ -d "${HOME}/.local/bin" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi
if [[ -d "${HOME}/.local/lib" ]]; then
  export LD_LIBRARY_PATH="${HOME}/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LIBRARY_PATH="${HOME}/.local/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
fi

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/swift}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event (smoke default: message)"
    exit 1
    ;;
esac

REPS="$(bench_mode_reps "$MODE")"
if [[ "$MODE" == "smoke" ]]; then
  FILTER_SER="${FILTER_SER:-JSON}"
  FILTER_DATA="${FILTER_DATA:-message}"
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"

# Library run config from master config (data_model_v2.smoke_run_config / default_run_config).
# Caller may override with BENCHMARK_RUN_CONFIG=...
bench_export_run_config "$MODE"

cd "$SWIFT_DIR"
if ! command -v swift >/dev/null 2>&1; then
  echo "[ERROR] swift not found. Install via ./scripts/install-host-requirements.sh swift" >&2
  exit 1
fi

echo "[INFO] swift build -c release (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)"
swift build -c release 2>&1

BIN="$(swift build -c release --show-bin-path)/serializer-benchmark-swift"
export LOG_DIR
ARGS=("$REPS")
[[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
echo "[INFO] $BIN ${ARGS[*]}"
"$BIN" "${ARGS[@]}"

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

echo "[SUCCESS] Swift logs in $LOG_DIR"
