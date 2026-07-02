#!/usr/bin/env bash
# Regenerate FlatBuffers Python tables from benchmark.fbs
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/src/benchmark/schemas/flatbuffers/benchmark.fbs"
OUT="$ROOT/generated/flatbuffers_gen"
FLATC="${FLATC:-flatc}"
if ! command -v "$FLATC" >/dev/null 2>&1; then
  echo "flatc not found; set FLATC= to a flatc binary" >&2
  exit 1
fi
mkdir -p "$OUT"
"$FLATC" --python -o "$OUT" "$SCHEMA"
echo "Generated FlatBuffers Python into $OUT"
