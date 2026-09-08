#!/usr/bin/env bash
# mojo run of 14-starter-kit.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" mojo
