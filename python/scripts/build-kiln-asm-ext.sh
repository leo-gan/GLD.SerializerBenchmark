#!/usr/bin/env bash
# Compile the thin CPython C-API extension for gld-kiln-asm 0.2.0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PY_DIR/.." && pwd)"

KILN_DIR="$PROJECT_ROOT/build/kiln-asm"
if [[ ! -f "$KILN_DIR/libkiln_asm_bench.a" || ! -f "$KILN_DIR/include/kiln_asm_bench.h" ]]; then
    "$PROJECT_ROOT/scripts/build-kiln-asm-bench.sh"
fi

PY_BIN="${PYTHON_BIN:-$PY_DIR/.venv/bin/python}"
if [[ ! -x "$PY_BIN" ]]; then
    PY_BIN="$(command -v python3)"
fi

PY_INC="$("$PY_BIN" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
EXT_SUFFIX="$("$PY_BIN" -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX") or ".so")')"

SRC="$PY_DIR/src/benchmark/serializers/_kiln_asm_ext.c"
OUT="$PY_DIR/src/benchmark/serializers/_kiln_asm_ext${EXT_SUFFIX}"

if [[ ! -f "$OUT" || "$SRC" -nt "$OUT" || "$KILN_DIR/libkiln_asm_bench.a" -nt "$OUT" ]]; then
    echo "[kiln-asm] Building Python C extension -> $(basename "$OUT")"
    gcc -O3 -fPIC -shared -Wall -Wextra \
        -I"$PY_INC" \
        -I"$KILN_DIR/include" \
        "$SRC" "$KILN_DIR/libkiln_asm_bench.a" \
        -o "$OUT"
fi
