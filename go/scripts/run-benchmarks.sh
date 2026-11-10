#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$GO_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner go "encoding/json" "$@"

if ! command -v go >/dev/null 2>&1; then
  echo "[ERROR] go not found. Run: ./scripts/install-host-requirements.sh go" >&2
  exit 1
fi
# GOPATH/bin is needed for protoc-gen-go. It can also hold an older go than the
# one already selected on PATH (this machine: 1.22.10 vs the module toolchain).
go_bin_dir="$(dirname "$(command -v go)")"
export PATH="$(go env GOPATH 2>/dev/null)/bin:${PATH:-}"
export PATH="${go_bin_dir}:${PATH}"

echo "[INFO] Building Go benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cd "$GO_DIR"
if [[ -x "$GO_DIR/scripts/generate-protobuf.sh" ]]; then
  "$GO_DIR/scripts/generate-protobuf.sh" || echo "[WARN] protobuf generation skipped/failed"
fi
go build -o bin/serializer-benchmark-go .

echo "[INFO] Running: bin/serializer-benchmark-go -log-dir $LOG_DIR ${ARGS[*]}"
./bin/serializer-benchmark-go -log-dir "$LOG_DIR" "${ARGS[@]}"

bench_finish_runner Go
