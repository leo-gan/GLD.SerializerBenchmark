#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$JS_DIR/.." && pwd)"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/javascript}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

case "$MODE" in
  smoke) REPS=2; FILTER_SER="${FILTER_SER:-JSON}"; FILTER_DATA="${FILTER_DATA:-Person}" ;;
  all-single) REPS=10 ;;
  full) REPS=100 ;;
  research) REPS=500 ;;
  *) echo "Usage: $0 [smoke|all-single|full|research] [serializerFilter] [dataFilter]"; exit 1 ;;
esac

cd "$JS_DIR"
if [[ ! -d node_modules ]]; then
  echo "[INFO] npm install..."
  npm install --no-fund --no-audit 2>&1 | tail -8
fi

export LOG_DIR
ARGS=("$REPS")
[[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
echo "[INFO] node src/runner.js ${ARGS[*]}"
node src/runner.js "${ARGS[@]}"
echo "[SUCCESS] JS logs in $LOG_DIR"
