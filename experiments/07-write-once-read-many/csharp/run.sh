#!/usr/bin/env bash
# csharp run of Experiment 7.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" csharp
