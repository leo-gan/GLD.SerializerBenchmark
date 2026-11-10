#!/usr/bin/env python3
"""Unit tests for compliance/scripts/merge_parts.py."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from merge_parts import merge_part_files, record_mojo_timeout, split_mojo_catalogs


class MergePartsTest(unittest.TestCase):
    def test_merge_part_files_counts_and_aggregates(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pdir = Path(tmp) / "parts"
            pdir.mkdir()
            (pdir / "a.json").write_text(
                json.dumps(
                    {
                        "results": [
                            {"id": "1", "format": "json", "serializer": "s1", "outcome": "pass"},
                            {"id": "2", "format": "json", "serializer": "s1", "outcome": "fail"},
                        ],
                        "serializer_errors": ["e1"],
                    }
                ),
                encoding="utf-8",
            )
            (pdir / "b.json").write_text(
                json.dumps(
                    {
                        "results": [
                            {"id": "3", "format": "yaml", "serializer": "s2", "outcome": "skip"},
                            {"id": "4", "format": "yaml", "serializer": "s2", "outcome": "error"},
                        ]
                    }
                ),
                encoding="utf-8",
            )
            out = Path(tmp) / "merged.json"
            doc = merge_part_files(pdir, out, "csharp")
            self.assertEqual(doc["language"], "csharp")
            self.assertEqual(doc["passed"], 1)
            self.assertEqual(doc["failed"], 1)
            self.assertEqual(doc["skipped"], 1)
            self.assertEqual(doc["errors"], 1)
            self.assertEqual(doc["scope"]["formats"], ["json", "yaml"])
            self.assertEqual(doc["serializer_errors"], ["e1"])
            self.assertEqual(json.loads(out.read_text(encoding="utf-8"))["passed"], 1)

    def test_split_mojo_catalogs_and_timeout_mojo(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            data = Path(tmp) / "data"
            (data / "toml").mkdir(parents=True)
            (data / "json").mkdir(parents=True)
            (data / "kiln").mkdir(parents=True)
            (data / "toml" / "v1.json").write_text(
                json.dumps(
                    {
                        "format": "toml",
                        "standard": "TOML",
                        "version": "1.0",
                        "cases": [{"id": f"t{i}"} for i in range(6)],
                    }
                ),
                encoding="utf-8",
            )
            (data / "json" / "rfc8259.json").write_text(
                json.dumps({"format": "json", "cases": [{"id": "j1"}]}),
                encoding="utf-8",
            )
            (data / "kiln" / "v2.json").write_text(
                json.dumps({"format": "kiln", "cases": [{"id": "k1"}]}),
                encoding="utf-8",
            )
            dest = Path(tmp) / "dest"
            n = split_mojo_catalogs(data, dest)
            self.assertEqual(n, 3)
            self.assertTrue((dest / "toml-v1-0000.json").is_file())
            self.assertTrue((dest / "toml-v1-0004.json").is_file())
            self.assertTrue((dest / "json-rfc8259.json").is_file())

            standards = Path(tmp) / "standards.json"
            standards.write_text(
                json.dumps({"languages": {"mojo": {"mojo-toml": ["toml"], "gld-toml": ["toml"]}}}),
                encoding="utf-8",
            )
            tout = Path(tmp) / "timeout-out.json"
            rows = record_mojo_timeout(dest / "toml-v1-0004.json", tout, standards)
            self.assertEqual(len(rows), 4)
            self.assertTrue(all(r["outcome"] == "error" and r["observed"] == "timeout" for r in rows))


if __name__ == "__main__":
    unittest.main()
