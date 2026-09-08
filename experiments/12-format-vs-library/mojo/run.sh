#!/usr/bin/env bash
# mojo run of 12-format-vs-library.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" mojo
