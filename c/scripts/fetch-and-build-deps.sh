#!/usr/bin/env bash
# Fetch and build vendored C serializer dependencies into c/third_party/
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TP="$C_DIR/third_party"
mkdir -p "$TP" "$TP/_build" "$TP/_prefix"

download() {
  local name="$1" url="$2"
  if [ -d "$TP/$name" ] && [ "$(find "$TP/$name" -name '*.c' -o -name '*.h' | head -1)" ]; then
    echo "[skip] $name already present"
    return 0
  fi
  echo "[get] $name"
  local tmp="$TP/dl-$name.tgz"
  curl -fsSL -L -o "$tmp" "$url"
  rm -rf "$TP/$name" "$TP/_extract_$name"
  mkdir -p "$TP/_extract_$name"
  tar xzf "$tmp" -C "$TP/_extract_$name"
  local top
  top=$(find "$TP/_extract_$name" -mindepth 1 -maxdepth 1 -type d | head -1)
  mv "$top" "$TP/$name"
  rm -rf "$TP/_extract_$name" "$tmp"
}

download cJSON "https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.18.tar.gz"
download yyjson "https://github.com/ibireme/yyjson/archive/refs/tags/0.10.0.tar.gz"
download parson "https://github.com/kgabis/parson/archive/refs/heads/master.tar.gz"
download jansson "https://github.com/akheron/jansson/archive/refs/tags/v2.14.tar.gz"
download mpack "https://github.com/ludocode/mpack/archive/refs/tags/v1.1.tar.gz"
download msgpack-c "https://github.com/msgpack/msgpack-c/archive/refs/tags/c-6.0.1.tar.gz"
download tinycbor "https://github.com/intel/tinycbor/archive/refs/tags/v0.6.0.tar.gz"
download QCBOR "https://github.com/laurencelundblade/QCBOR/archive/refs/tags/v1.5.1.tar.gz" || \
  download QCBOR "https://github.com/laurencelundblade/QCBOR/archive/refs/heads/master.tar.gz"
download libcbor "https://github.com/PJK/libcbor/archive/refs/tags/v0.11.0.tar.gz"
download nanopb "https://github.com/nanopb/nanopb/archive/refs/tags/0.4.9.tar.gz"
download zcbor "https://github.com/NordicSemiconductor/zcbor/archive/refs/heads/main.tar.gz"
download flatcc "https://github.com/dvidelabs/flatcc/archive/refs/tags/v0.6.1.tar.gz"
download protobuf-c "https://github.com/protobuf-c/protobuf-c/archive/refs/tags/v1.5.0.tar.gz"
download avro "https://github.com/apache/avro/archive/refs/tags/release-1.11.3.tar.gz"
download mongo-c-driver "https://github.com/mongodb/mongo-c-driver/archive/refs/tags/1.27.5.tar.gz"

echo "[build] jansson"
mkdir -p "$TP/_build/jansson"
cmake -S "$TP/jansson" -B "$TP/_build/jansson" -DCMAKE_BUILD_TYPE=Release \
  -DJANSSON_BUILD_DOCS=OFF -DJANSSON_WITHOUT_TESTS=ON -DCMAKE_INSTALL_PREFIX="$TP/_prefix"
cmake --build "$TP/_build/jansson" -j"$(nproc 2>/dev/null || echo 2)"
cmake --install "$TP/_build/jansson"

echo "[build] msgpack-c"
mkdir -p "$TP/_build/msgpack-c"
cmake -S "$TP/msgpack-c" -B "$TP/_build/msgpack-c" -DCMAKE_BUILD_TYPE=Release \
  -DMSGPACK_BUILD_EXAMPLES=OFF -DMSGPACK_BUILD_TESTS=OFF
cmake --build "$TP/_build/msgpack-c" -j"$(nproc 2>/dev/null || echo 2)"

echo "[build] libcbor"
rm -f "$TP/libcbor/src/cbor/configuration.h"
mkdir -p "$TP/_build/libcbor"
cmake -S "$TP/libcbor" -B "$TP/_build/libcbor" -DCMAKE_BUILD_TYPE=Release \
  -DWITH_TESTS=OFF -DWITH_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF
cmake --build "$TP/_build/libcbor" -j"$(nproc 2>/dev/null || echo 2)"

echo "[build] libbson"
rm -f "$TP/mongo-c-driver/src/libbson/src/bson/bson-config.h"
mkdir -p "$TP/_build/libbson"
cmake -S "$TP/mongo-c-driver" -B "$TP/_build/libbson" -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_MONGOC=OFF -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF \
  -DENABLE_HTML_DOCS=OFF -DENABLE_MAN_PAGES=OFF -DENABLE_UNINSTALL=OFF \
  -DENABLE_STATIC=ON -DENABLE_SHARED=OFF -DENABLE_SSL=OFF -DENABLE_SASL=OFF \
  -DENABLE_SRV=OFF -DENABLE_SNAPPY=OFF -DENABLE_ZLIB=OFF -DENABLE_ZSTD=OFF \
  -DCMAKE_C_FLAGS="-Wno-error"
cmake --build "$TP/_build/libbson" -j"$(nproc 2>/dev/null || echo 2)" --target bson_static

echo "[build] avro-c"
export PKG_CONFIG_PATH="$TP/_prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
mkdir -p "$TP/_build/avro-c"
cmake -S "$TP/avro/lang/c" -B "$TP/_build/avro-c" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$TP/_prefix"
cmake --build "$TP/_build/avro-c" -j"$(nproc 2>/dev/null || echo 2)" --target avro-static 2>/dev/null \
  || cmake --build "$TP/_build/avro-c" -j"$(nproc 2>/dev/null || echo 2)"

echo "[build] tinycbor prefixed"
mkdir -p "$TP/_build/tinycbor_pref"
cd "$TP/_build/tinycbor_pref"
rm -f *.o *.a redef.map
cc -O2 -c -I"$TP/tinycbor/src" \
  "$TP/tinycbor/src/cborencoder.c" \
  "$TP/tinycbor/src/cborencoder_close_container_checked.c" \
  "$TP/tinycbor/src/cborerrorstrings.c" \
  "$TP/tinycbor/src/cborparser.c" \
  "$TP/tinycbor/src/cborparser_dup_string.c" \
  "$TP/tinycbor/src/cborpretty.c"
> redef.map
for f in *.o; do nm "$f" | awk '/ [TDB] /{print $3}' | grep -E '^cbor_|^_cbor' || true; done | sort -u \
  | while read -r s; do echo "$s tc_$s" >> redef.map; done
for f in *.o; do objcopy --redefine-syms=redef.map "$f"; done
ar rcs libtinycbor_tc.a *.o

echo "[build] parson prefixed"
mkdir -p "$TP/_build/parson_pref"
cd "$TP/_build/parson_pref"
rm -f *.o *.a redef.map syms.txt
cc -O2 -c -I"$TP/parson" "$TP/parson/parson.c" -o parson.o
nm parson.o | awk '/ [TDB] /{print $3}' | grep -v '^_' > syms.txt
> redef.map
while read -r s; do [ -n "$s" ] && echo "$s parson_$s" >> redef.map; done < syms.txt
objcopy --redefine-syms=redef.map parson.o
ar rcs libparson_pref.a parson.o

# regenerate prefix headers used by the harness (pass paths via env; quoted heredoc)
TP="$TP" C_DIR="$C_DIR" python3 - <<'PY'
from pathlib import Path
import os

tp = Path(os.environ["TP"])
c_dir = Path(os.environ["C_DIR"])

# tinycbor
redef = (tp / "_build/tinycbor_pref/redef.map").read_text().splitlines()
lines = ["#ifndef TINYCBOR_PREF_H", "#define TINYCBOR_PREF_H"]
for line in redef:
    parts = line.split()
    if len(parts) == 2:
        lines.append(f"#define {parts[0]} {parts[1]}")
lines += ['#include "cbor.h"', "#endif"]
(c_dir / "src/tinycbor_pref.h").write_text("\n".join(lines) + "\n")

# parson
redef = (tp / "_build/parson_pref/redef.map").read_text().splitlines()
lines = ["#ifndef PARSON_PREF_H", "#define PARSON_PREF_H"]
for line in redef:
    parts = line.split()
    if len(parts) == 2:
        lines.append(f"#define {parts[0]} {parts[1]}")
lines += ['#include "parson.h"', "#endif"]
(c_dir / "src/parson_pref.h").write_text("\n".join(lines) + "\n")
print("prefix headers regenerated")
PY

echo "[SUCCESS] deps ready under $TP"
