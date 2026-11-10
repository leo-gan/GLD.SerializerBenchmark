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


class ConsolidatedExperimentScriptsTest(unittest.TestCase):
    def test_all_15_summarize_wrappers_render_combined_and_language_markdown(self) -> None:
        exp_dirs = sorted( (REPO / "experiments").glob("[0-9][0-9]-*") )
        self.assertEqual(len(exp_dirs), 15)
        for exp_dir in exp_dirs:
            spec = importlib.util.spec_from_file_location(
                f"summarize_{exp_dir.name}", exp_dir / "summarize.py"
            )
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            cfg = mod._load_cfg()
            saved = load_language_blocks(exp_dir)
            self.assertTrue(saved, f"expected saved languages in {exp_dir.name}")
            comb_md = mod.write_combined_markdown(cfg, saved)
            self.assertIn(cfg["question"], comb_md)
            payload = mod.experiment_payload(cfg, saved)
            self.assertEqual(payload["experiment_id"], cfg["id"])
            for lang, pack in saved.items():
                lang_md = mod.write_language_markdown(lang, pack)
                self.assertIn(f"— {lang}", lang_md)

    def test_save_sample_shared_module_matches_saved_sample_json(self) -> None:
        for extra in (REPO / "python" / "src", REPO / "analysis" / "src"):
            s = str(extra)
            if s not in sys.path:
                sys.path.insert(0, s)
        exp_dir = REPO / "experiments" / "01-json-library-bakeoff"
        spec = importlib.util.spec_from_file_location(
            "save_sample_01", exp_dir / "python" / "save_sample.py"
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        before = (exp_dir / "sample.json").read_text(encoding="utf-8")
        self.assertEqual(mod.main([]), 0)
        after = (exp_dir / "sample.json").read_text(encoding="utf-8")
        self.assertEqual(before, after)

    def test_all_14_run_sh_wrappers_delegate_to_run_experiment_sh(self) -> None:
        exp_dirs = sorted((REPO / "experiments").glob("[0-9][0-9]-*"))
        delegating = [
            d for d in exp_dirs if d.name != "15-fortran-ffi-tax"
        ]
        self.assertEqual(len(delegating), 14)
        for d in delegating:
            text = (d / "run.sh").read_text(encoding="utf-8")
            self.assertIn("run_experiment.sh", text)


if __name__ == "__main__":
    unittest.main()
