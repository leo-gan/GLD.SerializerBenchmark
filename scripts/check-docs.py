#!/usr/bin/env python3
"""Lightweight documentation quality gate for MkDocs content.

Checks public Markdown files under docs/ (excluding docs/internal/ and
docs/dashboard/) plus mkdocs.yml navigation and redirect targets using only
the Python standard library.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
MKDOCS = ROOT / "mkdocs.yml"

PROHIBITED_PROSE_RE = re.compile(r"\b(fixtures?|harnesses?|first-year)\b", re.IGNORECASE)
PROSE_EXEMPT = {Path("analysis/terminology.md")}
HEADING_RE = re.compile(r"^(#{1,6})\s+\S")
FN_DEF_RE = re.compile(r"^\[\^([^\]]+)\]:", re.MULTILINE)
FN_REF_RE = re.compile(r"\[\^([^\]]+)\](?!:)")


def iter_public_markdown() -> list[Path]:
    files: list[Path] = []
    for p in sorted(DOCS.rglob("*.md")):
        rel = p.relative_to(DOCS)
        if rel.parts[0] in {"internal", "dashboard"}:
            continue
        files.append(p)
    return files


def strip_code_blocks(text: str) -> str:
    return re.sub(r"```.*?```", "", text, flags=re.DOTALL)


def strip_prose_noise(text: str) -> str:
    s = strip_code_blocks(text)
    s = re.sub(r"`[^`\n]+`", "", s)
    s = re.sub(r"\]\([^)]+\)", "]()", s)
    s = re.sub(r"\{#[^}]+\}", "", s)
    return s


def check_markdown(path: Path) -> list[str]:
    rel = path.relative_to(DOCS)
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []

    if "wikipedia.png" in text:
        errors.append(f"{rel}: contains hotlinked wikipedia.png")

    if rel not in PROSE_EXEMPT:
        prose = strip_prose_noise(text)
        hits = sorted({m.group(1).lower() for m in PROHIBITED_PROSE_RE.finditer(prose)})
        if hits:
            errors.append(f"{rel}: prohibited prose term(s) {hits}")

    no_code = strip_code_blocks(text)
    fn_defs = set(FN_DEF_RE.findall(no_code))
    fn_refs = set(FN_REF_RE.findall(no_code))
    if fn_defs != fn_refs:
        errors.append(
            f"{rel}: footnote mismatch (defined={sorted(fn_defs)}, referenced={sorted(fn_refs)})"
        )

    math_scan = re.sub(r"`[^`\n]+`", "", no_code)
    math_scan = re.sub(r"\\\$", "", math_scan)
    math_scan = re.sub(r"\$\$.*?\$\$", "", math_scan, flags=re.DOTALL)
    if math_scan.count("$") % 2 != 0:
        errors.append(f"{rel}: unbalanced single '$' math delimiter")

    in_code = False
    prev_level = 0
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.strip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = HEADING_RE.match(line)
        if m:
            level = len(m.group(1))
            if prev_level and level > prev_level + 1:
                errors.append(
                    f"{rel}:{lineno}: heading level jumps from H{prev_level} to H{level}"
                )
            prev_level = level

    return errors


def check_mkdocs_paths() -> list[str]:
    errors: list[str] = []
    text = MKDOCS.read_text(encoding="utf-8")

    # Verify redirect_maps destinations exist under docs/
    for m in re.finditer(r"^\s*'[^']+\.md':\s*'([^']+\.md)'\s*$", text, re.MULTILINE):
        dst = m.group(1)
        if not (DOCS / dst).is_file():
            errors.append(f"mkdocs.yml: redirect target missing: docs/{dst}")

    # Verify nav .md entries exist under docs/
    in_nav = False
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.startswith("nav:"):
            in_nav = True
            continue
        if not in_nav:
            continue
        m = re.search(r"(?::\s+|-\s+)([A-Za-z0-9_./-]+\.md)\s*$", line)
        if m:
            rel_path = m.group(1)
            if not (DOCS / rel_path).is_file():
                errors.append(f"mkdocs.yml:{lineno}: nav page missing: docs/{rel_path}")

    return errors


def main() -> int:
    files = iter_public_markdown()
    errors: list[str] = []
    for p in files:
        errors.extend(check_markdown(p))
    errors.extend(check_mkdocs_paths())

    if errors:
        print(f"check-docs: {len(errors)} issue(s) found across {len(files)} markdown files:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"check-docs: OK ({len(files)} public markdown files + mkdocs.yml verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
