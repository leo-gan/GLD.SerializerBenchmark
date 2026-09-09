#!/usr/bin/env bash
# Refresh vendored Mojo libraries and rewrite colliding package names.
# Run from repo root or mojo/. Commits should keep vendor/{gldjson_src,cbor_src,pb_src,toml_src}.
set -euo pipefail
MOJO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MOJO_DIR"
mkdir -p vendor
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git clone --depth 1 https://github.com/leo-gan/gld-json.git "$tmp/gld-json"
git clone --depth 1 https://github.com/leo-gan/gld-cbor.git "$tmp/gld-cbor"
git clone --depth 1 https://github.com/leo-gan/gld-protobuf.git "$tmp/gld-protobuf"
git clone --depth 1 https://github.com/DataBooth/mojo-toml.git "$tmp/mojo-toml"
git clone --depth 1 --branch v0.3.0 https://github.com/ehsanmok/json.git "$tmp/ehsanmok-json"

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
