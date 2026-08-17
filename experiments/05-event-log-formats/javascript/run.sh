#!/usr/bin/env bash
# javascript run of Experiment 5.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" javascript
