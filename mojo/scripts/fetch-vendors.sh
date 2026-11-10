#!/usr/bin/env bash
# Refresh vendored Mojo libraries and rewrite colliding package names.
# Prefers sibling checkouts next to this repo (…/GLD/gld-json, …) and
# falls back to a shallow git clone. Run from repo root or mojo/.
set -euo pipefail
MOJO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MOJO_DIR"
mkdir -p vendor
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SIBLING_ROOT="${GLD_SIBLING_ROOT:-$(cd "$MOJO_DIR/../.." && pwd)}"

acquire() {
  local name="$1"
  local dest="$2"
  local url="$3"
  local extra="${4:-}"
  if [[ -d "$SIBLING_ROOT/$name/src" ]]; then
    echo "[INFO] using sibling $SIBLING_ROOT/$name"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$SIBLING_ROOT/$name/src" "$dest/src"
    [[ -f "$SIBLING_ROOT/$name/pixi.toml" ]] && cp -a "$SIBLING_ROOT/$name/pixi.toml" "$dest/"
    return 0
  fi
  echo "[INFO] cloning $url"
  # shellcheck disable=SC2086
  git clone --depth 1 $extra "$url" "$dest"
}

for pkg in \
  gld-json gld-cbor gld-protobuf gld-yaml gld-messagepack \
  gld-flatbuffers gld-avro gld-bson gld-ion gld-smile \
  gld-toml gld-arrow gld-parquet gld-hdf5 gld-kiln; do
  acquire "$pkg" "$tmp/$pkg" "https://github.com/leo-gan/${pkg}.git"
done

# DataBooth/mojo-toml keeps the `toml` package. gld-toml is vendored separately.
if [[ -d "$SIBLING_ROOT/mojo-toml/src/toml" ]]; then
  echo "[INFO] using sibling $SIBLING_ROOT/mojo-toml"
  rm -rf "$tmp/mojo-toml"
  mkdir -p "$tmp/mojo-toml"
  cp -a "$SIBLING_ROOT/mojo-toml/src" "$tmp/mojo-toml/src"
else
  git clone --depth 1 https://github.com/DataBooth/mojo-toml.git "$tmp/mojo-toml"
fi

if [[ -d "$SIBLING_ROOT/ehsanmok-json/json" ]]; then
  echo "[INFO] using sibling $SIBLING_ROOT/ehsanmok-json"
  rm -rf "$tmp/ehsanmok-json"
  mkdir -p "$tmp/ehsanmok-json"
  cp -a "$SIBLING_ROOT/ehsanmok-json/json" "$tmp/ehsanmok-json/json"
else
  git clone --depth 1 --branch v0.4.0 https://github.com/ehsanmok/json.git "$tmp/ehsanmok-json"
fi

python3 "$MOJO_DIR/scripts/vendor_rewrite.py" "$tmp" "$MOJO_DIR"
