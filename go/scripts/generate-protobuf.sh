#!/usr/bin/env bash
# Generate Data Model v2 protobuf bindings into gen/pbv2/.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$GO_DIR/.." && pwd)"
export PATH="${HOME}/.local/go/bin:${HOME}/.local/bin:$(go env GOPATH 2>/dev/null)/bin:${PATH}"

if ! command -v protoc-gen-go >/dev/null 2>&1; then
  go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.1
fi

PROTO_SRC="$ROOT/schemas/v2/protobuf/benchmark_v2.proto"
if [[ ! -f "$PROTO_SRC" ]]; then
  echo "error: missing $PROTO_SRC" >&2
  exit 1
fi

# V1 bindings removed; drop any leftover gen/pb.
rm -rf "$GO_DIR/gen/pb"
mkdir -p "$GO_DIR/gen/pbv2"
TMP_DIR="$(mktemp -d)"
TMP_PROTO="$TMP_DIR/benchmark_v2.proto"
{
  echo 'syntax = "proto3";'
  echo 'package benchmark.v2;'
  echo 'option go_package = "serializer-benchmark-go/gen/pbv2;benchmarkv2";'
  # Drop syntax/package/option go_package lines from shared schema
  grep -v -E '^\s*(syntax|package)\s' "$PROTO_SRC" | grep -v -E '^\s*option\s+go_package\s'
} > "$TMP_PROTO"

protoc \
  --proto_path="$TMP_DIR" \
  --go_out="$GO_DIR/gen/pbv2" \
  --go_opt=paths=source_relative \
  benchmark_v2.proto

rm -rf "$TMP_DIR"
echo "[OK] generated $GO_DIR/gen/pbv2/benchmark_v2.pb.go"
ls -la "$GO_DIR/gen/pbv2/"
