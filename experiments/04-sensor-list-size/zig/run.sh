#!/usr/bin/env bash
# zig run of 04-sensor-list-size.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" zig
