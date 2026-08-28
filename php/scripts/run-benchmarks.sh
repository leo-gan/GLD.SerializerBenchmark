#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PHP_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

# Prefer user-local PHP / Composer from install-host-requirements.sh
if [[ -x "${HOME}/.local/php/bin/php" ]]; then
  export PATH="${HOME}/.local/php/bin:${PATH}"
fi
if [[ -x "${HOME}/.local/bin/composer" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/php}"
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
  FILTER_SER="${FILTER_SER:-json}"
  FILTER_DATA="${FILTER_DATA:-message}"
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_LANGUAGE=php

bench_export_run_config "$MODE"

if ! command -v php >/dev/null 2>&1; then
  echo "[ERROR] php not found. Run: ./scripts/install-host-requirements.sh php" >&2
  exit 1
fi

cd "$PHP_DIR"
if [[ ! -d vendor ]]; then
  if command -v composer >/dev/null 2>&1; then
    echo "[INFO] composer install..."
    composer install --no-dev --no-interaction --prefer-dist
  else
    echo "[ERROR] composer not found. Run: ./scripts/install-host-requirements.sh php" >&2
    exit 1
  fi
fi

export LOG_DIR
ARGS=("$REPS")
[[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
echo "[INFO] php src/Runner.php ${ARGS[*]} (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $(php -v | head -1)"
php src/Runner.php "${ARGS[@]}"

echo "[SUCCESS] PHP logs in $LOG_DIR"
