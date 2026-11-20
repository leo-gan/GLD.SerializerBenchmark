#!/usr/bin/env python3
"""Unit tests for compliance catalog formatting and failure row deduplication."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO = SCRIPTS_DIR.parents[1]
for p in (SCRIPTS_DIR, REPO / "dashboard" / "scripts"):
    s = str(p)
    if s not in sys.path:
        sys.path.insert(0, s)

from catalog_io import dumps_compliance_catalog

import importlib.util

_SYNC_SPEC = importlib.util.spec_from_file_location(
    "sync_compliance", REPO / "dashboard" / "scripts" / "sync-compliance.py"
)
_SYNC_MOD = importlib.util.module_from_spec(_SYNC_SPEC)
assert _SYNC_SPEC and _SYNC_SPEC.loader
_SYNC_SPEC.loader.exec_module(_SYNC_MOD)
slim_failure_rows = _SYNC_MOD.slim_failure_rows
load_catalog_cases = _SYNC_MOD.load_catalog_cases
restore_case_sources = _SYNC_MOD.restore_case_sources


class CatalogIoTest(unittest.TestCase):
    def test_dumps_compliance_catalog_round_trips_and_inlines_cases(self) -> None:
        doc = {
            "format": "json",
            "standard": "RFC 8259",
            "version": "rfc8259",
            "standard_url": "https://www.rfc-editor.org/rfc/rfc8259",
            "cases": [
                {"id": "c1", "expect": "accept", "input": "{}"},
                {"id": "c2", "expect": "reject", "input": "{"},
            ],
        }
        text = dumps_compliance_catalog(doc)
        self.assertEqual(json.loads(text), doc)
        self.assertIn('{"id":"c1","expect":"accept","input":"{}"}', text)
        self.assertLessEqual(text.count("\n"), 12)

    def test_slim_failure_rows_deduplicates_case_metadata_and_strips_skips(self) -> None:
        rows = [
            {
                "outcome": "skip",
                "format": "json",
                "standard": "RFC 8259",
                "id": "s1",
                "title": "Skip me",
            },
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "version": "rfc8259",
                "version_key": "json.rfc8259",
                "standard_url": "https://www.rfc-editor.org/rfc/rfc8259",
                "id": "f1",
                "title": "Trailing comma",
                "section": "4",
                "expect": "reject",
                "input": "[1,]",
                "language": "python",
                "serializer": "json",
                "observed": "accepted",
                "detail": "accepted",
            },
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "version": "rfc8259",
                "version_key": "json.rfc8259",
                "standard_url": "https://www.rfc-editor.org/rfc/rfc8259",
                "id": "f1",
                "title": "Trailing comma",
                "section": "4",
                "expect": "reject",
                "input": "[1,]",
                "language": "rust",
                "serializer": "serde_json",
                "observed": "accepted",
            },
        ]
        slim = slim_failure_rows(rows)
        self.assertEqual(slim[0], {"outcome": "skip"})
        self.assertIn("title", slim[1])
        self.assertNotIn("detail", slim[1])
        self.assertNotIn("standard_url", slim[1])
        self.assertNotIn("title", slim[2])
        self.assertNotIn("section", slim[2])
        self.assertEqual(slim[2]["serializer"], "serde_json")

    def test_slim_keeps_source_from_a_later_row_when_the_first_omitted_it(self) -> None:
        rows = [
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "id": "jts-8259-n_number_minus_space_1",
                "title": "n number minus space 1",
                "input": "",
                "input_encoding": "utf-8",
                "language": "csharp",
                "serializer": "NetJSON",
                "observed": "accepted",
            },
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "id": "jts-8259-n_number_minus_space_1",
                "input": "[- 1]",
                "input_encoding": "utf-8",
                "language": "fortran",
                "serializer": "json-fortran",
                "observed": "accepted",
            },
        ]
        slim = slim_failure_rows(rows)
        self.assertEqual(slim[0]["input"], "[- 1]")
        self.assertEqual(slim[0]["serializer"], "NetJSON")
        self.assertNotIn("input", slim[1])
        self.assertEqual(slim[1]["outcome"], "fail")

    def test_restore_case_sources_fills_a_blank_fixture_and_keeps_a_recorded_one(self) -> None:
        catalog = {
            ("json", "RFC 8259", "blank"): {"input": "[- 1]", "input_encoding": "utf-8"},
            ("json", "RFC 8259", "kept"): {"input": "DIFFERENT", "input_encoding": "utf-8"},
            ("cbor", "RFC 8949", "hex"): {"input": "ff", "input_encoding": "hex"},
            ("toml", "TOML 1.1.0", "empty"): {"input": "", "input_encoding": "utf-8"},
        }
        rows = [
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "id": "blank",
                "input": "",
                "language": "csharp",
                "serializer": "NetJSON",
            },
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "id": "blank",
                "input": "[- 1]",
                "language": "fortran",
                "serializer": "json-fortran",
            },
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "id": "kept",
                "input": "[1]",
                "input_encoding": "utf-8",
                "language": "python",
                "serializer": "json",
            },
            {
                "outcome": "fail",
                "format": "cbor",
                "standard": "RFC 8949",
                "id": "hex",
                "input": "",
                "input_encoding": "",
                "language": "zig",
                "serializer": "zbor",
            },
            {
                "outcome": "fail",
                "format": "toml",
                "standard": "TOML 1.1.0",
                "id": "empty",
                "input": "",
                "language": "mojo",
                "serializer": "mojo-toml",
            },
        ]
        changed = restore_case_sources(rows, catalog)
        self.assertEqual(changed, 2)
        self.assertEqual(rows[0]["input"], "[- 1]")
        self.assertEqual(rows[0]["input_encoding"], "utf-8")
        # The later row still carries its own copy; slimming drops that repeat.
        self.assertEqual(rows[1]["input"], "[- 1]")
        self.assertEqual(rows[2]["input"], "[1]")
        self.assertEqual(rows[3]["input"], "ff")
        self.assertEqual(rows[3]["input_encoding"], "hex")
        self.assertEqual(rows[4]["input"], "")
        self.assertNotIn("input_encoding", rows[4])
        self.assertEqual(rows[0]["outcome"], "fail")

    def test_rfc8259_catalog_source_matches_the_json_test_suite_bytes(self) -> None:
        catalog = load_catalog_cases(REPO / "compliance" / "data")
        colon = catalog[("json", "RFC 8259", "jts-8259-n_array_colon_instead_of_comma")]
        minus = catalog[("json", "RFC 8259", "jts-8259-n_number_minus_space_1")]
        self.assertEqual(colon["input"], '["": 1]')
        self.assertEqual(minus["input"], "[- 1]")
        rows = [
            {
                "outcome": "fail",
                "format": "json",
                "standard": "RFC 8259",
                "id": "jts-8259-n_array_colon_instead_of_comma",
                "input": "",
                "input_encoding": "utf-8",
                "serializer": "NetJSON",
            }
        ]
        self.assertEqual(restore_case_sources(rows, catalog), 1)
        self.assertEqual(rows[0]["input"], '["": 1]')


if __name__ == "__main__":
    unittest.main()
