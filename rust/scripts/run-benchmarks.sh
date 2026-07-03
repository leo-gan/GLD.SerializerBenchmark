#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$RUST_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/rust}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *) echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"; exit 1 ;;
esac

if [[ "$MODE" == "custom" ]]; then
  REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}"
else
  REPS="$(bench_mode_reps "$MODE")"
  if [[ "$MODE" == "smoke" ]]; then
    FILTER_SER="${FILTER_SER:-serde_json}"
    FILTER_DATA="${FILTER_DATA:-Person}"
  fi
fi

export BENCHMARK_SEED="$(bench_random_seed)"

echo "[INFO] Building Rust benchmark (release, mode=$MODE reps=$REPS)..."
cd "$RUST_DIR"
source "$HOME/.cargo/env" 2>/dev/null || true
cargo build --release 2>&1 | tail -5

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
echo "[INFO] Running: target/release/serializer-benchmark-rust ${ARGS[*]}"
./target/release/serializer-benchmark-rust "${ARGS[@]}" --log-dir "$LOG_DIR"
echo "[SUCCESS] Rust logs in $LOG_DIR"
