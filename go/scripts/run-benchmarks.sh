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

export PATH="${HOME}/.local/go/bin:${HOME}/.local/bin:${PATH:-}"
# Ensure protoc-gen-go is available for optional regen
export PATH="$(go env GOPATH 2>/dev/null)/bin:${PATH}"

echo "[INFO] Building Go benchmark..."
cd "$GO_DIR"
# Regenerate protobuf if protoc available and script present
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
echo "[INFO] Running: bin/serializer-benchmark-go ${ARGS[*]}"
./bin/serializer-benchmark-go "${ARGS[@]}" -log-dir "$LOG_DIR"
echo "[SUCCESS] Go logs in $LOG_DIR"
