"""RFC scoring for the JSON compliance catalogs.

JSONTestSuite names a file i_ when parsers disagree. The catalog scores
that file from the cited RFC. expect any means both outcomes conform.
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from import_official import i_case_kind, jts_case_fields
from write_corpus import json_8259_lone_surrogate, json_u_escape_cases

DATA = Path(__file__).resolve().parents[1] / "data" / "json"
URLS = {
    "4627": "https://www.rfc-editor.org/rfc/rfc4627",
    "7159": "https://www.rfc-editor.org/rfc/rfc7159",
    "8259": "https://www.rfc-editor.org/rfc/rfc8259",
}
PREFIX = {"4627": "json-4627", "7159": "json-7159", "8259": "json-8259"}
META_KEYS = (
    "section",
    "section_title",
    "section_url",
    "paragraph",
    "requirement",
    "expect",
    "notes",
)


def _load(rfc: str) -> dict:
    return json.loads((DATA / f"rfc{rfc}.json").read_text(encoding="utf-8"))


def _raw(case: dict) -> bytes:
    if case.get("input_encoding") == "hex":
        return bytes.fromhex(case["input"])
    return case["input"].encode("utf-8")


class JsonRfcCasesTest(unittest.TestCase):
    def test_every_vendored_i_file_is_classified(self) -> None:
        for rfc in URLS:
            for case in _load(rfc)["cases"]:
                stem = case["id"].removeprefix(f"jts-{rfc}-")
                if not stem.startswith("i_"):
                    continue
                self.assertNotEqual(i_case_kind(stem), "", case["id"])

    def test_utf8_surrogate_bytes_are_not_an_unpaired_escape(self) -> None:
        self.assertEqual(i_case_kind("i_string_UTF8_surrogate_U+D800"), "ill-formed-utf8")
        rejected = jts_case_fields("i_string_UTF8_surrogate_U+D800", b"", "8259")
        self.assertEqual(rejected["expect"], "reject")
        self.assertEqual(rejected["section"], "8.1")

    def test_generator_matches_the_three_catalogs(self) -> None:
        for rfc in URLS:
            doc = _load(rfc)
            for case in doc["cases"]:
                prefix = f"jts-{rfc}-"
                if not case["id"].startswith(prefix):
                    continue
                stem = case["id"][len(prefix) :]
                fields = jts_case_fields(stem, _raw(case), rfc)
                for key in META_KEYS:
                    self.assertEqual(case[key], fields[key], f"{case['id']} {key}")

    def test_8259_utf16_rejects_and_earlier_rfcs_accept(self) -> None:
        raw = bytes.fromhex("5b002200e90022005d00")
        self.assertEqual(
            jts_case_fields("i_string_utf16LE_no_BOM", raw, "8259")["expect"],
            "reject",
        )
        self.assertEqual(
            jts_case_fields("i_string_utf16LE_no_BOM", raw, "7159")["expect"],
            "accept",
        )
        self.assertEqual(
            jts_case_fields("i_string_utf16LE_no_BOM", raw, "4627")["expect"],
            "accept",
        )

    def test_number_and_surrogate_latitude_is_unscored(self) -> None:
        number = jts_case_fields(
            "i_number_too_big_pos_int",
            b"[100000000000000000000]",
            "8259",
        )
        self.assertEqual(number["expect"], "any")
        self.assertEqual(number["requirement"], "MAY")
        self.assertIn("limits on the range and precision", number["paragraph"])
        self.assertIn("Neither outcome is preferred", number["notes"])

        surrogate = jts_case_fields(
            "i_string_invalid_lonely_surrogate",
            '["\\ud800"]'.encode(),
            "8259",
        )
        self.assertEqual(surrogate["expect"], "any")
        self.assertEqual(surrogate["requirement"], "MAY")
        self.assertEqual(surrogate["section"], "8.2")
        self.assertIn("unpredictable", surrogate["paragraph"])

        duplicate = jts_case_fields(
            "y_object_duplicated_key",
            b'{"a":"b","a":"c"}',
            "8259",
        )
        self.assertEqual(duplicate["expect"], "any")
        self.assertEqual(duplicate["requirement"], "SHOULD")

    def test_u_escape_cases_are_must_not(self) -> None:
        for rfc, url in URLS.items():
            wanted = {case["id"]: case for case in json_u_escape_cases(PREFIX[rfc], url)}
            found = {case["id"]: case for case in _load(rfc)["cases"]}
            for case_id, expected in wanted.items():
                self.assertIn(case_id, found)
                got = found[case_id]
                self.assertEqual(got["expect"], "reject", case_id)
                self.assertEqual(got["requirement"], "MUST NOT", case_id)
                self.assertEqual(got["input"], expected["input"], case_id)
                self.assertEqual(got["paragraph"], expected["paragraph"], case_id)

    def test_lone_surrogate_matches_the_writer(self) -> None:
        expected = json_8259_lone_surrogate(URLS["8259"])
        found = next(
            case for case in _load("8259")["cases"] if case["id"] == "json-8259-lone-surrogate"
        )
        self.assertEqual(found, expected)
        self.assertEqual(found["expect"], "any")
        self.assertNotEqual(found["requirement"], "SHOULD NOT")

    def test_short_u_escape_inputs_are_the_reported_shapes(self) -> None:
        cases = {case["id"]: case for case in json_u_escape_cases("json-8259", URLS["8259"])}
        self.assertEqual(cases["json-8259-u-escape-short"]["input"], '"\\u123')
        self.assertEqual(cases["json-8259-u-escape-short-before-quote"]["input"], '["\\u123"]')
        self.assertEqual(
            cases["json-8259-u-escape-fullwidth-digit"]["input"],
            '["\\u1\uff1234"]',
        )
        self.assertEqual(
            cases["json-8259-u-escape-low-byte-hex"]["input"],
            '["\\u1\u204234"]',
        )
        self.assertEqual(
            cases["json-8259-u-escape-unicode-digit-low-byte"]["input"],
            '["\\u1\u066134"]',
        )


if __name__ == "__main__":
    unittest.main()
