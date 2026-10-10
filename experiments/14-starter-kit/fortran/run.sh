#!/usr/bin/env bash
# fortran run of 14-starter-kit.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" fortran
