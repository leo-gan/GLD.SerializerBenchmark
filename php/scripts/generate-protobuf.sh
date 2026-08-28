#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_DIR="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$PHP_DIR/.." && pwd)"
OUT="$PHP_DIR/src/Generated"
mkdir -p "$OUT"
protoc --php_out="$OUT" --proto_path="$REPO/schemas/v2/protobuf" \
  "$REPO/schemas/v2/protobuf/benchmark_v2.proto"
echo "wrote PHP protobuf classes under $OUT"
