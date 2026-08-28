#!/usr/bin/env bash
# zig run of 01-json-library-bakeoff.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" zig
