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


if __name__ == "__main__":
    unittest.main()
