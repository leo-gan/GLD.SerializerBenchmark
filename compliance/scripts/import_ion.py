#!/usr/bin/env python3
"""Import Amazon ion-tests iontestdata into compliance/data/ion/.

Reads a local clone (default /tmp/ion-tests). Does not fetch the network.
License: Apache-2.0 (Amazon.com, Inc.). See compliance/vendor/ion-tests.Apache-2.0.txt.

  python3 compliance/scripts/import_ion.py /tmp/ion-tests
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
VENDOR = ROOT / "vendor"
SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/ion-tests")

SPEC = "https://amazon-ion.github.io/ion-docs/docs/spec.html"
BINARY = "https://amazon-ion.github.io/ion-docs/docs/binary.html"
SYMBOLS = "https://amazon-ion.github.io/ion-docs/docs/symbols.html"
SPEC_11 = "https://amazon-ion.github.io/ion-docs/books/ion-1-1/"


def _dump(rel: str, doc: dict) -> None:
    path = DATA / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)} ({len(doc['cases'])} cases)")


def _bytes_to_input(raw: bytes) -> tuple[str, str]:
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.hex(), "hex"


def _section(rel: str, binary: bool) -> tuple[str, str, str, str]:
    n = rel.lower().replace("\\", "/")
    if binary or n.endswith(".10n") or "typecode" in n or "magic" in n or n.endswith(".10n"):
        if "ivm" in n or "magic" in n:
            return (
                "Value Streams",
                "binary version marker",
                BINARY,
                "A binary Ion stream starts with the four-octet BVM 0xE0 0x01 0x00 0xEA.",
            )
        if "nop" in n or "pad" in n:
            return (
                "NOP Padding",
                "binary NOP",
                f"{BINARY}#nop-padding",
                "Binary Ion may insert NOP padding; a truncated or annotated NOP is not well-formed.",
            )
        if "symbol" in n or "annotation" in n:
            return (
                "Annotations",
                "binary annotations",
                f"{BINARY}#annotations",
                "Annotation wrappers and symbol IDs must resolve in the current symbol table.",
            )
        return (
            "Value Streams",
            "binary encoding",
            BINARY,
            "Each binary value is a type descriptor plus an optional representation. Lengths must match the remaining bytes.",
        )
    if "timestamp" in n:
        return (
            "Timestamps",
            "timestamp",
            f"{SPEC}#timestamps",
            "A timestamp is a date and optional time-of-day with an offset. Out-of-range fields are invalid.",
        )
    if "utf8" in n or "utf-8" in n or "utf16" in n or "utf32" in n:
        return (
            "Strings",
            "character encoding",
            f"{SPEC}#strings",
            "Ion text strings are Unicode. Invalid UTF-8 / unexpected UTF-16 or UTF-32 is not well-formed text.",
        )
    if "string" in n or "clob" in n:
        kind = "clob" if "clob" in n else "string"
        return (
            "Clobs" if kind == "clob" else "Strings",
            kind,
            SPEC,
            "Strings are double-quoted Unicode. Clobs are uninterpreted bytes in a {{ }} wrapper and must be ASCII in text.",
        )
    if "blob" in n:
        return (
            "Blobs",
            "blob",
            SPEC,
            "A blob is uninterpreted bytes written as {{ base64 }}. The closer must be well-formed.",
        )
    if "decimal" in n:
        return (
            "Decimals",
            "decimal",
            f"{SPEC}#decimals",
            "A decimal is a coefficient and an exponent. Underscores and a leading plus are not allowed in this form.",
        )
    if "float" in n or "nan" in n or "inf" in n:
        return (
            "Floats",
            "float",
            f"{SPEC}#floats",
            "Ion floats are IEEE-754 binary32/binary64. A leading plus on a float token is invalid.",
        )
    if "int" in n or "hex" in n or "octal" in n or "binaryint" in n:
        return (
            "Integers",
            "integer",
            f"{SPEC}#integers",
            "Integers are decimal, hex (0x), or binary (0b). A leading plus, trailing underscore, or empty digits are invalid.",
        )
    if "struct" in n or "fieldname" in n:
        return (
            "Structs",
            "struct",
            f"{SPEC}#structs",
            "A struct is { field: value, ... }. Field names are symbols. A leading comma or a closer from another container is invalid.",
        )
    if "list" in n:
        return (
            "Lists",
            "list",
            f"{SPEC}#lists",
            "A list is [ values ]. It must close with ] and cannot use a struct or sexp closer.",
        )
    if "sexp" in n:
        return (
            "S-expressions",
            "sexp",
            f"{SPEC}#s-expressions",
            "An s-expression is ( values ). Operators are symbols. It must close with ).",
        )
    if "annotation" in n or "symbol" in n:
        return (
            "Symbols",
            "symbols and annotations",
            SYMBOLS,
            "Annotations are symbol::value. An annotation must be a symbol and must precede a value.",
        )
    if "null" in n:
        return (
            "Nulls",
            "null",
            f"{SPEC}#nulls",
            "typed null is written null.type. A trailing dot without a type is invalid.",
        )
    if "bool" in n or "true" in n or "false" in n:
        return (
            "Booleans",
            "boolean",
            f"{SPEC}#booleans",
            "Booleans are the unquoted tokens true and false.",
        )
    if "blank" in n or "empty" in n or "whitespace" in n or "comment" in n:
        return (
            "Grammar",
            "whitespace and comments",
            SPEC,
            "An Ion document may be empty. C-style comments are whitespace. A document is zero or more top-level values.",
        )
    if "ivm" in n or "version" in n:
        return (
            "Ion Version Markers",
            "IVM",
            f"{SYMBOLS}#ion-version-markers",
            "The text IVM is the unquoted top-level symbol $ion_1_0. An unsupported version is invalid Ion 1.0.",
        )
    return (
        "Grammar",
        "Ion text",
        SPEC,
        "An Ion text document is zero or more values. Tokens must match the Ion 1.0 grammar.",
    )


def _collect(kind: str) -> list[dict]:
    base = SRC / "iontestdata" / kind
    if not base.is_dir():
        raise SystemExit(f"missing {base}")
    expect = "accept" if kind == "good" else "reject"
    req = "MUST" if kind == "good" else "MUST NOT"
    out: list[dict] = []
    for path in sorted(base.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in {".ion", ".10n"}:
            continue
        rel = path.relative_to(base).as_posix()
        raw = path.read_bytes()
        text, enc = _bytes_to_input(raw)
        binary = path.suffix == ".10n"
        sec, title, url, para = _section(rel, binary)
        stem = rel.replace("/", "-").replace(".", "-")
        out.append(
            {
                "id": f"ion-{kind}-{stem}",
                "title": rel,
                "section": sec,
                "section_title": title,
                "section_url": url,
                "paragraph": para,
                "requirement": req,
                "expect": expect,
                "input": text,
                "input_encoding": enc,
                "notes": f"Vendored from amazon-ion/ion-tests iontestdata/{kind}/{rel} (Apache-2.0).",
            }
        )
    return out


def write_ion_11() -> None:
    cases = [
        {
            "id": "ion11-text-ivm",
            "title": "Ion 1.1 text version marker",
            "section": "Version markers",
            "section_title": "Ion 1.1 IVM",
            "section_url": SPEC_11,
            "paragraph": "The text IVM $ion_1_1 selects Ion 1.1. A 1.1 processor must accept it.",
            "requirement": "MUST",
            "expect": "accept",
            "input": "$ion_1_1 7",
        },
        {
            "id": "ion11-binary-ivm",
            "title": "Ion 1.1 binary version marker",
            "section": "Version markers",
            "section_title": "Ion 1.1 BVM",
            "section_url": SPEC_11,
            "paragraph": "The binary version marker for Ion 1.1 is 0xE0 0x01 0x01 0xEA.",
            "requirement": "MUST",
            "expect": "accept",
            "input": "e00101ea0f",
            "input_encoding": "hex",
        },
        {
            "id": "ion11-reads-10-text",
            "title": "Ion 1.1 processor reads Ion 1.0 text",
            "section": "Compatibility",
            "section_title": "1.0 documents",
            "section_url": SPEC_11,
            "paragraph": "An Ion 1.1 processor must still accept an Ion 1.0 text document.",
            "requirement": "MUST",
            "expect": "accept",
            "input": "$ion_1_0 {harbor: kelp}",
        },
        {
            "id": "ion11-reads-10-binary",
            "title": "Ion 1.1 processor reads Ion 1.0 binary",
            "section": "Compatibility",
            "section_title": "1.0 documents",
            "section_url": SPEC_11,
            "paragraph": "An Ion 1.1 processor must still accept the Ion 1.0 BVM 0xE0 0x01 0x00 0xEA.",
            "requirement": "MUST",
            "expect": "accept",
            "input": "e00100ea11",
            "input_encoding": "hex",
        },
        {
            "id": "ion11-unsupported-major",
            "title": "Unknown major version is not Ion 1.1",
            "section": "Version markers",
            "section_title": "Ion 1.1 IVM",
            "section_url": SPEC_11,
            "paragraph": "A BVM whose major version is not 1 is not a supported Ion stream.",
            "requirement": "MUST NOT",
            "expect": "reject",
            "input": "e00200ea",
            "input_encoding": "hex",
        },
    ]
    _dump(
        "ion/1.1.json",
        {
            "format": "ion",
            "standard": "Amazon Ion 1.1",
            "version": "1.1",
            "standard_url": SPEC_11,
            "provenance": "original-work",
            "notes": "Original 1.1 IVM / compatibility cases. amazon.ion 0.x is a 1.0 reader.",
            "cases": cases,
        },
    )


def copy_license() -> None:
    src = SRC / "LICENSE"
    VENDOR.mkdir(parents=True, exist_ok=True)
    dest = VENDOR / "ion-tests.Apache-2.0.txt"
    if src.is_file():
        shutil.copyfile(src, dest)
        print(f"copied license {dest.name}")
    else:
        print(f"warning: missing {src}")


def main() -> None:
    if not (SRC / "iontestdata").is_dir():
        raise SystemExit(f"iontestdata not found at {SRC}. Clone amazon-ion/ion-tests first.")
    copy_license()
    good = _collect("good")
    bad = _collect("bad")
    # Split by original suffix recorded in the id (…-ion vs …-10n).
    text_cases = [c for c in good + bad if c["id"].endswith("-ion")]
    bin_cases = [c for c in good + bad if c["id"].endswith("-10n")]
    if not text_cases or not bin_cases:
        raise SystemExit(f"expected both .ion and .10n cases, got {len(text_cases)} text / {len(bin_cases)} binary")
    _dump(
        "ion/text-1.0.json",
        {
            "format": "ion",
            "standard": "Amazon Ion 1.0 text",
            "version": "1.0-text",
            "standard_url": SPEC,
            "provenance": "amazon-ion/ion-tests",
            "notes": "Official iontestdata good/bad *.ion (Apache-2.0). Accept/reject only; equivalence folders are still valid documents.",
            "cases": text_cases,
        },
    )
    _dump(
        "ion/binary-1.0.json",
        {
            "format": "ion",
            "standard": "Amazon Ion 1.0 binary",
            "version": "1.0-binary",
            "standard_url": BINARY,
            "provenance": "amazon-ion/ion-tests",
            "notes": "Official iontestdata good/bad *.10n (Apache-2.0).",
            "cases": bin_cases,
        },
    )
    write_ion_11()


if __name__ == "__main__":
    main()
