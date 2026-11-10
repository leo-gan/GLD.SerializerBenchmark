#!/usr/bin/env python3
"""Table-driven Mojo vendor tree rewriter for fetch-vendors.sh."""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

STD_PACKAGES = ("runtime", "wire", "schema", "codegen")

# (repo_name, dest_dir, prefix, prefixed_packages, extra_mapping)
GLD_SPECS: tuple[tuple[str, str, str, tuple[str, ...], dict[str, str]], ...] = (
    ("gld-json", "gldjson_src", "gldjson", STD_PACKAGES, {"json": "gldjson"}),
    (
        "gld-cbor",
        "cbor_src",
        "cbor",
        ("runtime", "wire", "diag", "cddl", "codegen"),
        {"cbor": "cbor"},
    ),
    (
        "gld-protobuf",
        "pb_src",
        "pb",
        ("runtime", "wire", "descriptor", "codegen", "conformance_runner"),
        {"protobuf": "protobuf"},
    ),
    ("gld-yaml", "yaml_src", "yaml", STD_PACKAGES, {"yaml": "yaml"}),
    ("gld-messagepack", "msgpack_src", "msgpack", STD_PACKAGES, {"msgpack": "msgpack"}),
    ("gld-bson", "bson_src", "bson", STD_PACKAGES, {"bson": "bson_lib"}),
    (
        "gld-avro",
        "avro_src",
        "avro",
        ("runtime", "wire", "schema", "json", "deflate", "codegen"),
        {"avro": "avro"},
    ),
    ("gld-ion", "ion_src", "ion", STD_PACKAGES, {"ion": "ion"}),
    ("gld-toml", "gldtoml_src", "gldtoml", STD_PACKAGES, {"toml": "gldtoml"}),
    ("gld-smile", "smile_src", "smile", STD_PACKAGES, {"smile": "smile"}),
    (
        "gld-arrow",
        "arrow_src",
        "arrow",
        (*STD_PACKAGES, "compress"),
        {"arrow": "arrow"},
    ),
    (
        "gld-parquet",
        "parquet_src",
        "parquet",
        (*STD_PACKAGES, "compress"),
        {"parquet": "parquet"},
    ),
    ("gld-hdf5", "hdf5_src", "hdf5", STD_PACKAGES, {"hdf5": "hdf5"}),
    ("gld-kiln", "kiln_src", "", (), {}),
    (
        "gld-flatbuffers",
        "fb_src",
        "fb",
        ("wire", "flex", "schema", "codegen"),
        {"flatbuffers": "flatbuffers"},
    ),
)

EHSANMOK_GPU_STUB = """# GPU backends require Modular `max`. This harness times the default
# CPU parser only, so the GPU symbols are stubs that raise if selected.

from ..types import JSONInput
from ..value import Value


def parse_json_gpu(input_obj: JSONInput) raises -> Int:
    raise Error("ehsanmok-json GPU target is not built in this harness")


def parse_json_gpu_from_pinned(input_obj: JSONInput) raises -> Int:
    raise Error("ehsanmok-json GPU target is not built in this harness")


def parse_gpu_to_value(s: String, result: Int) raises -> Value:
    raise Error("ehsanmok-json GPU target is not built in this harness")
"""

SMILE_OLD = (
    "    def _try_header(mut self) raises DecodeError -> Bool:\n"
    "        if self._remain() < 4:\n"
    "            return False\n"
)
SMILE_NEW = (
    "    def _try_header(mut self) raises DecodeError -> Bool:\n"
    "        if self._remain() < 4:\n"
    "            # 0x3A starts a header. Leaving those bytes unconsumed makes\n"
    "            # `_finish` call this again and never move forward.\n"
    "            if self._remain() > 0 and Int(self.raw[self.i]) == 0x3A:\n"
    "                raise DecodeError(DecodeError.KIND_EOF, self.i)\n"
    "            return False\n"
)


def build_mapping(
    prefix: str, prefixed: tuple[str, ...], extra: dict[str, str]
) -> dict[str, str]:
    mapping = {pkg: f"{prefix}_{pkg}" for pkg in prefixed}
    mapping.update(extra)
    return mapping


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


EHSANMOK_REFLECTION_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    ("from std.memory import UnsafeMaybeUninit", "from std.memory import MaybeUninit"),
    ("var slot = UnsafeMaybeUninit[E]()", "var slot = MaybeUninit[E]()"),
    ("var slot = UnsafeMaybeUninit[V]()", "var slot = MaybeUninit[V]()"),
    ("var slot = UnsafeMaybeUninit[T]()", "var slot = MaybeUninit[T]()"),
    (
        "            try:\n"
        "                _parse_into[E](r, Pointer(to=slot.unsafe_assume_init_ref()))\n"
        "            except e:\n"
        '                raise Error("element " + String(index) + ": " + String(e))\n'
        "            out.append(slot.unsafe_assume_init_take())",
        "            try:\n"
        "                _parse_into[E](r, Pointer(to=slot.unsafe_assume_init()))\n"
        "            except e:\n"
        "                slot^.unsafe_forget()\n"
        '                raise Error("element " + String(index) + ": " + String(e))\n'
        "            out.append(slot^.unsafe_assume_init())",
    ),
    (
        "        _parse_into[E](r, Pointer(to=slot.unsafe_assume_init_ref()))\n"
        "        var element = slot.unsafe_assume_init_take()",
        "        try:\n"
        "            _parse_into[E](r, Pointer(to=slot.unsafe_assume_init()))\n"
        "        except e:\n"
        "            slot^.unsafe_forget()\n"
        "            raise e\n"
        "        var element = slot^.unsafe_assume_init()",
    ),
    (
        "                try:\n"
        "                    _parse_into[V](r, Pointer(to=slot.unsafe_assume_init_ref()))\n"
        "                except e:\n"
        "                    raise Error(\"key '\" + name + \"': \" + String(e))\n"
        "                out[name] = slot.unsafe_assume_init_take()",
        "                try:\n"
        "                    _parse_into[V](r, Pointer(to=slot.unsafe_assume_init()))\n"
        "                except e:\n"
        "                    slot^.unsafe_forget()\n"
        "                    raise Error(\"key '\" + name + \"': \" + String(e))\n"
        "                out[name] = slot^.unsafe_assume_init()",
    ),
    (
        "    _parse_into[T](reader, Pointer(to=slot.unsafe_assume_init_ref()))\n"
        "    reader.expect_end()\n"
        "    return slot.unsafe_assume_init_take()",
        "    try:\n"
        "        _parse_into[T](reader, Pointer(to=slot.unsafe_assume_init()))\n"
        "        reader.expect_end()\n"
        "    except e:\n"
        "        slot^.unsafe_forget()\n"
        "        raise e\n"
        "    return slot^.unsafe_assume_init()",
    ),
)


def patch_ehsanmok_for_mojo_1_1(ej_dest: Path) -> None:
    """Apply Mojo 1.1 stdlib adaptations to ehsanmok-json v0.4.0."""
    for path in ej_dest.rglob("*.mojo"):
        text = path.read_text(encoding="utf-8")
        updated = text.replace("InlineArray", "Array")
        if updated != text:
            path.write_text(updated, encoding="utf-8")

    refl = ej_dest / "reflection.mojo"
    if refl.is_file():
        rtext = refl.read_text(encoding="utf-8")
        for old, new in EHSANMOK_REFLECTION_REPLACEMENTS:
            rtext = rtext.replace(old, new)
        refl.write_text(rtext, encoding="utf-8")

    val = ej_dest / "value" / "value.mojo"
    if val.is_file():
        vtext = val.read_text(encoding="utf-8")
        vtext = vtext.replace(
            "hasher.update(self.hash_u64())",
            "hasher._update_with_simd(self.hash_u64())",
        )
        val.write_text(vtext, encoding="utf-8")

    gpu_init = ej_dest / "gpu" / "__init__.mojo"
    gpu_init.parent.mkdir(parents=True, exist_ok=True)
    gpu_init.write_text(EHSANMOK_GPU_STUB, encoding="utf-8")


def refresh_vendors(src_root: Path, mojo_dir: Path) -> None:
    vendor_dir = mojo_dir / "vendor"
    for repo_name, dest_name, prefix, prefixed, extra in GLD_SPECS:
        mapping = build_mapping(prefix, prefixed, extra)
        rewrite_tree(src_root / repo_name / "src", vendor_dir / dest_name, mapping)

    toml_dest = vendor_dir / "toml_src" / "toml"
    if toml_dest.exists():
        shutil.rmtree(toml_dest)
    shutil.copytree(src_root / "mojo-toml" / "src" / "toml", toml_dest)

    ej_dest = vendor_dir / "ehsanmok_src" / "ehsanmok_json"
    if ej_dest.exists():
        shutil.rmtree(ej_dest)
    shutil.copytree(src_root / "ehsanmok-json" / "json", ej_dest)
    patch_ehsanmok_for_mojo_1_1(ej_dest)

    smile_codec = vendor_dir / "smile_src" / "smile_wire" / "codec.mojo"
    smile_text = smile_codec.read_text(encoding="utf-8")
    if SMILE_OLD in smile_text:
        smile_codec.write_text(
            smile_text.replace(SMILE_OLD, SMILE_NEW, 1), encoding="utf-8"
        )
    elif "never move forward" not in smile_text:
        raise SystemExit("smile short-header guard could not be applied")


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if len(args) != 2:
        raise SystemExit("Usage: vendor_rewrite.py <src_root> <mojo_dir>")
    refresh_vendors(Path(args[0]), Path(args[1]))
    print("vendors refreshed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
