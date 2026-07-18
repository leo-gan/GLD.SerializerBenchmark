#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
mkdir -p generated/v2
# Suite schema: Data Model v2 — ephemeral uv env (no global tool install)
uv run --with grpcio-tools python -m grpc_tools.protoc \
  -I../schemas/v2/protobuf \
  --python_out=generated/v2 \
  ../schemas/v2/protobuf/benchmark_v2.proto
touch generated/__init__.py generated/v2/__init__.py
echo "Protobuf models compiled successfully (benchmark_v2)."
