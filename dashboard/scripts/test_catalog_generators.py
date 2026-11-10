#!/usr/bin/env python3
"""Unit tests for separated catalog data and serializer-sources generation."""

from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO = SCRIPTS_DIR.parents[1]


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class CatalogGeneratorsTest(unittest.TestCase):
    def test_compliance_catalog_loads_from_json(self) -> None:
        wcc = _load("wcc", SCRIPTS_DIR / "write-compliance-catalog.py")
        self.assertGreaterEqual(len(wcc.CATALOG), 400)
        seen = set()
        for lang, name, formats, docs, evidence in wcc.CATALOG:
            self.assertNotIn((lang, name), seen)
            seen.add((lang, name))
            self.assertIsInstance(formats, list)
            self.assertTrue(docs.startswith("http"))
            self.assertTrue(evidence)

    def test_serializer_sources_loads_specifics_and_formats_compact_rows(self) -> None:
        wss = _load("wss", SCRIPTS_DIR / "write-serializer-sources.py")
        self.assertGreater(len(wss.URL_OVERRIDE), 100)
        self.assertGreater(len(wss.SPECIFICS), 200)
        sample = {
            "version": 1,
            "description": "test",
            "languages": {
                "python": {
                    "orjson": {
                        "source_url": "https://github.com/ijl/orjson",
                        "version": "3.11.6",
                        "specifics": "Fast JSON.",
                    }
                }
            },
        }
        text = wss.dumps_serializer_sources(sample)
        self.assertEqual(json.loads(text), sample)
        self.assertIn(
            '"orjson": {"source_url":"https://github.com/ijl/orjson","version":"3.11.6","specifics":"Fast JSON."}',
            text,
        )
        self.assertTrue((REPO / "dashboard/public/data/serializer-sources.json").is_symlink())


if __name__ == "__main__":
    unittest.main()
