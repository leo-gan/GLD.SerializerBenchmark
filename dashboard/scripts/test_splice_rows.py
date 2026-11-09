"""Splice scripts share one reading of a row's type id and its numbers."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from splice_rows import as_whole, base_type, count_bases, error_row_count, require_finite


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


if __name__ == "__main__":
    unittest.main()
