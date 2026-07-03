#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$GO_DIR/.." && pwd)"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/go}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

case "$MODE" in
  smoke) REPS=2; FILTER_SER="${FILTER_SER:-encoding/json}"; FILTER_DATA="${FILTER_DATA:-Person}" ;;
  all-single) REPS=10 ;;
  full) REPS=100 ;;
  research) REPS=500 ;;
  custom) REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}" ;;
  *) echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"; exit 1 ;;
esac

# Same stem for result CSV, errors.csv, and environment.json (python/csharp pattern).
export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"

export PATH="${HOME}/.local/go/bin:${HOME}/.local/bin:${PATH:-}"
export PATH="$(go env GOPATH 2>/dev/null)/bin:${PATH}"

echo "[INFO] Building Go benchmark..."
cd "$GO_DIR"
if [[ -x "$GO_DIR/scripts/generate-protobuf.sh" ]]; then
  "$GO_DIR/scripts/generate-protobuf.sh" || echo "[WARN] protobuf generation skipped/failed"
fi
go build -o bin/serializer-benchmark-go .

ARGS=("$REPS")
if [[ "$MODE" != "custom" ]]; then
  [[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
  [[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
else
  ARGS=("$REPS")
  [[ -n "${3:-}" ]] && ARGS+=("$3")
  [[ -n "${4:-}" ]] && ARGS+=("$4")
fi

export LOG_DIR
# Flags must precede positionals (Go flag.Parse stops at first non-flag).
echo "[INFO] Running: bin/serializer-benchmark-go -log-dir $LOG_DIR ${ARGS[*]}"
./bin/serializer-benchmark-go -log-dir "$LOG_DIR" "${ARGS[@]}"

# Environment sidecar (same as python/c-sharp run-benchmarks.sh; also done by run-all).
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

echo "[SUCCESS] Go logs in $LOG_DIR"
