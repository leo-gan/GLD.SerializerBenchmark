#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$RUST_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner rust serde_json "$@"

echo "[INFO] Building Rust benchmark (release, mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cd "$RUST_DIR"
source "$HOME/.cargo/env" 2>/dev/null || true
cargo build --release 2>&1 | tail -5

echo "[INFO] Running: target/release/serializer-benchmark-rust ${ARGS[*]}"
./target/release/serializer-benchmark-rust "${ARGS[@]}" --log-dir "$LOG_DIR"

bench_finish_runner Rust
