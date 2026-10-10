#!/usr/bin/env bash
# Build the experiment-15 Fortran executable. It is not the leaderboard runner.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$HERE/ffi_bench}"
# shellcheck disable=SC1091
source "$ROOT/fortran/scripts/fpm-env.sh"
FC="${FPM_FC:-gfortran}"
MOD="${TMPDIR:-/tmp}/gld-ffi-mod-$$"
mkdir -p "$MOD"
cmake -S "$ROOT/c" -B "$ROOT/c/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/c/build" --target gld_ffi_probe -j"$(nproc 2>/dev/null || echo 2)"
"$FC" -O2 -fno-lto -J "$MOD" -c "$ROOT/fortran/src/data.f90" -o "$MOD/data.o"
"$FC" -O2 -fno-lto -J "$MOD" -I "$MOD" -c "$ROOT/fortran/src/csv_log.f90" -o "$MOD/csv.o"
"$FC" -O2 -fno-lto -J "$MOD" -I "$MOD" -c "$ROOT/fortran/ffi/ffi_bench.f90" -o "$MOD/ffi.o"
cc -O2 -fno-lto -c "$ROOT/fortran/src/black_box.c" -o "$MOD/bb.o"
python3 - "$ROOT/c/build/CMakeFiles/gld_ffi_probe.dir/link.txt" "$MOD/linkargs" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text().split()
out = []
skip = False
for i, tok in enumerate(text):
    if i == 0 or tok == "-o":
        skip = tok == "-o"
        continue
    if skip:
        skip = False
        continue
    if tok.endswith("ffi_probe.c.o"):
        continue
    if tok.endswith("libgld_ffi.a") or tok.endswith("/libgld_ffi.a"):
        out.extend(["-Wl,--whole-archive", tok, "-Wl,--no-whole-archive"])
        continue
    out.append(tok)
Path(sys.argv[2]).write_text("\n".join(out) + "\n")
PY
(
  cd "$ROOT/c/build"
  # shellcheck disable=SC2046
  "$FC" -O2 -fno-lto -o "$OUT" "$MOD/ffi.o" "$MOD/data.o" "$MOD/csv.o" "$MOD/bb.o" $(cat "$MOD/linkargs")
)
rm -rf "$MOD"
echo "[OK] $OUT"
