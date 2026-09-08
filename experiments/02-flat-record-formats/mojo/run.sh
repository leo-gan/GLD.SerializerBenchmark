#!/usr/bin/env bash
# mojo run of 02-flat-record-formats.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" mojo
