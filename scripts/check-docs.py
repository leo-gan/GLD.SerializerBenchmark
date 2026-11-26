#!/usr/bin/env python3
"""Lightweight documentation quality gate for MkDocs content.

Checks public Markdown files under docs/ (excluding docs/internal/ and
docs/dashboard/), language roster parity against packed Dashboard stats,
and mkdocs.yml navigation/redirect targets using only the Python standard
library.
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
MKDOCS = ROOT / "mkdocs.yml"
DASH_DATA = ROOT / "dashboard" / "public" / "data"

LANG_DIRS = {
    "c": "c",
    "c-sharp": "csharp",
    "cpp": "cpp",
    "fortran": "fortran",
    "go": "go",
    "java": "java",
    "javascript": "javascript",
    "kotlin": "kotlin",
    "mojo": "mojo",
    "php": "php",
    "python": "python",
    "rust": "rust",
    "swift": "swift",
    "zig": "zig",
}

PROHIBITED_PROSE_RE = re.compile(
    r"\b(fixtures?|harnesses?|first-year|introductory computer science|homework assignment)\b",
    re.IGNORECASE,
)
PROSE_EXEMPT = {Path("analysis/terminology.md")}
HEADING_RE = re.compile(r"^(#{1,6})\s+\S")
FN_DEF_RE = re.compile(r"^\[\^([^\]]+)\]:", re.MULTILINE)
FN_REF_RE = re.compile(r"\[\^([^\]]+)\](?!:)")
REL_MD_LINK_RE = re.compile(r"\]\(([^)#\s]+\.md)(?:#[^)\s]*)?\)")
STUB_RE = re.compile(r"is a registered serializer in the \w+ suite", re.IGNORECASE)
WIKI_ENFORCED_ROOTS = set(LANG_DIRS) | {"analysis", "languages"}


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

    if STUB_RE.search(text):
        errors.append(f"{rel}: contains stub placeholder specifics text")

    if "prepare(fixture)" in text:
        errors.append(f"{rel}: contains deprecated 'prepare(fixture)' pseudocode")

    if rel.parts[0] in WIKI_ENFORCED_ROOTS and "en.wikipedia.org" in text:
        errors.append(f"{rel}: contains en.wikipedia.org link (use primary references)")

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

    # Verify relative internal .md links exist on disk
    for m in REL_MD_LINK_RE.finditer(no_code):
        href = m.group(1)
        if href.startswith(("http://", "https://", "/")):
            continue
        target = (path.parent / href).resolve()
        if not target.is_file():
            errors.append(f"{rel}: broken relative link -> {href}")

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


def check_language_rosters() -> list[str]:
    errors: list[str] = []
    for doc_dir, lang_id in sorted(LANG_DIRS.items()):
        page = DOCS / doc_dir / "index.md"
        if not page.is_file():
            errors.append(f"docs/{doc_dir}/index.md: missing language overview page")
            continue
        text = page.read_text(encoding="utf-8")

        # Self-referential source URL check
        if f"blob/master/docs/{doc_dir}/index.md" in text:
            errors.append(f"{doc_dir}/index.md: serializer link self-references docs/{doc_dir}/index.md")

        # Roster parity against live packed Dashboard stats
        stats_path = DASH_DATA / f"stats_{lang_id}_latest.json.gz"
        if not stats_path.is_file():
            continue
        payload = json.loads(gzip.open(stats_path).read())
        published = {g["serializer"] for g in payload.get("groups") or [] if g.get("serializer")}
        doc_names = set(re.findall(r"^\| \[([^\]]+)\]\(", text, re.M))
        missing = sorted(published - doc_names)
        if missing:
            errors.append(f"{doc_dir}/index.md: published serializer(s) missing from table: {missing}")

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
    errors.extend(check_language_rosters())
    errors.extend(check_mkdocs_paths())

    if errors:
        print(f"check-docs: {len(errors)} issue(s) found across {len(files)} markdown files:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"check-docs: OK ({len(files)} public markdown files + 14 language rosters + mkdocs.yml verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
