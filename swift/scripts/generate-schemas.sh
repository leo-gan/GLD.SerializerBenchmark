#!/usr/bin/env bash
# Regenerate SwiftProtobuf + FlatBuffers sources from monorepo schemas.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$SWIFT_DIR/.." && pwd)"
OUT="$SWIFT_DIR/Sources/SerializerBenchmarkCore/Generated"
mkdir -p "$OUT" "$SWIFT_DIR/schemas"

if [[ -x "${HOME}/.local/bin/protoc-gen-swift" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi
if [[ -x "${HOME}/.local/bin/flatc" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi
if [[ -x "${HOME}/.local/bin/capnp" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

echo "[INFO] protoc → SwiftProtobuf"
protoc \
  --plugin=protoc-gen-swift="$(command -v protoc-gen-swift)" \
  --swift_out="$OUT" \
  --swift_opt=Visibility=Public \
  -I "$ROOT/schemas/v2/protobuf" \
  "$ROOT/schemas/v2/protobuf/benchmark_v2.proto"

echo "[INFO] flatc → FlatBuffers Swift"
cp -f "$ROOT/cpp/schemas/benchmark.fbs" "$SWIFT_DIR/schemas/benchmark.fbs"
flatc --swift -o "$OUT" "$SWIFT_DIR/schemas/benchmark.fbs"

echo "[INFO] capnp → C++ (CapnpBridge)"
cp -f "$ROOT/cpp/schemas/benchmark.capnp" "$SWIFT_DIR/schemas/benchmark.capnp"
capnp compile -oc++:"$SWIFT_DIR/Sources/CapnpBridge/cxx" --src-prefix="$SWIFT_DIR/schemas" \
  "$SWIFT_DIR/schemas/benchmark.capnp"
# normalize extension for SPM
if [[ -f "$SWIFT_DIR/Sources/CapnpBridge/cxx/benchmark.capnp.c++" ]]; then
  mv -f "$SWIFT_DIR/Sources/CapnpBridge/cxx/benchmark.capnp.c++" \
        "$SWIFT_DIR/Sources/CapnpBridge/cxx/benchmark.capnp.cpp"
fi

echo "[SUCCESS] Generated sources under $OUT and CapnpBridge/cxx"
