#!/usr/bin/env bash
# kotlin run of Experiment 3.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" kotlin
