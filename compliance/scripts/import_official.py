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


def _dump(rel: str, doc: dict) -> None:
    path = DATA / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)} ({len(doc['cases'])} cases)")


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


def _json_section(name: str) -> tuple[str, str, str, str]:
    n = name.lower()
    base = "https://www.rfc-editor.org/rfc/rfc8259"
    if "string" in n or "escaped" in n or "unicode" in n or "utf" in n or "surrogate" in n:
        return "7", "Strings", f"{base}#section-7", "A string is a sequence of Unicode code points wrapped in quotation marks, with the escapes listed in RFC 8259 §7."
    if "number" in n or "int" in n or "real" in n or "minus" in n or "plus" in n:
        return "6", "Numbers", f"{base}#section-6", "A number is produced from the RFC 8259 number grammar. NaN and Infinity are not number tokens."
    if "object" in n:
        return "4", "Objects", f"{base}#section-4", "An object is a pair of curly brackets surrounding zero or more name/value pairs."
    if "array" in n:
        return "5", "Arrays", f"{base}#section-5", "An array is a pair of square brackets surrounding zero or more values."
    if "comment" in n:
        return "2", "JSON Grammar", f"{base}#section-2", "The JSON grammar has no comment production."
    return "2", "JSON Grammar", f"{base}#section-2", "A JSON text is one serialized value matching the RFC 8259 grammar."


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
        sec, title, url, para = _json_section(name)
        stripped = raw.lstrip()
        top = stripped[:1]
        if name.startswith("y_"):
            expect_8259 = "accept"
            expect_4627 = "accept" if top in (b"{", b"[") else "reject"
            req = "MUST"
        elif name.startswith("n_"):
            expect_8259 = expect_4627 = "reject"
            req = "MUST NOT"
        elif name.startswith("i_"):
            expect_8259 = expect_4627 = "any"
            req = "MAY"
        else:
            continue
        stem = path.stem
        common = {
            "title": stem.replace("_", " "),
            "section": sec,
            "section_title": title,
            "section_url": url,
            "paragraph": para,
            "requirement": req,
            "input": text,
            "input_encoding": enc,
            "notes": f"Vendored from nst/JSONTestSuite test_parsing/{name} (MIT).",
        }
        rfc8259.append({**common, "id": f"jts-8259-{stem}", "expect": expect_8259})
        rfc7159.append({**common, "id": f"jts-7159-{stem}", "expect": expect_8259})
        rfc4627.append({**common, "id": f"jts-4627-{stem}", "expect": expect_4627})

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
            "notes": "Official JSONTestSuite parse files (y_/n_/i_) plus original section-linked extras.",
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
            "notes": "Same parse corpus as RFC 8259; original extras cover UTF-16 (still allowed in 7159).",
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
            "notes": "JSONTestSuite y_ cases that are not a top-level object/array are reject under RFC 4627.",
            "cases": _merge(rfc4627, extras_4627),
        },
    )


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
                url = spec if isinstance(spec, str) and spec.startswith("http") else "https://yaml.org/spec/1.2.2/"
                name = item.get("name") or path.stem
                yml = item["yaml"]
                if not isinstance(yml, str):
                    continue
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
