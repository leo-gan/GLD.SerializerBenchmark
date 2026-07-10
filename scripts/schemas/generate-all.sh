#!/usr/bin/env bash
# Regenerate all Data Model v2 schema language artifacts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> protobuf"
"$ROOT/scripts/schemas/generate-protobuf.sh"

# Future: avro, flatbuffers, …
echo "==> done (schemas/v2)"
