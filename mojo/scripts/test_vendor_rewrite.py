#!/usr/bin/env python3
"""Unit tests for Mojo vendor tree rewriting."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from vendor_rewrite import GLD_SPECS, SMILE_OLD, build_mapping, refresh_vendors, rewrite_tree


class VendorRewriteTest(unittest.TestCase):
    def test_gld_specs_cover_all_15_gld_libraries(self) -> None:
        self.assertEqual(len(GLD_SPECS), 15)
        dest_names = {spec[1] for spec in GLD_SPECS}
        self.assertIn("gldjson_src", dest_names)
        self.assertIn("smile_src", dest_names)
        self.assertIn("kiln_src", dest_names)

    def test_rewrite_tree_renames_packages_and_imports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_str:
            tmp = Path(tmp_str)
            src = tmp / "src"
            (src / "runtime").mkdir(parents=True)
            (src / "json").mkdir(parents=True)
            (src / "json" / "parser.mojo").write_text(
                "from runtime.buf import Buffer\nimport json.types\n",
                encoding="utf-8",
            )
            dest = tmp / "out"
            mapping = build_mapping(
                "gldjson", ("runtime", "wire", "schema", "codegen"), {"json": "gldjson"}
            )
            rewrite_tree(src, dest, mapping)
            self.assertTrue((dest / "gldjson_runtime").is_dir())
            rewritten = (dest / "gldjson" / "parser.mojo").read_text(encoding="utf-8")
            self.assertIn("from gldjson_runtime.buf import Buffer", rewritten)
            self.assertIn("import gldjson.types", rewritten)

    def test_refresh_vendors_applies_ehsanmok_and_smile_patches(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_str:
            tmp = Path(tmp_str)
            src_root = tmp / "src_root"
            mojo_dir = tmp / "mojo"
            for repo_name, _, _, _, _ in GLD_SPECS:
                (src_root / repo_name / "src").mkdir(parents=True)
            smile_wire = src_root / "gld-smile" / "src" / "wire"
            smile_wire.mkdir(parents=True)
            (smile_wire / "codec.mojo").write_text(SMILE_OLD, encoding="utf-8")
            (src_root / "mojo-toml" / "src" / "toml").mkdir(parents=True)
            (src_root / "ehsanmok-json" / "json" / "gpu").mkdir(parents=True)
            (src_root / "ehsanmok-json" / "json" / "value").mkdir(parents=True)
            (src_root / "ehsanmok-json" / "json" / "arr.mojo").write_text(
                "alias A = InlineArray[UInt8, 4]\n", encoding="utf-8"
            )
            (src_root / "ehsanmok-json" / "json" / "reflection.mojo").write_text(
                "from std.memory import UnsafeMaybeUninit\n"
                "        var slot = UnsafeMaybeUninit[E]()\n"
                "        _parse_into[E](r, Pointer(to=slot.unsafe_assume_init_ref()))\n"
                "        var element = slot.unsafe_assume_init_take()\n",
                encoding="utf-8",
            )
            (src_root / "ehsanmok-json" / "json" / "value" / "value.mojo").write_text(
                "        hasher.update(self.hash_u64())\n",
                encoding="utf-8",
            )

            refresh_vendors(src_root, mojo_dir)
            arr_text = (
                mojo_dir / "vendor" / "ehsanmok_src" / "ehsanmok_json" / "arr.mojo"
            ).read_text(encoding="utf-8")
            self.assertIn("Array[UInt8, 4]", arr_text)
            self.assertNotIn("InlineArray", arr_text)
            refl_text = (
                mojo_dir / "vendor" / "ehsanmok_src" / "ehsanmok_json" / "reflection.mojo"
            ).read_text(encoding="utf-8")
            self.assertIn("from std.memory import MaybeUninit", refl_text)
            self.assertIn("slot^.unsafe_assume_init()", refl_text)
            val_text = (
                mojo_dir / "vendor" / "ehsanmok_src" / "ehsanmok_json" / "value" / "value.mojo"
            ).read_text(encoding="utf-8")
            self.assertIn("hasher._update_with_simd(self.hash_u64())", val_text)
            smile_out = (
                mojo_dir / "vendor" / "smile_src" / "smile_wire" / "codec.mojo"
            ).read_text(encoding="utf-8")
            self.assertIn("never move forward", smile_out)


if __name__ == "__main__":
    unittest.main()
