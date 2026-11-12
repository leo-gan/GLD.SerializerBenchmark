#!/usr/bin/env bash
# zig run of 03-memory-vs-stream.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" zig
