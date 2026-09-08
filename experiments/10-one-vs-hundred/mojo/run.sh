#!/usr/bin/env bash
# mojo run of 10-one-vs-hundred.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" mojo
