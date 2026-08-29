#!/usr/bin/env bash
# Generate Zig protobuf types from the shared suite schema
# (schemas/v2/protobuf/benchmark_v2.proto) via Arwalk/zig-protobuf.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG_DIR="$(cd "$HERE/.." && pwd)"
export PATH="${HOME}/.local/zig:${HOME}/.local/bin:${PATH}"
if ! command -v zig >/dev/null 2>&1; then
  echo "error: zig not on PATH (need 0.16.x)" >&2
  exit 1
fi
mkdir -p "$ZIG_DIR/src/gen"
(cd "$ZIG_DIR" && zig build gen-proto)
echo "wrote Zig protobuf types under $ZIG_DIR/src/gen"
ls -la "$ZIG_DIR/src/gen/benchmark/"
