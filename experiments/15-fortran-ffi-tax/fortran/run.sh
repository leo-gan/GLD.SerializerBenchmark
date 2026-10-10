#!/usr/bin/env bash
# fortran run of 15-fortran-ffi-tax. Builds the FFI executable, not the leaderboard runner.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../run.sh" fortran
