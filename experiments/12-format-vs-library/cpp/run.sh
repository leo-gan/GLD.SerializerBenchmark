#!/usr/bin/env bash
# cpp run of Experiment 12.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" cpp
