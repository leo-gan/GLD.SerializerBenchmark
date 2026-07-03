#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$GO_DIR/.." && pwd)"
export PATH="${HOME}/.local/go/bin:${HOME}/.local/bin:$(go env GOPATH 2>/dev/null)/bin:${PATH}"

if ! command -v protoc-gen-go >/dev/null 2>&1; then
  go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.1
fi

mkdir -p "$GO_DIR/gen/pb"
TMP_DIR="$(mktemp -d)"
TMP_PROTO="$TMP_DIR/benchmark_data.proto"
{
  echo 'syntax = "proto3";'
  echo 'package benchmark_data;'
  echo 'option go_package = "serializer-benchmark-go/gen/pb";'
  # Drop syntax/package lines from shared schema
  grep -v -E '^\s*(syntax|package)\s' "$ROOT/schemas/benchmark_data.proto"
} > "$TMP_PROTO"

protoc \
  --proto_path="$TMP_DIR" \
  --go_out="$GO_DIR/gen/pb" \
  --go_opt=paths=source_relative \
  benchmark_data.proto

rm -rf "$TMP_DIR"
echo "[OK] generated $GO_DIR/gen/pb/benchmark_data.pb.go"
ls -la "$GO_DIR/gen/pb/"
