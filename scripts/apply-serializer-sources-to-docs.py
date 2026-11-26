#!/usr/bin/env python3
"""Link serializer names in language docs and insert grouped provenance notes.

Reads config/serializer-sources.json and config/serializer-specifics.json.
For each docs/<lang>/index.md:

1. In the Registered Serializers (or Serializers) table, turn every catalog
   name in the first column into a markdown link to source_url.
2. Replace or insert a collapsible `??? note "Library background & provenance"`
   block just after that table, grouped by shared library family (`spec_key`)
   with no H4 headings so the right-hand TOC stays clean.

    python3 scripts/apply-serializer-sources-to-docs.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "config" / "serializer-sources.json"
SPECIFICS_CFG = ROOT / "config" / "serializer-specifics.json"

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
    "fortran": ROOT / "docs" / "fortran" / "index.md",
}

HEADING_RE = re.compile(r"^## (?:Registered )?Serializers(?:\s+\(.*\))?\s*$", re.M)
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
BOLD_RE = re.compile(r"^\*\*(.+)\*\*$")


def load_catalog() -> dict:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return data.get("languages") or {}


def load_specifics_cfg() -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    if not SPECIFICS_CFG.exists():
        return {}, {}, {}
    raw = json.loads(SPECIFICS_CFG.read_text(encoding="utf-8"))
    return (
        raw.get("spec_key") or {},
        raw.get("specifics") or {},
        raw.get("extra") or {},
    )


def find_serializers_table(text: str) -> tuple[int, int, int] | None:
    """Return (heading_start, table_start, table_end) or None."""
    m = HEADING_RE.search(text)
    if not m:
        return None
    rest = text[m.end() :]
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
    parts = re.split(r"(\s*,\s*)", body)
    out = []
    for p in parts:
        if re.fullmatch(r"\s*,\s*", p) or p == "":
            out.append(p)
            continue
        out.append(link_fragment(p, sources))
    return prefix + "".join(out) + suffix


def render_provenance(
    lang: str,
    sources: dict[str, dict],
    table_names: list[str],
    spec_keys: dict[str, str],
    base_specifics: dict[str, str],
    extras: dict[str, str],
) -> str:
    seen: set[str] = set()
    ordered: list[str] = []
    for n in table_names:
        if n in sources and n not in seen:
            ordered.append(n)
            seen.add(n)

    # Group serializers sharing the same spec_key and base description while
    # preserving first-seen table order.
    grouped: list[dict] = []
    group_idx: dict[tuple[str, str], int] = {}

    for name in ordered:
        rec = sources[name]
        url = rec["source_url"]
        full_k = f"{lang}/{name}"
        sk = spec_keys.get(full_k)
        base = base_specifics.get(sk, "").strip() if sk else ""
        extra = extras.get(full_k, "").strip()
        full_spec = (rec.get("specifics") or "").strip()

        if sk and base:
            gkey = ("key", sk)
            if gkey in group_idx:
                g = grouped[group_idx[gkey]]
                g["members"].append((name, url, extra))
            else:
                group_idx[gkey] = len(grouped)
                grouped.append(
                    {
                        "base": base,
                        "members": [(name, url, extra)],
                    }
                )
        else:
            gkey = ("exact", f"{url}\0{full_spec}")
            if gkey in group_idx:
                grouped[group_idx[gkey]]["members"].append((name, url, ""))
            else:
                group_idx[gkey] = len(grouped)
                grouped.append(
                    {
                        "base": full_spec,
                        "members": [(name, url, "")],
                    }
                )

    lines = [
        '??? note "Library background & provenance"',
        "",
        "    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.",
        "",
    ]

    for g in grouped:
        members: list[tuple[str, str, str]] = g["members"]
        base_text: str = g["base"]
        if len(members) == 1:
            name, url, extra = members[0]
            body = f"{base_text} {extra}".strip() if extra else base_text
            lines.append(f"    - **[{name}]({url})** — {body}")
        else:
            # Multi-variant family: emit shared base once, plus compact sub-bullets
            # only for variants that carry distinct extra notes.
            heading = ", ".join(f"**[{n}]({u})**" for n, u, _ in members)
            lines.append(f"    - {heading} — {base_text}")
            distinct_extras = [(n, e) for n, _, e in members if e]
            unique_extra_texts = {e for _, e in distinct_extras}
            if len(unique_extra_texts) == 1 and len(distinct_extras) == len(members):
                # Every member has the exact same extra note — append once.
                lines[-1] = f"    - {heading} — {base_text} {distinct_extras[0][1]}".rstrip()
            elif distinct_extras:
                for n, e in distinct_extras:
                    lines.append(f"        - `{n}`: {e}")

    return "\n".join(lines).rstrip() + "\n"


def names_in_table(table: str, sources: dict[str, dict]) -> list[str]:
    names = []
    keys = sorted(sources.keys(), key=len, reverse=True)
    for line in table.splitlines():
        sc = split_first_cell(line + "\n")
        if not sc:
            continue
        cell = sc[1]
        if is_sep_row(cell.strip()) or not cell.strip():
            continue
        # Strip markdown links in first cell so we match labels, not URLs
        clean = LINK_RE.sub(r"\1", cell)
        clean = clean.replace("**", "")
        i = 0
        while i < len(clean):
            hit = None
            for k in keys:
                if clean.startswith(k, i):
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


def strip_old_blocks(after_table: str) -> str:
    """Remove generated ### Specifics or ??? note provenance blocks after the table."""
    s = re.sub(
        r"\n*### Specifics\n.*?(?=\n### |\n## |\Z)",
        "\n",
        after_table,
        flags=re.S,
    )
    s = re.sub(
        r'\n*\?\?\? note "Library background & provenance"\n(?:[ \t]+.*|\s*)*(?=\n[^\s]|\Z)',
        "\n",
        s,
    )
    return s


def patch_file(
    lang: str,
    path: Path,
    sources: dict[str, dict],
    spec_keys: dict[str, str],
    base_specifics: dict[str, str],
    extras: dict[str, str],
) -> bool:
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
            new_rows.append(line)
            continue
        new_rows.append(left + link_first_cell(cell, sources) + rest)
    new_table = "".join(new_rows)
    names = names_in_table(table, sources)
    provenance = render_provenance(lang, sources, names, spec_keys, base_specifics, extras)
    after = strip_old_blocks(text[t1:])
    after = "\n" + after.lstrip("\n") if after.strip() else ""
    new_text = text[:t0] + new_table + "\n" + provenance + after
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)} ({len(names)} libraries)")
        return True
    print(f"unchanged {path.relative_to(ROOT)}")
    return False


def main() -> int:
    languages = load_catalog()
    spec_keys, base_specifics, extras = load_specifics_cfg()
    n = 0
    for lang, path in DOCS.items():
        if not path.exists():
            print(f"SKIP missing {path}")
            continue
        src = languages.get(lang) or {}
        if patch_file(lang, path, src, spec_keys, base_specifics, extras):
            n += 1
    print(f"{n} files changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
