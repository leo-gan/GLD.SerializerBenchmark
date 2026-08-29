#!/usr/bin/env bash
# Generate C++ Cap'n Proto types from the shared suite schema
# (cpp/schemas/benchmark.capnp) for the official C++ runtime.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$ZIG_DIR/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"
if ! command -v capnp >/dev/null 2>&1; then
  echo "error: capnp not on PATH" >&2
  exit 1
fi
OUT="$ZIG_DIR/src/gen/capnp"
mkdir -p "$OUT"
capnp compile -oc++:"$OUT" --src-prefix="$ROOT/cpp/schemas" \
  "$ROOT/cpp/schemas/benchmark.capnp"
if [[ -f "$OUT/benchmark.capnp.c++" ]]; then
  mv -f "$OUT/benchmark.capnp.c++" "$OUT/benchmark.capnp.cpp"
fi
echo "wrote Cap'n Proto C++ types under $OUT"
ls -la "$OUT"
