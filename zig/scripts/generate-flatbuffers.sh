#!/usr/bin/env bash
# Generate Zig FlatBuffers types from the shared suite schema
# (cpp/schemas/benchmark.fbs) via nDimensional/zig-flatbuffers.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$ZIG_DIR/.." && pwd)"
export PATH="${HOME}/.local/zig:${HOME}/.local/bin:${PATH}"
if ! command -v zig >/dev/null 2>&1; then
  echo "error: zig not on PATH (need 0.16.x)" >&2
  exit 1
fi
if ! command -v flatc >/dev/null 2>&1; then
  echo "error: flatc not on PATH" >&2
  exit 1
fi
OUT="$ZIG_DIR/src/gen/flatbuffers"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
flatc -b --schema --bfbs-comments --bfbs-builtins -o "$TMP" \
  "$ROOT/cpp/schemas/benchmark.fbs"
PKG="$(find "$ZIG_DIR/zig-pkg" -maxdepth 1 -type d -name 'flatbuffers-*' | head -1)"
if [[ -z "$PKG" ]]; then
  echo "error: zig-flatbuffers package not fetched; run: (cd zig && zig build)" >&2
  exit 1
fi
(cd "$PKG" && zig build parse -- "$TMP/benchmark.bfbs") > "$OUT/benchmark.zon"
(cd "$PKG" && zig build generate -- "$OUT/benchmark.zon") | zig fmt --stdin > "$OUT/benchmark.zig"
echo "wrote Zig FlatBuffers types under $OUT"
ls -la "$OUT"
