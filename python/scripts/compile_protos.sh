#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
mkdir -p generated
# Ensure grpcio-tools is installed as a tool or use system protoc
uv tool install grpcio-tools
python-grpc-tools-protoc -I../schemas --python_out=generated ../schemas/benchmark_data.proto
touch generated/__init__.py
echo "Protobuf models compiled successfully."
