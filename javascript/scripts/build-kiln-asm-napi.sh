#!/usr/bin/env bash
# Compile the thin Node.js N-API C addon for gld-kiln-asm 0.2.0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$JS_DIR/.." && pwd)"

KILN_DIR="$PROJECT_ROOT/build/kiln-asm"
if [[ ! -f "$KILN_DIR/libkiln_asm_bench.a" || ! -f "$KILN_DIR/include/kiln_asm_bench.h" ]]; then
    "$PROJECT_ROOT/scripts/build-kiln-asm-bench.sh"
fi

NODE_INC=""
NODE_PREFIX=""
if command -v node >/dev/null 2>&1; then
    NODE_PREFIX="$(dirname "$(dirname "$(command -v node)")")"
fi
for cand in \
    "${NODE_PREFIX}/include/node" \
    "/usr/include/node" \
    "$JS_DIR/node_modules/node-addon-api/external-napi" \
    "$JS_DIR/node_modules/node-addon-api/src"
do
    if [[ -n "$cand" && -f "$cand/node_api.h" ]]; then
        NODE_INC="$cand"
        break
    fi
done
if [[ -z "$NODE_INC" ]]; then
    echo "ERROR: node_api.h not found under /usr/include/node or node_modules/node-addon-api" >&2
    exit 1
fi

SRC="$JS_DIR/src/serializers/kiln_asm_napi.c"
OUT="$KILN_DIR/kiln_asm_napi.node"

if [[ ! -f "$OUT" || "$SRC" -nt "$OUT" || "$KILN_DIR/libkiln_asm_bench.a" -nt "$OUT" ]]; then
    echo "[kiln-asm] Building Node N-API addon -> build/kiln-asm/kiln_asm_napi.node"
    gcc -O3 -fPIC -shared -Wall -Wextra \
        -I"$NODE_INC" \
        -I"$KILN_DIR/include" \
        "$SRC" "$KILN_DIR/libkiln_asm_bench.a" \
        -o "$OUT"
fi
