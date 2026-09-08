#!/usr/bin/env bash
# mojo run of 07-write-once-read-many.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" mojo
