"""The combined experiment results.json is the saved language block."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

LIB = Path(__file__).resolve().parent
REPO = LIB.parents[1]
if str(LIB) not in sys.path:
    sys.path.insert(0, str(LIB))

from language_results import load_language_blocks, saved_language


def _write(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


class LanguageResultsTest(unittest.TestCase):
    def test_combined_file_is_the_saved_block(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            _write(
                folder / "results.json",
                {"languages": {"python": {"status": "ok", "rows": [1]}}},
            )
            self.assertEqual(
                load_language_blocks(folder),
                {"python": {"status": "ok", "rows": [1]}},
            )
            self.assertEqual(
                saved_language(folder, "python")["rows"],
                [1],
            )

    def test_side_file_is_only_a_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            _write(folder / "python" / "results.json", {"status": "ok", "rows": [7]})
            self.assertEqual(saved_language(folder, "python")["rows"], [7])
            _write(
                folder / "results.json",
                {"languages": {"python": {"status": "ok", "rows": [1]}}},
            )
            self.assertEqual(saved_language(folder, "python")["rows"], [1])

    def test_missing_language_is_none(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            self.assertIsNone(saved_language(Path(raw), "python"))


def _load_summarize():
    path = REPO / "experiments" / "01-json-library-bakeoff" / "summarize.py"
    spec = importlib.util.spec_from_file_location("summarize_exp01", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SummarizeKeepsCombinedFileTest(unittest.TestCase):
    def test_one_language_does_not_write_a_second_json_copy(self) -> None:
        mod = _load_summarize()
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            _write(
                folder / "results.json",
                {
                    "languages": {
                        "python": {"status": "ok", "language": "python", "rows": [1]},
                        "go": {"status": "ok", "language": "go", "rows": [2]},
                    }
                },
            )
            mod.HERE = folder
            mod._load_cfg = lambda path: {}
            mod.libraries_by_language = lambda cfg: {"python": {}, "go": {}}
            mod.summarize_language = lambda lang, csv, catalog, analysis: {
                "status": "ok",
                "language": lang,
                "rows": [9],
            }
            mod.write_language_markdown = lambda language, pack: f"# {language}\n"
            captured = {}

            def write_aggregate(cfg, languages):
                captured["languages"] = languages
                return folder / "results.json"

            mod.write_aggregate = write_aggregate
            rc = mod.main(["--language", "python", "--csv", str(folder / "unused.csv")])
            self.assertEqual(rc, 0)
            self.assertEqual(captured["languages"]["python"]["rows"], [9])
            self.assertEqual(captured["languages"]["go"]["rows"], [2])
            self.assertFalse((folder / "python" / "results.json").exists())
            self.assertTrue((folder / "python" / "results.md").is_file())

    def test_all_without_csv_keeps_the_combined_block(self) -> None:
        mod = _load_summarize()
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            _write(
                folder / "results.json",
                {"languages": {"python": {"status": "ok", "language": "python", "rows": [4]}}},
            )
            mod.HERE = folder
            mod._load_cfg = lambda path: {}
            mod.libraries_by_language = lambda cfg: {"python": {}, "go": {}}
            mod._latest_csv = lambda lang: None
            mod.write_language_markdown = lambda language, pack: f"# {language}\n"
            captured = {}
            mod.write_aggregate = lambda cfg, languages: captured.update(languages=languages) or folder / "results.json"
            rc = mod.main(["--all"])
            self.assertEqual(rc, 0)
            self.assertEqual(captured["languages"]["python"]["rows"], [4])
            self.assertEqual(captured["languages"]["go"]["status"], "missing")
            self.assertFalse((folder / "python" / "results.json").exists())
            self.assertFalse((folder / "go" / "results.json").exists())


if __name__ == "__main__":
    unittest.main()
