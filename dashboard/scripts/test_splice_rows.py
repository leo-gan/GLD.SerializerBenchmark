"""Splice scripts share one reading of a row's type id and its numbers."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from splice_rows import as_whole, base_type, count_bases, error_row_count, export_stats, require_finite


class SpliceRowsTest(unittest.TestCase):
    def test_type_id_stops_at_the_batch_suffix(self) -> None:
        self.assertEqual(base_type("message@n=100"), "message")
        self.assertEqual(base_type("message@n=1@n=100"), "message")
        self.assertEqual(base_type(None), "")

    def test_whole_float_becomes_an_int(self) -> None:
        self.assertEqual(as_whole(1.0), 1)
        self.assertIsInstance(as_whole(1.0), int)
        self.assertEqual(as_whole(1.5), 1.5)
        self.assertEqual(as_whole("1"), "1")

    def test_non_finite_is_rejected(self) -> None:
        require_finite({"metrics": [1.0, {"ok": 2}]}, "group")
        with self.assertRaises(SystemExit):
            require_finite({"metrics": float("nan")}, "group")

    def test_error_rows_ignore_the_header(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            csv_path = folder / "run.csv"
            csv_path.write_text("a\n", encoding="utf-8")
            self.assertEqual(error_row_count(csv_path), 0)
            err = folder / "run.errors.csv"
            err.write_text("col\n", encoding="utf-8")
            self.assertEqual(error_row_count(csv_path), 0)
            err.write_text("col\nbad\n", encoding="utf-8")
            self.assertEqual(error_row_count(csv_path), 1)

    def test_count_bases_ignores_other_types(self) -> None:
        groups = [
            {"test_data": "message@n=100"},
            {"test_data": "message"},
            {"test_data": "graph"},
        ]
        self.assertEqual(count_bases(groups, ("message", "document")), {"message": 2, "document": 0})


class ExportStatsTest(unittest.TestCase):
    def test_wrong_schema_is_rejected_and_a_good_one_is_returned(self) -> None:
        import splice_rows
        import types

        calls = {}

        def load_stats_config():
            return {"ok": True}

        def compute_statistics_multi_policy(records, config, language_hint):
            calls["records"] = records
            calls["config"] = config
            calls["language"] = language_hint
            return {"all": {}}

        def build_stats_export_payload(by_policy, language):
            calls["built_for"] = language
            calls["policies"] = by_policy
            return calls["payload"]

        fake = types.ModuleType("benchmark_analysis.stats")
        fake.load_stats_config = load_stats_config
        fake.compute_statistics_multi_policy = compute_statistics_multi_policy
        fake.build_stats_export_payload = build_stats_export_payload
        parent = types.ModuleType("benchmark_analysis")
        parent.stats = fake
        import sys
        saved = {
            name: sys.modules.get(name)
            for name in ("benchmark_analysis", "benchmark_analysis.stats")
        }
        sys.modules["benchmark_analysis"] = parent
        sys.modules["benchmark_analysis.stats"] = fake
        try:
            calls["payload"] = {"schema_version": "9"}
            with self.assertRaises(SystemExit):
                export_stats([{"row": 1}], "python")
            calls["payload"] = {"schema_version": "2.2", "groups": []}
            fresh = export_stats([{"row": 1}], "python")
        finally:
            for name, module in saved.items():
                if module is None:
                    sys.modules.pop(name, None)
                else:
                    sys.modules[name] = module
        self.assertEqual(fresh["schema_version"], "2.2")
        self.assertEqual(calls["language"], "python")
        self.assertEqual(calls["records"], [{"row": 1}])
        self.assertEqual(calls["built_for"], "python")


if __name__ == "__main__":
    unittest.main()
