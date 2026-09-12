"""Load and validate the on-disk compliance corpus (`compliance/data/`)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

from .models import Case, Suite

_VALID_EXPECT = {"accept", "reject", "roundtrip", "any"}
_VALID_REQ = {"MUST", "MUST NOT", "SHOULD", "SHOULD NOT", "MAY"}
_VALID_ENC = {"utf-8", "hex", "latin-1"}


def repo_root() -> Path:
    """Return the monorepo root (directory that contains compliance/data)."""
    here = Path(__file__).resolve()
    for candidate in (here.parents[3], here.parents[2], Path.cwd()):
        if (candidate / "compliance" / "data").is_dir():
            return candidate
    raise FileNotFoundError(
        "Cannot locate compliance/data — run from the serializer-benchmark repo"
    )


def corpus_root() -> Path:
    return repo_root() / "compliance" / "data"


def load_all_suites(root: Path | None = None) -> list[Suite]:
    base = root if root is not None else corpus_root()
    suites: list[Suite] = []
    for path in sorted(base.glob("*/*.json")):
        if path.name.startswith("_") or path.name == "schema.json":
            continue
        suites.append(load_suite(path))
    if not suites:
        raise FileNotFoundError(f"No compliance suites under {base}")
    return suites


def load_suite(path: Path) -> Suite:
    raw = json.loads(path.read_text(encoding="utf-8"))
    errors = list(_validate_suite_dict(raw, path))
    if errors:
        raise ValueError(f"{path}: " + "; ".join(errors))
    cases = tuple(_case_from_dict(item) for item in raw["cases"])
    return Suite(
        format=raw["format"],
        standard=raw["standard"],
        version=str(raw["version"]),
        standard_url=raw["standard_url"],
        provenance=raw.get("provenance", ""),
        cases=cases,
        notes=raw.get("notes", ""),
        source_path=str(path),
        adapters=tuple(raw.get("adapters") or ()),
    )


def _case_from_dict(item: dict[str, Any]) -> Case:
    has_decoded = "decoded" in item
    skip = item.get("skip_adapters") or []
    return Case(
        id=item["id"],
        title=item["title"],
        section=str(item["section"]),
        section_title=item["section_title"],
        section_url=item["section_url"],
        paragraph=item["paragraph"],
        requirement=item["requirement"],
        expect=item["expect"],
        input=item["input"],
        input_encoding=item.get("input_encoding", "utf-8"),
        decoded=item.get("decoded"),
        has_decoded=has_decoded,
        notes=item.get("notes", ""),
        skip_adapters=tuple(skip),
        schema=item.get("schema"),
    )


def _validate_suite_dict(raw: Any, path: Path) -> Iterable[str]:
    if not isinstance(raw, dict):
        yield "suite root must be an object"
        return
    for key in ("format", "standard", "version", "standard_url", "cases"):
        if key not in raw:
            yield f"missing suite field {key!r}"
    cases = raw.get("cases")
    if not isinstance(cases, list) or not cases:
        yield "cases must be a non-empty array"
        return
    seen: set[str] = set()
    for i, item in enumerate(cases):
        prefix = f"cases[{i}]"
        if not isinstance(item, dict):
            yield f"{prefix} must be an object"
            continue
        for key in (
            "id",
            "title",
            "section",
            "section_title",
            "section_url",
            "paragraph",
            "requirement",
            "expect",
            "input",
        ):
            if key not in item:
                yield f"{prefix} missing {key!r}"
        cid = item.get("id")
        if isinstance(cid, str):
            if cid in seen:
                yield f"duplicate case id {cid!r}"
            seen.add(cid)
        if item.get("expect") not in _VALID_EXPECT:
            yield f"{prefix} expect must be one of {sorted(_VALID_EXPECT)}"
        if item.get("requirement") not in _VALID_REQ:
            yield f"{prefix} requirement must be one of {sorted(_VALID_REQ)}"
        enc = item.get("input_encoding", "utf-8")
        if enc not in _VALID_ENC:
            yield f"{prefix} input_encoding must be one of {sorted(_VALID_ENC)}"
        url = item.get("section_url", "")
        if isinstance(url, str) and not url.startswith("http"):
            yield f"{prefix} section_url must be an http(s) URL"
        if enc == "hex" and isinstance(item.get("input"), str):
            compact = "".join(item["input"].split())
            try:
                bytes.fromhex(compact)
            except ValueError:
                yield f"{prefix} input is not valid hex"
    _ = path
