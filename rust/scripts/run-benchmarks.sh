#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$RUST_DIR/.." && pwd)"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/rust}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

case "$MODE" in
  smoke) REPS=2; FILTER_SER="${FILTER_SER:-serde_json}"; FILTER_DATA="${FILTER_DATA:-Person}" ;;
  all-single) REPS=10 ;;
  full) REPS=100 ;;
  research) REPS=500 ;;
  custom) REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}" ;;
  *) echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"; exit 1 ;;
esac

echo "[INFO] Building Rust benchmark (release)..."
cd "$RUST_DIR"
source "$HOME/.cargo/env" 2>/dev/null || true
cargo build --release 2>&1 | tail -5

ARGS=("$REPS")
[[ -n "$FILTER_SER" && "$MODE" != "custom" ]] && ARGS+=("$FILTER_SER")
[[ -n "$FILTER_DATA" && "$MODE" != "custom" ]] && ARGS+=("$FILTER_DATA")
if [[ "$MODE" == "custom" ]]; then
  ARGS=("$REPS")
  [[ -n "${3:-}" ]] && ARGS+=("$3")
  [[ -n "${4:-}" ]] && ARGS+=("$4")
fi

export LOG_DIR
echo "[INFO] Running: target/release/serializer-benchmark-rust ${ARGS[*]}"
./target/release/serializer-benchmark-rust "${ARGS[@]}" --log-dir "$LOG_DIR"
echo "[SUCCESS] Rust logs in $LOG_DIR"
