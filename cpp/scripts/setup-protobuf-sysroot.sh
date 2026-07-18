#!/usr/bin/env bash
# Fetch matching Ubuntu jammy protobuf 3.12.4 debs into cpp/third_party/protobuf-sysroot
# (protoc + headers + static libs) without requiring root install.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYSROOT="$CPP_DIR/third_party/protobuf-sysroot"
CACHE="$CPP_DIR/third_party/_protobuf_debs"
VER="3.12.4-1ubuntu7.22.04.6"
MIRROR="${PROTOBUF_DEB_MIRROR:-http://us.archive.ubuntu.com/ubuntu/pool/main/p/protobuf}"

if [[ -x "$SYSROOT/usr/bin/protoc" && -f "$SYSROOT/usr/include/google/protobuf/message.h" && -f "$SYSROOT/usr/lib/x86_64-linux-gnu/libprotobuf.a" ]]; then
  echo "[skip] protobuf sysroot already present at $SYSROOT"
  "$SYSROOT/usr/bin/protoc" --version 2>/dev/null || \
    LD_LIBRARY_PATH="$SYSROOT/usr/lib/x86_64-linux-gnu" "$SYSROOT/usr/bin/protoc" --version
  exit 0
fi

mkdir -p "$CACHE" "$SYSROOT"
debs=(
  "libprotobuf23_${VER}_amd64.deb"
  "libprotoc23_${VER}_amd64.deb"
  "protobuf-compiler_${VER}_amd64.deb"
  "libprotobuf-dev_${VER}_amd64.deb"
  "libprotoc-dev_${VER}_amd64.deb"
)

for deb in "${debs[@]}"; do
  if [[ ! -f "$CACHE/$deb" ]]; then
    echo "[get] $deb"
    curl -fsSL -o "$CACHE/$deb" "$MIRROR/$deb"
  else
    echo "[have] $deb"
  fi
  dpkg-deb -x "$CACHE/$deb" "$SYSROOT"
done

# Convenience pkg-config for local builds (optional)
PC="$SYSROOT/usr/lib/x86_64-linux-gnu/pkgconfig"
mkdir -p "$PC"
cat > "$PC/protobuf.pc" <<EOF
prefix=$SYSROOT/usr
libdir=$SYSROOT/usr/lib/x86_64-linux-gnu
includedir=\${prefix}/include
Name: Protocol Buffers
Description: Google's Data Interchange Format (suite sysroot)
Version: 3.12.4
Libs: -L\${libdir} -lprotobuf -pthread
Cflags: -I\${includedir}
EOF

export LD_LIBRARY_PATH="$SYSROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "[OK] protobuf sysroot ready: $($SYSROOT/usr/bin/protoc --version)"
