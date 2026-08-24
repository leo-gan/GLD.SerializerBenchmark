"""Display number formatting for unpublished language report Summary / pivot tables."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark_analysis.reports import _format_in_unit, _format_sig  # noqa: E402


class TestFormatSig(unittest.TestCase):
    def test_fixed_point_cases(self):
        cases = [
            (0, "0"),
            (0.42, "0.42"),
            (1.17, "1.17"),
            (18.4, "18.4"),
            (150, "150"),
            (579, "579"),
            (1165.5, "1,170"),  # was 1.17e+03 with :.3g
            (1170, "1,170"),
            (1230, "1,230"),
            (1620, "1,620"),
            (4520, "4,520"),
            (3840, "3,840"),
            (18400, "18,400"),
            (0.581, "0.581"),
            (1_000_000, "1,000,000"),
            (-2410, "-2,410"),
        ]
        for val, want in cases:
            with self.subTest(val=val):
                self.assertEqual(_format_sig(val, sig=3), want)

    def test_never_scientific(self):
        for exp in range(-4, 9):
            for mant in (1.0, 1.17, 2.41, 9.99):
                v = mant * (10**exp)
                s = _format_sig(v, sig=3)
                self.assertNotRegex(s, r"(?i)\d\.?\d*e[+-]?\d+", msg=f"{v} -> {s}")

    def test_format_in_unit(self):
        self.assertEqual(_format_in_unit(18400, 1000.0, "K", sig=3), "18.4K")
        self.assertEqual(_format_in_unit(1_170_000, 1_000_000.0, "M", sig=3), "1.17M")
        # unscaled large values get thousands separators
        self.assertEqual(_format_in_unit(2_320_000, 1.0, "", sig=3), "2,320,000")
        self.assertNotRegex(
            _format_in_unit(2_320_000, 1.0, "", sig=3),
            r"(?i)\d\.?\d*e[+-]?\d+",
        )

    def test_summary_us_path(self):
        for ns, want in (
            (579_000, "579"),
            (1_170_000, "1,170"),
            (1_680_000, "1,680"),
            (2_320_000, "2,320"),
            (2_410_000, "2,410"),
            (3_840_000, "3,840"),
            (4_520_000, "4,520"),
        ):
            text = _format_sig(ns / 1000.0, sig=3)
            self.assertEqual(text, want)


if __name__ == "__main__":
    unittest.main()
