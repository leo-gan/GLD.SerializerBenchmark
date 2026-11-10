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

bench_init_runner php json "$@"

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

echo "[INFO] php src/Runner.php ${ARGS[*]} (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $(php -v | head -1)"
php src/Runner.php "${ARGS[@]}"

bench_finish_runner PHP
