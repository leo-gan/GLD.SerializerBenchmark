#!/usr/bin/env python3
"""Link serializer names in language docs and insert Specifics subsections.

Reads config/serializer-sources.json. For each docs/<lang>/index.md:

1. In the Serializers table, turn every catalog name in the first column
   into a markdown link to source_url (keeps existing link targets if any).
2. Replace or insert a ### Specifics block (#### per serializer) just
   after that table.

    python3 scripts/apply-serializer-sources-to-docs.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "config" / "serializer-sources.json"

# dashboard language id → docs path
DOCS = {
    "python": ROOT / "docs" / "python" / "index.md",
    "go": ROOT / "docs" / "go" / "index.md",
    "java": ROOT / "docs" / "java" / "index.md",
    "javascript": ROOT / "docs" / "javascript" / "index.md",
    "csharp": ROOT / "docs" / "c-sharp" / "index.md",
    "rust": ROOT / "docs" / "rust" / "index.md",
    "c": ROOT / "docs" / "c" / "index.md",
    "cpp": ROOT / "docs" / "cpp" / "index.md",
    "kotlin": ROOT / "docs" / "kotlin" / "index.md",
    "php": ROOT / "docs" / "php" / "index.md",
    "swift": ROOT / "docs" / "swift" / "index.md",
    "zig": ROOT / "docs" / "zig" / "index.md",
    "mojo": ROOT / "docs" / "mojo" / "index.md",
}

HEADING_RE = re.compile(r"^## Serializers(?:\s+\(.*\))?\s*$", re.M)
TABLE_ROW_RE = re.compile(r"^\|(.+)\|\s*$", re.M)
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
BOLD_RE = re.compile(r"^\*\*(.+)\*\*$")


def load_catalog() -> dict:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return data.get("languages") or {}


def find_serializers_table(text: str) -> tuple[int, int, int] | None:
    """Return (heading_start, table_start, table_end) or None."""
    m = HEADING_RE.search(text)
    if not m:
        return None
    rest = text[m.end() :]
    # first markdown table after the heading
    lines = rest.splitlines(keepends=True)
    table_rel = None
    i = 0
    while i < len(lines):
        if lines[i].startswith("|"):
            table_rel = i
            break
        if lines[i].startswith("## "):
            return None
        i += 1
    if table_rel is None:
        return None
    j = table_rel
    while j < len(lines) and lines[j].startswith("|"):
        j += 1
    table_start = m.end() + sum(len(x) for x in lines[:table_rel])
    table_end = m.end() + sum(len(x) for x in lines[:j])
    return m.start(), table_start, table_end


def split_first_cell(row: str) -> tuple[str, str, str] | None:
    if not row.startswith("|"):
        return None
    # leading |, first cell, rest including the following |
    m = re.match(r"^(\|)([^|]*)(\|.*)$", row.rstrip("\n"))
    if not m:
        return None
    nl = "\n" if row.endswith("\n") else ""
    return m.group(1), m.group(2), m.group(3) + nl


def is_sep_row(cell: str) -> bool:
    return bool(re.fullmatch(r"[\s:-]+", cell or ""))


def link_fragment(raw: str, sources: dict[str, dict]) -> str:
    text = raw.strip()
    if not text:
        return raw
    # already a markdown link — keep label, retarget if we know the name
    lm = LINK_RE.fullmatch(text)
    if lm:
        label = lm.group(1)
        name = BOLD_RE.sub(r"\1", label)
        rec = sources.get(name)
        if rec:
            return f"[{label}]({rec['source_url']})"
        return text
    name = BOLD_RE.sub(r"\1", text)
    rec = sources.get(name)
    if rec:
        return f"[{text}]({rec['source_url']})"
    return text


def link_first_cell(cell: str, sources: dict[str, dict]) -> str:
    lead = re.match(r"^(\s*)(.*?)(\s*)$", cell)
    if not lead:
        return cell
    prefix, body, suffix = lead.group(1), lead.group(2), lead.group(3)
    if not body or is_sep_row(body):
        return cell
    # split on commas for grouped C-style cells
    parts = re.split(r"(\s*,\s*)", body)
    out = []
    for p in parts:
        if re.fullmatch(r"\s*,\s*", p) or p == "":
            out.append(p)
            continue
        out.append(link_fragment(p, sources))
    return prefix + "".join(out) + suffix


def render_specifics(lang: str, sources: dict[str, dict], table_names: list[str]) -> str:
    lines = ["### Specifics", ""]
    lines.append(
        "Why each library exists, what problem it was written to solve, "
        "and how. Names link to the source repository (or the stdlib / "
        "in-tree path this suite times). A version after the name is the "
        "last measured `SerializerVersion` from this suite's latest bench."
    )
    lines.append("")
    seen = set()
    ordered = []
    for n in table_names:
        if n in sources and n not in seen:
            ordered.append(n)
            seen.add(n)
    for n in sources:
        if n not in seen:
            # skip compliance-only extras that never appear in the language table
            continue
    for name in ordered:
        rec = sources[name]
        url = rec["source_url"]
        spec = rec.get("specifics") or ""
        ver = (rec.get("version") or "").strip()
        if ver:
            lines.append(f"#### [{name}]({url}) · `{ver}`")
        else:
            lines.append(f"#### [{name}]({url})")
        lines.append("")
        lines.append(spec.strip())
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def names_in_table(table: str, sources: dict[str, dict]) -> list[str]:
    names = []
    # longest first so "shamaton/msgpack (array)" wins over "shamaton/msgpack"
    keys = sorted(sources.keys(), key=len, reverse=True)
    for line in table.splitlines():
        sc = split_first_cell(line + "\n")
        if not sc:
            continue
        cell = sc[1]
        if is_sep_row(cell.strip()) or not cell.strip():
            continue
        i = 0
        while i < len(cell):
            hit = None
            for k in keys:
                if cell.startswith(k, i):
                    hit = k
                    break
            if hit:
                names.append(hit)
                i += len(hit)
            else:
                i += 1
    out = []
    seen = set()
    for n in names:
        if n not in seen:
            out.append(n)
            seen.add(n)
    return out


def strip_old_specifics(after_table: str) -> str:
    """Remove a previously generated ### Specifics section immediately after the table."""
    m = re.match(r"^\n*### Specifics\n.*?(?=\n### |\n## |\Z)", after_table, re.S)
    if not m:
        return after_table
    return after_table[m.end() :]


def patch_file(lang: str, path: Path, sources: dict[str, dict]) -> bool:
    text = path.read_text(encoding="utf-8")
    loc = find_serializers_table(text)
    if not loc:
        print(f"SKIP no Serializers table: {path}")
        return False
    _h, t0, t1 = loc
    table = text[t0:t1]
    new_rows = []
    header_done = False
    for line in table.splitlines(keepends=True):
        sc = split_first_cell(line)
        if not sc:
            new_rows.append(line)
            continue
        left, cell, rest = sc
        stripped = cell.strip()
        if is_sep_row(stripped):
            new_rows.append(line)
            header_done = True
            continue
        if not header_done:
            # header
            new_rows.append(line)
            continue
        new_rows.append(left + link_first_cell(cell, sources) + rest)
    new_table = "".join(new_rows)
    names = names_in_table(table, sources)
    specifics = render_specifics(lang, sources, names)
    after = strip_old_specifics(text[t1:])
    # keep a single blank line between table and Specifics
    if not after.startswith("\n"):
        after = "\n" + after
    new_text = text[:t0] + new_table + "\n" + specifics + after
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)} ({len(names)} specifics)")
        return True
    print(f"unchanged {path.relative_to(ROOT)}")
    return False


def main() -> int:
    languages = load_catalog()
    n = 0
    for lang, path in DOCS.items():
        if not path.exists():
            print(f"SKIP missing {path}")
            continue
        src = languages.get(lang) or {}
        if patch_file(lang, path, src):
            n += 1
    print(f"{n} files changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
