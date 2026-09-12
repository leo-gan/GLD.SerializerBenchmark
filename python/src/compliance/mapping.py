"""Load compliance/serializer-standards.json — source of truth for runners and the dashboard."""

from __future__ import annotations

import json
from pathlib import Path

from .catalog import repo_root


def mapping_path() -> Path:
    return repo_root() / "compliance" / "serializer-standards.json"


def load_mapping() -> dict[str, dict[str, list[str]]]:
    path = mapping_path()
    raw = json.loads(path.read_text(encoding="utf-8"))
    languages = raw.get("languages") or {}
    out: dict[str, dict[str, list[str]]] = {}
    for lang, rows in languages.items():
        slice_: dict[str, list[str]] = {}
        for name, fmts in (rows or {}).items():
            slice_[str(name)] = [str(f) for f in (fmts or [])]
        out[str(lang)] = slice_
    return out


def allowed_pairs(language: str) -> set[tuple[str, str]]:
    pairs: set[tuple[str, str]] = set()
    for name, fmts in load_mapping().get(language, {}).items():
        for fmt in fmts:
            pairs.add((name, fmt))
    return pairs


def filter_adapters(language: str, adapters: list) -> list:
    allow = allowed_pairs(language)
    return [a for a in adapters if (a.name, a.format) in allow]
