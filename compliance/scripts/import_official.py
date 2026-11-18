#!/usr/bin/env python3
"""Import OSI-licensed official suites into compliance/data/.

Reads local clones (default /tmp/compliance-suites) and writes catalog JSON.
Does not fetch the network. Re-run after refreshing those clones.

Sources (see compliance/LEGAL.md and compliance/vendor/):
  nst/JSONTestSuite              MIT
  yaml/yaml-test-suite           MIT
  toml-lang/toml-test            MIT
  kawanet/msgpack-test-suite     MIT
  cbor-wg/cbor-test-vectors      BSD-2-Clause
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
VENDOR = ROOT / "vendor"
SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/compliance-suites")


from catalog_io import dump_catalog


def _dump(rel: str, doc: dict) -> None:
    dump_catalog(rel, doc, ensure_ascii=True)


def _load_existing(rel: str) -> list[dict]:
    path = DATA / rel
    if not path.is_file():
        return []
    return list(json.loads(path.read_text(encoding="utf-8")).get("cases") or [])


def _merge(official: list[dict], extras: list[dict]) -> list[dict]:
    seen = {c["id"] for c in official}
    out = list(official)
    for item in extras:
        if item["id"] not in seen:
            out.append(item)
            seen.add(item["id"])
    return out


def _bytes_to_input(raw: bytes) -> tuple[str, str]:
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.hex(), "hex"


# JSONTestSuite marks these y_ (must accept). RFC 4627 §2.2, RFC 7159 §4, and
# RFC 8259 §4 only say member names SHOULD be unique, and that behavior is
# unpredictable when they are not. Score them implementation-defined.
_DUP_OBJECT_STEMS = frozenset(
    {
        "y_object_duplicated_key",
        "y_object_duplicated_key_and_value",
    }
)

_DUP_PARAGRAPH = (
    "The names within an object SHOULD be unique. When they are not, "
    "the behavior is unpredictable across implementations."
)

# JSONTestSuite i_ means "parsers disagree". The RFC still decides the score.
# Stems are the test_parsing filename without ".json".
_UTF16_STEMS = frozenset(
    {
        "i_string_UTF-16LE_with_BOM",
        "i_string_utf16BE_no_BOM",
        "i_string_utf16LE_no_BOM",
    }
)
_ILL_FORMED_UTF8_STEMS = frozenset(
    {
        "i_string_UTF-8_invalid_sequence",
        "i_string_UTF8_surrogate_U+D800",
        "i_string_invalid_utf-8",
        "i_string_iso_latin_1",
        "i_string_lone_utf8_continuation_byte",
        "i_string_not_in_unicode_range",
        "i_string_overlong_sequence_2_bytes",
        "i_string_overlong_sequence_6_bytes",
        "i_string_overlong_sequence_6_bytes_null",
        "i_string_truncated-utf-8",
    }
)
_UNPAIRED_SURROGATE_STEMS = frozenset(
    {
        "i_object_key_lone_2nd_surrogate",
        "i_string_1st_surrogate_but_2nd_missing",
        "i_string_1st_valid_surrogate_2nd_invalid",
        "i_string_incomplete_surrogate_and_escape_valid",
        "i_string_incomplete_surrogate_pair",
        "i_string_incomplete_surrogates_escape_valid",
        "i_string_invalid_lonely_surrogate",
        "i_string_invalid_surrogate",
        "i_string_inverted_surrogates_U+1D11E",
        "i_string_lone_second_surrogate",
    }
)
_NESTING_STEM = "i_structure_500_nested_arrays"
_UTF8_BOM_STEM = "i_structure_UTF-8_BOM_empty_object"

_JSON_FILE_NOTES = {
    "8259": (
        "Official JSONTestSuite parse files (y_/n_/i_) plus original section-linked extras. "
        "An i_ file is scored from RFC 8259, not kept as expect any by default. "
        "expect any means both outcomes conform; the paragraph names the latitude, "
        "and neither outcome is preferred."
    ),
    "7159": (
        "Same parse corpus as RFC 8259; original extras cover UTF-16 (still allowed in 7159). "
        "UTF-16 JSONTestSuite files are accept. "
        "expect any means both outcomes conform; the paragraph names the latitude, "
        "and neither outcome is preferred."
    ),
    "4627": (
        "JSONTestSuite y_ cases that are not a top-level object/array are reject under RFC 4627. "
        "Ill-formed UTF-8 and a leading UTF-8 BOM are reject. UTF-16 text is accept. "
        "expect any means both outcomes conform; the paragraph names the latitude, "
        "and neither outcome is preferred."
    ),
}


def i_case_kind(stem: str) -> str:
    """Why an i_ file is not left as a generic MAY, or \"\" if this stem is not one."""
    if stem in _UTF16_STEMS:
        return "utf16"
    if stem in _ILL_FORMED_UTF8_STEMS:
        return "ill-formed-utf8"
    if stem in _UNPAIRED_SURROGATE_STEMS:
        return "unpaired-surrogate"
    if stem.startswith("i_number_"):
        return "number-limit"
    if stem == _NESTING_STEM:
        return "nesting-limit"
    if stem == _UTF8_BOM_STEM:
        return "utf8-bom"
    return ""


def _encoding_head(rfc: str) -> tuple[str, str, str]:
    if rfc == "4627":
        return "3", "Encoding", "https://www.rfc-editor.org/rfc/rfc4627#section-3"
    return "8.1", "Character Encoding", f"https://www.rfc-editor.org/rfc/rfc{rfc}#section-8.1"


def _parsers_head(rfc: str) -> tuple[str, str, str]:
    if rfc == "4627":
        return "4", "Parsers", "https://www.rfc-editor.org/rfc/rfc4627#section-4"
    return "9", "Parsers", f"https://www.rfc-editor.org/rfc/rfc{rfc}#section-9"


def _apply_i_policy(stem: str, rfc: str, fields: dict[str, str]) -> None:
    """Replace a generic i_ → MAY mapping with the cited RFC's rule."""
    kind = i_case_kind(stem)
    if not kind:
        return
    vendored = fields["notes"]
    if kind == "utf16":
        sec, title, url = _encoding_head(rfc)
        fields["section"] = sec
        fields["section_title"] = title
        fields["section_url"] = url
        if rfc == "8259":
            fields["paragraph"] = (
                "JSON text exchanged between systems that are not part of a closed "
                "ecosystem MUST be encoded using UTF-8."
            )
            fields["requirement"] = "MUST"
            fields["expect"] = "reject"
            fields["notes"] = (
                vendored
                + " JSONTestSuite marks this file i_. RFC 8259 interchange text is "
                "UTF-8 only, so this catalog rejects it."
            )
        elif rfc == "7159":
            fields["paragraph"] = (
                "JSON text SHALL be encoded in Unicode. The default encoding is UTF-8. "
                "UTF-16 and UTF-32 are also permitted."
            )
            fields["requirement"] = "MUST"
            fields["expect"] = "accept"
            fields["notes"] = (
                vendored
                + " JSONTestSuite marks this file i_. RFC 7159 permits UTF-16 and "
                "UTF-32, so a parser that rejects this text fails the case."
            )
        else:
            fields["paragraph"] = (
                "JSON text SHALL be encoded in Unicode. The first octets select "
                "UTF-8, UTF-16, or UTF-32."
            )
            fields["requirement"] = "MUST"
            fields["expect"] = "accept"
            fields["notes"] = (
                vendored
                + " JSONTestSuite marks this file i_. RFC 4627 requires the parser "
                "to detect this encoding."
            )
        return
    if kind == "ill-formed-utf8":
        sec, title, url = _encoding_head(rfc)
        fields["section"] = sec
        fields["section_title"] = title
        fields["section_url"] = url
        fields["requirement"] = "MUST NOT"
        fields["expect"] = "reject"
        if rfc == "8259":
            fields["paragraph"] = (
                "JSON text exchanged between systems that are not part of a closed "
                "ecosystem MUST be encoded using UTF-8. This sequence is not UTF-8."
            )
        elif rfc == "7159":
            fields["paragraph"] = (
                "JSON text SHALL be encoded in UTF-8, UTF-16, or UTF-32. "
                "This sequence is none of those encodings."
            )
        else:
            fields["paragraph"] = (
                "JSON text SHALL be encoded in Unicode. "
                "This sequence is not a Unicode encoding form."
            )
        fields["notes"] = (
            vendored
            + " JSONTestSuite marks this file i_. The bytes are not a legal encoding "
            "for this RFC, so this catalog rejects them."
        )
        return
    if kind == "unpaired-surrogate":
        if rfc == "4627":
            sec, title, url, _para = _json_cite("4627", "string")
            fields["paragraph"] = (
                "The string grammar includes \\u and four hex digits, and a string is "
                "a sequence of Unicode characters. Receivers disagree on an unpaired "
                "surrogate. Accept and reject are recorded and not scored."
            )
        else:
            sec, title, url = (
                "8.2",
                "Unicode Characters",
                f"https://www.rfc-editor.org/rfc/rfc{rfc}#section-8.2",
            )
            fields["paragraph"] = (
                "The grammar allows an unpaired surrogate, for example \\uDEAD. "
                "The behavior of software that receives such a text is unpredictable. "
                "Accepting it and rejecting it both conform."
            )
        fields["section"] = sec
        fields["section_title"] = title
        fields["section_url"] = url
        fields["requirement"] = "MAY"
        fields["expect"] = "any"
        fields["notes"] = (
            vendored
            + " I-JSON (RFC 7493) is the profile that forbids unpaired surrogates. "
            "Neither outcome is preferred here."
        )
        return
    if kind == "number-limit":
        if rfc == "4627":
            fields["paragraph"] = (
                "RFC 4627 gives the number grammar and does not set a maximum magnitude. "
                "Implementations differ when the value does not fit the host number type. "
                "Accept and reject are recorded and not scored."
            )
        else:
            fields["paragraph"] = (
                "This specification allows implementations to set limits on the range "
                "and precision of numbers accepted. A parser that accepts this number "
                "and a parser that rejects it both conform."
            )
        fields["notes"] = vendored + " Neither outcome is preferred."
        return
    if kind == "nesting-limit":
        sec, title, url = _parsers_head(rfc)
        fields["section"] = sec
        fields["section_title"] = title
        fields["section_url"] = url
        if rfc == "4627":
            fields["paragraph"] = (
                "RFC 4627 requires a parser to accept texts that conform to the grammar "
                "and does not name a nesting limit. Deep arrays exhaust real parsers. "
                "Accept and reject are recorded and not scored."
            )
        else:
            fields["paragraph"] = (
                "An implementation may set limits on the maximum depth of nesting. "
                "Rejecting this text at that limit and accepting it both conform."
            )
        fields["notes"] = vendored + " Neither outcome is preferred."
        return
    sec, title, url = _encoding_head(rfc)
    fields["section"] = sec
    fields["section_title"] = title
    fields["section_url"] = url
    if rfc == "4627":
        fields["paragraph"] = (
            "RFC 4627 does not allow a leading U+FEFF. A JSON text is an object or "
            "an array, and U+FEFF is not whitespace."
        )
        fields["requirement"] = "MUST NOT"
        fields["expect"] = "reject"
        fields["notes"] = (
            vendored
            + " JSONTestSuite marks this file i_. RFC 4627 has no permission to skip "
            "a UTF-8 BOM, so this catalog rejects it."
        )
        return
    fields["paragraph"] = (
        "Generators MUST NOT add a byte order mark. A parser MAY ignore a leading "
        "U+FEFF instead of reporting an error. Accepting the text and rejecting it "
        "both conform."
    )
    fields["requirement"] = "MAY"
    fields["expect"] = "any"
    fields["notes"] = vendored + " Neither outcome is preferred."


def _json_topic(name: str) -> str:
    n = name.lower()
    if "string" in n or "escaped" in n or "unicode" in n or "utf" in n or "surrogate" in n:
        return "string"
    if "number" in n or "int" in n or "real" in n or "minus" in n or "plus" in n:
        return "number"
    if "object" in n:
        return "object"
    if "array" in n:
        return "array"
    if "comment" in n:
        return "comment"
    return "grammar"


def _json_cite(rfc: str, topic: str) -> tuple[str, str, str, str]:
    """Section citation for one JSONTestSuite filename topic under one RFC.

    RFC 7159 and RFC 8259 share section numbers. RFC 4627 puts values, objects,
    arrays, numbers, and strings in §2.1–§2.5, and its JSON text is only an
    object or an array (§2).
    """
    if rfc == "4627":
        base = "https://www.rfc-editor.org/rfc/rfc4627"
        table = {
            "string": (
                "2.5",
                "Strings",
                f"{base}#section-2.5",
                "A string is a sequence of zero or more Unicode characters wrapped in quotation marks, with the escapes listed in RFC 4627 §2.5.",
            ),
            "number": (
                "2.4",
                "Numbers",
                f"{base}#section-2.4",
                "A number is produced from the RFC 4627 number grammar. NaN and Infinity are not number tokens.",
            ),
            "object": (
                "2.2",
                "Objects",
                f"{base}#section-2.2",
                "An object is a pair of curly brackets surrounding zero or more name/value pairs.",
            ),
            "array": (
                "2.3",
                "Arrays",
                f"{base}#section-2.3",
                "An array is a pair of square brackets surrounding zero or more values.",
            ),
            "comment": (
                "2",
                "JSON Grammar",
                f"{base}#section-2",
                "The JSON grammar has no comment production.",
            ),
            "grammar": (
                "2",
                "JSON Grammar",
                f"{base}#section-2",
                "A JSON text is a serialized object or array.",
            ),
        }
        return table[topic]
    number = "7159" if rfc == "7159" else "8259"
    base = f"https://www.rfc-editor.org/rfc/rfc{number}"
    label = f"RFC {number}"
    table = {
        "string": (
            "7",
            "Strings",
            f"{base}#section-7",
            f"A string is a sequence of Unicode code points wrapped in quotation marks, with the escapes listed in {label} §7.",
        ),
        "number": (
            "6",
            "Numbers",
            f"{base}#section-6",
            f"A number is produced from the {label} number grammar. NaN and Infinity are not number tokens.",
        ),
        "object": (
            "4",
            "Objects",
            f"{base}#section-4",
            "An object is a pair of curly brackets surrounding zero or more name/value pairs.",
        ),
        "array": (
            "5",
            "Arrays",
            f"{base}#section-5",
            "An array is a pair of square brackets surrounding zero or more values.",
        ),
        "comment": (
            "2",
            "JSON Grammar",
            f"{base}#section-2",
            "The JSON grammar has no comment production.",
        ),
        "grammar": (
            "2",
            "JSON Grammar",
            f"{base}#section-2",
            f"A JSON text is one serialized value matching the {label} grammar.",
        ),
    }
    return table[topic]


def jts_case_fields(name: str, raw: bytes, rfc: str) -> dict[str, str]:
    """Citation and scoring fields for one JSONTestSuite file under one RFC.

    ``name`` is the suite filename (``y_string_space.json``) or its stem.
    ``rfc`` is ``4627``, ``7159``, or ``8259``.
    """
    filename = name if name.endswith(".json") else f"{name}.json"
    stem = filename[:-5]
    sec, title, url, para = _json_cite(rfc, _json_topic(filename))
    top = raw.lstrip()[:1]
    if filename.startswith("y_"):
        expect = "accept"
        req = "MUST"
        if rfc == "4627" and top not in (b"{", b"["):
            expect = "reject"
            sec, title, url, para = _json_cite("4627", "grammar")
    elif filename.startswith("n_"):
        expect = "reject"
        req = "MUST NOT"
    elif filename.startswith("i_"):
        expect = "any"
        req = "MAY"
    else:
        raise ValueError(filename)
    notes = f"Vendored from nst/JSONTestSuite test_parsing/{filename} (MIT)."
    if rfc == "4627" and filename.startswith("y_") and top not in (b"{", b"[") and stem not in _DUP_OBJECT_STEMS:
        notes += " Rejected under RFC 4627 because the top-level value is not an object or array."
    if stem in _DUP_OBJECT_STEMS:
        expect = "any"
        req = "SHOULD"
        sec, title, url, para = _json_cite(rfc, "object")
        para = _DUP_PARAGRAPH
        notes = (
            f"Vendored from nst/JSONTestSuite test_parsing/{filename} (MIT). "
            "JSONTestSuite marks this file y_ (must accept). This catalog scores it "
            "implementation-defined: the RFC says member names SHOULD be unique and "
            "behavior is unpredictable when they are not."
        )
    fields = {
        "section": sec,
        "section_title": title,
        "section_url": url,
        "paragraph": para,
        "requirement": req,
        "expect": expect,
        "notes": notes,
    }
    if filename.startswith("i_"):
        _apply_i_policy(stem, rfc, fields)
    return fields


def import_json() -> None:
    parsing = SRC / "JSONTestSuite" / "test_parsing"
    if not parsing.is_dir():
        raise SystemExit(f"missing {parsing}")
    rfc8259: list[dict] = []
    rfc7159: list[dict] = []
    rfc4627: list[dict] = []
    for path in sorted(parsing.glob("*.json")):
        raw = path.read_bytes()
        text, enc = _bytes_to_input(raw)
        name = path.name
        if not (name.startswith("y_") or name.startswith("n_") or name.startswith("i_")):
            continue
        stem = path.stem
        title = stem.replace("_", " ")
        for rfc, bucket in (("8259", rfc8259), ("7159", rfc7159), ("4627", rfc4627)):
            fields = jts_case_fields(name, raw, rfc)
            bucket.append(
                {
                    "title": title,
                    "section": fields["section"],
                    "section_title": fields["section_title"],
                    "section_url": fields["section_url"],
                    "paragraph": fields["paragraph"],
                    "requirement": fields["requirement"],
                    "input": text,
                    "input_encoding": enc,
                    "notes": fields["notes"],
                    "id": f"jts-{rfc}-{stem}",
                    "expect": fields["expect"],
                }
            )

    extras_8259 = [c for c in _load_existing("json/rfc8259.json") if not str(c["id"]).startswith("jts-")]
    extras_7159 = [c for c in _load_existing("json/rfc7159.json") if not str(c["id"]).startswith("jts-")]
    extras_4627 = [c for c in _load_existing("json/rfc4627.json") if not str(c["id"]).startswith("jts-")]

    _dump(
        "json/rfc8259.json",
        {
            "format": "json",
            "standard": "RFC 8259",
            "version": "8259",
            "standard_url": "https://www.rfc-editor.org/rfc/rfc8259",
            "provenance": "nst/JSONTestSuite+original-work",
            "notes": _JSON_FILE_NOTES["8259"],
            "cases": _merge(rfc8259, extras_8259),
        },
    )
    _dump(
        "json/rfc7159.json",
        {
            "format": "json",
            "standard": "RFC 7159",
            "version": "7159",
            "standard_url": "https://www.rfc-editor.org/rfc/rfc7159",
            "provenance": "nst/JSONTestSuite+original-work",
            "notes": _JSON_FILE_NOTES["7159"],
            "cases": _merge(rfc7159, extras_7159),
        },
    )
    _dump(
        "json/rfc4627.json",
        {
            "format": "json",
            "standard": "RFC 4627",
            "version": "4627",
            "standard_url": "https://www.rfc-editor.org/rfc/rfc4627",
            "provenance": "nst/JSONTestSuite+original-work",
            "notes": _JSON_FILE_NOTES["4627"],
            "cases": _merge(rfc4627, extras_4627),
        },
    )


def unescape_yaml_test_suite(text: str) -> str:
    """Decode yaml-test-suite visualization glyphs into real bytes.

    See yaml/yaml-test-suite ReadMe.md “Special Characters”.
    """
    for glyph in ("————»", "———»", "——»", "—»", "»"):
        text = text.replace(glyph, "\t")
    text = text.replace("␣", " ")
    text = text.replace("↵", "")
    text = text.replace("←", "\r")
    text = text.replace("⇔", "\ufeff")
    if "∎" in text:
        text = text.replace("∎", "")
        if text.endswith("\n"):
            text = text[:-1]
    return text


def import_yaml() -> None:
    src = SRC / "yaml-test-suite" / "src"
    if not src.is_dir():
        raise SystemExit(f"missing {src}")
    try:
        import yaml
    except ImportError as exc:
        raise SystemExit("PyYAML required to import yaml-test-suite") from exc

    official: list[dict] = []
    for path in sorted(src.glob("*.yaml")):
        try:
            docs = list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
        except Exception:
            continue
        idx = 0
        for doc in docs:
            items = doc if isinstance(doc, list) else [doc]
            for item in items:
                if not isinstance(item, dict) or "yaml" not in item:
                    continue
                idx += 1
                tags = item.get("tags") or ""
                if isinstance(tags, list):
                    tags = " ".join(str(t) for t in tags)
                fail = bool(item.get("fail")) or "error" in str(tags).split()
                spec = item.get("from") or ""
                url = "https://yaml.org/spec/1.2.2/"
                if isinstance(spec, str) and spec.startswith("http"):
                    candidate = spec.split()[0]
                    if "yaml.org/spec/" in candidate:
                        url = candidate
                name = item.get("name") or path.stem
                yml = item["yaml"]
                if not isinstance(yml, str):
                    continue
                yml = unescape_yaml_test_suite(yml)
                official.append(
                    {
                        "id": f"yts-{path.stem}-{idx}",
                        "title": str(name),
                        "section": "1.2",
                        "section_title": "YAML 1.2",
                        "section_url": url,
                        "paragraph": "Official yaml-test-suite item. fail/error tagged cases must be rejected; others must be accepted.",
                        "requirement": "MUST NOT" if fail else "MUST",
                        "expect": "reject" if fail else "accept",
                        "input": yml,
                        "input_encoding": "utf-8",
                        "notes": f"Vendored from yaml/yaml-test-suite src/{path.name} (MIT).",
                    }
                )

    extras_12 = [c for c in _load_existing("yaml/v1.2.json") if not str(c["id"]).startswith("yts-")]
    extras_122 = [c for c in _load_existing("yaml/v1.2.2.json") if not str(c["id"]).startswith("yts-")]
    extras_11 = [c for c in _load_existing("yaml/v1.1.json") if not str(c["id"]).startswith("yts-")]
    _dump(
        "yaml/v1.2.json",
        {
            "format": "yaml",
            "standard": "YAML 1.2",
            "version": "1.2",
            "standard_url": "https://yaml.org/spec/1.2/spec.html",
            "provenance": "yaml/yaml-test-suite+original-work",
            "notes": "Official YAML Test Suite (MIT) plus original extras.",
            "cases": _merge(official, extras_12),
        },
    )
    _dump(
        "yaml/v1.2.2.json",
        {
            "format": "yaml",
            "standard": "YAML 1.2.2",
            "version": "1.2.2",
            "standard_url": "https://yaml.org/spec/1.2.2/",
            "provenance": "yaml/yaml-test-suite+original-work",
            "notes": "Same official suite as 1.2 (1.2.2 is the current 1.2 revision) plus original extras.",
            "cases": _merge(official, extras_122),
        },
    )
    _dump(
        "yaml/v1.1.json",
        {
            "format": "yaml",
            "standard": "YAML 1.1",
            "version": "1.1",
            "standard_url": "https://yaml.org/spec/1.1/",
            "provenance": "yaml/yaml-test-suite+original-work",
            "notes": "Official suite is 1.2-oriented; 1.1 extras cover yes/no booleans and sexagesimal.",
            "cases": _merge(official, extras_11),
        },
    )


def _toml_section(rel: str, version: str) -> tuple[str, str, str, str]:
    kind = rel.split("/")[1] if "/" in rel else "document"
    url = f"https://toml.io/en/v{version}#{kind.replace('_', '-')}"
    return kind, kind.replace("-", " ").title(), url, f"TOML {version} {kind} production."


def import_toml() -> None:
    tests = SRC / "toml-test" / "tests"
    if not tests.is_dir():
        raise SystemExit(f"missing {tests}")

    def load_list(name: str) -> list[str]:
        path = tests / name
        return [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip()]

    def cases_for(version: str, listing: str) -> list[dict]:
        out = []
        for rel in load_list(listing):
            if not rel.endswith(".toml"):
                rel = rel + ".toml" if not rel.endswith(".json") else ""
            if not rel.endswith(".toml"):
                continue
            path = tests / rel
            if not path.is_file():
                continue
            raw = path.read_bytes()
            text, enc = _bytes_to_input(raw)
            invalid = rel.startswith("invalid/")
            sec, title, url, para = _toml_section(rel, version)
            stem = rel.replace("/", "-").removesuffix(".toml")
            out.append(
                {
                    "id": f"toml-{version}-{stem}",
                    "title": rel,
                    "section": sec,
                    "section_title": title,
                    "section_url": url,
                    "paragraph": para,
                    "requirement": "MUST NOT" if invalid else "MUST",
                    "expect": "reject" if invalid else "accept",
                    "input": text,
                    "input_encoding": enc,
                    "notes": f"Vendored from toml-lang/toml-test tests/{rel} (MIT).",
                }
            )
        return out

    extras_10 = [c for c in _load_existing("toml/v1.0.0.json") if not str(c["id"]).startswith("toml-1.0.0-")]
    extras_11 = [c for c in _load_existing("toml/v1.1.0.json") if not str(c["id"]).startswith("toml-1.1.0-")]
    extras_05 = _load_existing("toml/v0.5.0.json")
    _dump(
        "toml/v1.0.0.json",
        {
            "format": "toml",
            "standard": "TOML 1.0.0",
            "version": "1.0.0",
            "standard_url": "https://toml.io/en/v1.0.0",
            "provenance": "toml-lang/toml-test+original-work",
            "notes": "Official toml-test files-toml-1.0.0 list (MIT).",
            "cases": _merge(cases_for("1.0.0", "files-toml-1.0.0"), extras_10),
        },
    )
    _dump(
        "toml/v1.1.0.json",
        {
            "format": "toml",
            "standard": "TOML 1.1.0",
            "version": "1.1.0",
            "standard_url": "https://toml.io/en/v1.1.0",
            "provenance": "toml-lang/toml-test+original-work",
            "notes": "Official toml-test files-toml-1.1.0 list (MIT).",
            "cases": _merge(cases_for("1.1.0", "files-toml-1.1.0"), extras_11),
        },
    )
    _dump(
        "toml/v0.5.0.json",
        {
            "format": "toml",
            "standard": "TOML 0.5.0",
            "version": "0.5.0",
            "standard_url": "https://toml.io/en/v0.5.0",
            "provenance": "original-work",
            "notes": "No official 0.5 file list; original cases kept. Use 1.0/1.1 columns for the full toml-test corpus.",
            "cases": extras_05,
        },
    )


def import_msgpack() -> None:
    path = SRC / "msgpack-test-suite" / "dist" / "msgpack-test-suite.json"
    if not path.is_file():
        raise SystemExit(f"missing {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    official: list[dict] = []
    n = 0
    for group, exams in data.items():
        for exam in exams:
            hexes = exam.get("msgpack") or []
            if not hexes:
                continue
            n += 1
            compact = str(hexes[0]).replace("-", "")
            kind = next((k for k in exam if k != "msgpack"), "value")
            official.append(
                {
                    "id": f"mps-{group}-{n}",
                    "title": f"{group} {kind}={exam.get(kind)!r}",
                    "section": kind,
                    "section_title": f"{kind} format family",
                    "section_url": "https://github.com/msgpack/msgpack/blob/master/spec.md",
                    "paragraph": "Official kawanet/msgpack-test-suite vector. The listed hex encodings must decode.",
                    "requirement": "MUST",
                    "expect": "accept",
                    "input": compact,
                    "input_encoding": "hex",
                    "notes": f"Vendored from kawanet/msgpack-test-suite {group} (MIT).",
                }
            )
    extras_13 = [c for c in _load_existing("msgpack/spec-2013-str-bin.json") if not str(c["id"]).startswith("mps-")]
    extras_17 = [c for c in _load_existing("msgpack/spec-2017-timestamp.json") if not str(c["id"]).startswith("mps-")]
    extras_08 = _load_existing("msgpack/spec-2008-raw.json")
    _dump(
        "msgpack/spec-2013-str-bin.json",
        {
            "format": "msgpack",
            "standard": "MessagePack (2013 str/bin/ext)",
            "version": "2013-str-bin",
            "standard_url": "https://github.com/msgpack/msgpack/blob/master/spec.md",
            "provenance": "kawanet/msgpack-test-suite+original-work",
            "notes": "Official msgpack-test-suite hex vectors (MIT) plus original extras.",
            "cases": _merge(official, extras_13),
        },
    )
    _dump(
        "msgpack/spec-2017-timestamp.json",
        {
            "format": "msgpack",
            "standard": "MessagePack (2017 timestamp ext)",
            "version": "2017-timestamp",
            "standard_url": "https://github.com/msgpack/msgpack/blob/master/spec.md#timestamp-extension-type",
            "provenance": "kawanet/msgpack-test-suite+original-work",
            "notes": "Same official vectors (includes timestamp group) plus original extras.",
            "cases": _merge(official, extras_17),
        },
    )
    _dump(
        "msgpack/spec-2008-raw.json",
        {
            "format": "msgpack",
            "standard": "MessagePack (pre-2013 raw)",
            "version": "2008-raw",
            "standard_url": "https://github.com/msgpack/msgpack/blob/master/spec-old.md",
            "provenance": "original-work",
            "notes": "Pre-str/bin chart. Official suite targets the 2013+ spec; original 2008 cases kept.",
            "cases": extras_08,
        },
    )


_EDN_TEST = re.compile(
    r'\{\s*"description"\s*:\s*"(?P<desc>(?:\\.|[^"\\])*)".*?"encoded"\s*:\s*h\'(?P<hex>[0-9a-fA-F \n]+)\'',
    re.S,
)


def import_cbor() -> None:
    base = SRC / "cbor-test-vectors" / "tests" / "rfc8949"
    if not base.is_dir():
        raise SystemExit(f"missing {base}")

    def from_edn(path: Path, expect: str, req: str) -> list[dict]:
        text = path.read_text(encoding="utf-8")
        out = []
        for i, m in enumerate(_EDN_TEST.finditer(text), 1):
            hx = re.sub(r"\s+", "", m.group("hex"))
            out.append(
                {
                    "id": f"cbor-wg-{path.stem}-{i}",
                    "title": m.group("desc"),
                    "section": "3",
                    "section_title": "CBOR data items",
                    "section_url": "https://www.rfc-editor.org/rfc/rfc8949#section-3",
                    "paragraph": "cbor-wg/cbor-test-vectors (BSD-2-Clause) for RFC 8949 well-formedness.",
                    "requirement": req,
                    "expect": expect,
                    "input": hx,
                    "input_encoding": "hex",
                    "notes": f"Vendored from cbor-wg/cbor-test-vectors tests/rfc8949/{path.name}.",
                }
            )
        return out

    good = from_edn(base / "good.edn", "accept", "MUST")
    bad = from_edn(base / "bad.edn", "reject", "MUST NOT")
    extras_8949 = [c for c in _load_existing("cbor/rfc8949.json") if not str(c["id"]).startswith("cbor-wg-")]
    extras_7049 = [c for c in _load_existing("cbor/rfc7049.json") if not str(c["id"]).startswith("cbor-wg-")]
    official = good + bad
    _dump(
        "cbor/rfc8949.json",
        {
            "format": "cbor",
            "standard": "RFC 8949",
            "version": "8949",
            "standard_url": "https://www.rfc-editor.org/rfc/rfc8949",
            "provenance": "cbor-wg/cbor-test-vectors+original-work+ietf-appendix-A",
            "notes": "Official cbor-wg good/bad vectors (BSD-2-Clause) plus original Appendix A extras.",
            "cases": _merge(official, extras_8949),
        },
    )
    _dump(
        "cbor/rfc7049.json",
        {
            "format": "cbor",
            "standard": "RFC 7049",
            "version": "7049",
            "standard_url": "https://www.rfc-editor.org/rfc/rfc7049",
            "provenance": "cbor-wg/cbor-test-vectors+original-work+ietf-appendix-A",
            "notes": "Same well-formedness corpus (8949 tightens a few cases) plus original extras.",
            "cases": _merge(official, extras_7049),
        },
    )


def copy_licenses() -> None:
    mapping = {
        "JSONTestSuite/LICENSE": "JSONTestSuite.MIT.txt",
        "yaml-test-suite/License": "yaml-test-suite.MIT.txt",
        "toml-test/LICENSE": "toml-test.MIT.txt",
        "msgpack-test-suite/LICENSE": "msgpack-test-suite.MIT.txt",
        "cbor-test-vectors/LICENSE": "cbor-test-vectors.BSD-2-Clause.txt",
    }
    VENDOR.mkdir(parents=True, exist_ok=True)
    for src_rel, dest_name in mapping.items():
        src = SRC / src_rel
        if src.is_file():
            (VENDOR / dest_name).write_bytes(src.read_bytes())
            print(f"copied license {dest_name}")


def main() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"Suite clones not found at {SRC}. Clone them first (see script docstring).")
    copy_licenses()
    import_json()
    import_yaml()
    import_toml()
    import_msgpack()
    import_cbor()


if __name__ == "__main__":
    main()
