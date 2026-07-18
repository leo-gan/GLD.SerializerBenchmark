#!/usr/bin/env bash
# Generate CommonJS stubs for the Google JS runtime (google-protobuf / jspb).
# Uses the suite's vendored protoc 3.12 (built-in --js_out); modern protoc needs protoc-gen-js.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
SYSROOT="${PROTOBUF_SYSROOT:-$REPO/cpp/third_party/protobuf-sysroot}"
PROTOC="${PROTOC:-$SYSROOT/usr/bin/protoc}"
LIBDIR="$SYSROOT/usr/lib/x86_64-linux-gnu"

if [[ ! -x "$PROTOC" ]]; then
  echo "error: protoc not found at $PROTOC — run cpp/scripts/setup-protobuf-sysroot.sh" >&2
  exit 1
fi

export LD_LIBRARY_PATH="${LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
OUT="$ROOT/src/generated/google"
mkdir -p "$OUT"
"$PROTOC" \
  --js_out=import_style=commonjs,binary:"$OUT" \
  -I "$ROOT/schemas" \
  "$ROOT/schemas/js_fixtures.proto"
# package.json is "type": "module" — CommonJS stubs must use .cjs
if [[ -f "$OUT/js_fixtures_pb.js" ]]; then
  mv -f "$OUT/js_fixtures_pb.js" "$OUT/js_fixtures_pb.cjs"
fi
echo "[OK] wrote $OUT/js_fixtures_pb.cjs (google-protobuf / jspb)"
