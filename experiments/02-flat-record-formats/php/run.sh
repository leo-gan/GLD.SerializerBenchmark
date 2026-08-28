#!/usr/bin/env bash
# php run of this experiment.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" php
