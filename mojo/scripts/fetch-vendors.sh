#!/usr/bin/env bash
# Refresh vendored Mojo libraries and rewrite colliding package names.
# Prefers sibling checkouts next to this repo (…/GLD/gld-json, …) and
# falls back to a shallow git clone. Run from repo root or mojo/.
# Commits should keep vendor/{gldjson_src,cbor_src,pb_src,toml_src,yaml_src,msgpack_src,ehsanmok_src}.
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
    mkdir -p "$(dirname "$dest")"
    # Copy the tree the rewrite step needs. Skip heavy generated site/.
    if [[ -d "$SIBLING_ROOT/$name/src" ]]; then
      mkdir -p "$dest"
      cp -a "$SIBLING_ROOT/$name/src" "$dest/src"
      # pixi.toml is only used for a version stamp in docs; optional.
      [[ -f "$SIBLING_ROOT/$name/pixi.toml" ]] && cp -a "$SIBLING_ROOT/$name/pixi.toml" "$dest/"
    fi
    return 0
  fi
  echo "[INFO] cloning $url"
  # shellcheck disable=SC2086
  git clone --depth 1 $extra "$url" "$dest"
}

acquire gld-json "$tmp/gld-json" https://github.com/leo-gan/gld-json.git
acquire gld-cbor "$tmp/gld-cbor" https://github.com/leo-gan/gld-cbor.git
acquire gld-protobuf "$tmp/gld-protobuf" https://github.com/leo-gan/gld-protobuf.git
acquire gld-yaml "$tmp/gld-yaml" https://github.com/leo-gan/gld-yaml.git
acquire gld-messagepack "$tmp/gld-messagepack" https://github.com/leo-gan/gld-messagepack.git
# DataBooth TOML is not a leo-gan sibling; clone (or reuse a sibling if present).
if [[ -d "$SIBLING_ROOT/mojo-toml/src/toml" ]]; then
  echo "[INFO] using sibling $SIBLING_ROOT/mojo-toml"
  rm -rf "$tmp/mojo-toml"
  mkdir -p "$tmp/mojo-toml"
  cp -a "$SIBLING_ROOT/mojo-toml/src" "$tmp/mojo-toml/src"
elif [[ -d "$SIBLING_ROOT/gld-toml/src/toml" ]]; then
  echo "[INFO] using sibling $SIBLING_ROOT/gld-toml"
  rm -rf "$tmp/mojo-toml"
  mkdir -p "$tmp/mojo-toml"
  cp -a "$SIBLING_ROOT/gld-toml/src" "$tmp/mojo-toml/src"
else
  git clone --depth 1 https://github.com/DataBooth/mojo-toml.git "$tmp/mojo-toml"
fi
if [[ -d "$SIBLING_ROOT/ehsanmok-json/json" ]]; then
  echo "[INFO] using sibling $SIBLING_ROOT/ehsanmok-json"
  rm -rf "$tmp/ehsanmok-json"
  mkdir -p "$tmp/ehsanmok-json"
  cp -a "$SIBLING_ROOT/ehsanmok-json/json" "$tmp/ehsanmok-json/json"
else
  git clone --depth 1 --branch v0.3.1 https://github.com/ehsanmok/json.git "$tmp/ehsanmok-json"
fi

python3 - "$tmp" "$MOJO_DIR" <<'PY'
from pathlib import Path
import re
import shutil
import sys

src_root = Path(sys.argv[1])
mojo = Path(sys.argv[2])

def rewrite_tree(src: Path, dest: Path, mapping: dict[str, str]) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for item in src.iterdir():
        if item.name.startswith("."):
            continue
        target = dest / mapping.get(item.name, item.name)
        if item.is_dir():
            shutil.copytree(item, target)
        else:
            shutil.copy2(item, target)
    for path in dest.rglob("*.mojo"):
        text = path.read_text(encoding="utf-8")
        orig = text
        for old, new in mapping.items():
            if old == new:
                continue
            text = re.sub(rf"\bfrom {re.escape(old)}\b", f"from {new}", text)
            text = re.sub(rf"\bimport {re.escape(old)}\b", f"import {new}", text)
        if text != orig:
            path.write_text(text, encoding="utf-8")

rewrite_tree(
    src_root / "gld-json" / "src",
    mojo / "vendor" / "gldjson_src",
    {
        "runtime": "gldjson_runtime",
        "wire": "gldjson_wire",
        "schema": "gldjson_schema",
        "codegen": "gldjson_codegen",
        "json": "gldjson",
    },
)
rewrite_tree(
    src_root / "gld-cbor" / "src",
    mojo / "vendor" / "cbor_src",
    {
        "runtime": "cbor_runtime",
        "wire": "cbor_wire",
        "diag": "cbor_diag",
        "cddl": "cbor_cddl",
        "codegen": "cbor_codegen",
        "cbor": "cbor",
    },
)
rewrite_tree(
    src_root / "gld-protobuf" / "src",
    mojo / "vendor" / "pb_src",
    {
        "runtime": "pb_runtime",
        "wire": "pb_wire",
        "descriptor": "pb_descriptor",
        "codegen": "pb_codegen",
        "conformance_runner": "pb_conformance_runner",
        "protobuf": "protobuf",
    },
)
rewrite_tree(
    src_root / "gld-yaml" / "src",
    mojo / "vendor" / "yaml_src",
    {
        "runtime": "yaml_runtime",
        "wire": "yaml_wire",
        "schema": "yaml_schema",
        "codegen": "yaml_codegen",
        "yaml": "yaml",
    },
)
rewrite_tree(
    src_root / "gld-messagepack" / "src",
    mojo / "vendor" / "msgpack_src",
    {
        "runtime": "msgpack_runtime",
        "wire": "msgpack_wire",
        "schema": "msgpack_schema",
        "codegen": "msgpack_codegen",
        "msgpack": "msgpack",
    },
)
toml_dest = mojo / "vendor" / "toml_src" / "toml"
if toml_dest.exists():
    shutil.rmtree(toml_dest)
shutil.copytree(src_root / "mojo-toml" / "src" / "toml", toml_dest)
ej_dest = mojo / "vendor" / "ehsanmok_src" / "ehsanmok_json"
if ej_dest.exists():
    shutil.rmtree(ej_dest)
shutil.copytree(src_root / "ehsanmok-json" / "json", ej_dest)
# GPU path needs Modular `max`; this harness times the CPU parser only.
(ej_dest / "gpu" / "__init__.mojo").write_text(
    """# GPU backends require Modular `max`. This harness times the default
# CPU parser only, so the GPU symbols are stubs that raise if selected.

from ..types import JSONInput
from ..value import Value


def parse_json_gpu(input_obj: JSONInput) raises -> Int:
    raise Error("ehsanmok-json GPU target is not built in this harness")


def parse_json_gpu_from_pinned(input_obj: JSONInput) raises -> Int:
    raise Error("ehsanmok-json GPU target is not built in this harness")


def parse_gpu_to_value(s: String, result: Int) raises -> Value:
    raise Error("ehsanmok-json GPU target is not built in this harness")
""",
    encoding="utf-8",
)
print("vendors refreshed")
PY
