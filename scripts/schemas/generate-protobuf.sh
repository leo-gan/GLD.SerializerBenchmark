#!/usr/bin/env bash
# Generate Protocol Buffer stubs for Data Model v2.
# Currently emits Python into python/generated/v2/ when protoc + plugin available.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROTO_DIR="$ROOT/schemas/v2/protobuf"
PROTO="$PROTO_DIR/benchmark_v2.proto"

if [[ ! -f "$PROTO" ]]; then
  echo "error: missing $PROTO" >&2
  exit 1
fi

OUT_PY="$ROOT/python/generated/v2"
mkdir -p "$OUT_PY"

if command -v protoc >/dev/null 2>&1; then
  # Prefer grpc_tools if present for Python; else plain protoc.
  if python3 -c "import grpc_tools.protoc" 2>/dev/null; then
    python3 -m grpc_tools.protoc \
      -I"$PROTO_DIR" \
      --python_out="$OUT_PY" \
      "$PROTO"
  else
    protoc -I"$PROTO_DIR" --python_out="$OUT_PY" "$PROTO" || {
      echo "warning: protoc failed for Python; schema sources still valid" >&2
      exit 0
    }
  fi
  touch "$OUT_PY/__init__.py"
  echo "generated: $OUT_PY"
else
  echo "warning: protoc not found; skipped Python codegen (sources in schemas/v2/protobuf)" >&2
fi
