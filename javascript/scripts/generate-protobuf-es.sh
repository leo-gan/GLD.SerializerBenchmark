#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/src/generated"
protoc \
  --plugin=protoc-gen-es="$ROOT/node_modules/.bin/protoc-gen-es" \
  --es_out="$ROOT/src/generated" \
  --es_opt=target=js+dts \
  -I "$ROOT/schemas" \
  "$ROOT/schemas/js_fixtures.proto"
echo "[OK] wrote $ROOT/src/generated/js_fixtures_pb.js"
