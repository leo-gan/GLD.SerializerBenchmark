#!/usr/bin/env bash
# Regenerate all Data Model v2 schema language artifacts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> protobuf"
"$ROOT/scripts/schemas/generate-protobuf.sh"

if command -v zig >/dev/null 2>&1 || [[ -x "${HOME}/.local/zig/zig" ]]; then
  echo "==> zig protobuf"
  "$ROOT/zig/scripts/generate-protobuf.sh"
  if command -v flatc >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/flatc" ]]; then
    echo "==> zig flatbuffers"
    "$ROOT/zig/scripts/generate-flatbuffers.sh"
  fi
fi
if command -v capnp >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/capnp" ]]; then
  echo "==> zig capnp"
  "$ROOT/zig/scripts/generate-capnp.sh"
fi

# Future: avro, flatbuffers, …
echo "==> done (schemas/v2)"
