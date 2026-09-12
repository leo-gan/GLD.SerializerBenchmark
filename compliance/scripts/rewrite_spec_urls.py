#!/usr/bin/env python3
"""Rewrite known-dead spec URLs in catalogs (and optionally reports)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Exact document replacements (prefix match, longest first).
REPLACEMENTS = [
    (
        "https://github.com/betwixt-labs/bebop/blob/master/Specification.md",
        "https://github.com/6over3/bebop/wiki/Wire-format",
    ),
    (
        "https://github.com/6over3/bebop/blob/master/Specification.md",
        "https://github.com/6over3/bebop/wiki/Wire-format",
    ),
    (
        "https://amazon-ion.github.io/ion-docs/docs/ion-1-1/",
        "https://amazon-ion.github.io/ion-docs/books/ion-1-1/",
    ),
    (
        "https://amazon-ion.github.io/ion-docs/docs/ion-1-1",
        "https://amazon-ion.github.io/ion-docs/books/ion-1-1/",
    ),
    (
        "https://flatbuffers.dev/flatbuffers_internals/",
        "https://flatbuffers.dev/internals/",
    ),
    (
        "https://microsoft.github.io/bond/manual/bond_os.html",
        "https://microsoft.github.io/bond/manual/bond_cpp.html",
    ),
    (
        "https://github.com/ingydotnet/yaml-pegex-pm/blob/master/test/footer.tml",
        "https://yaml.org/spec/1.2.2/",
    ),
    (
        "https://github.com/ingydotnet/yaml-pegex-pm/blob/master/test/indent.tml",
        "https://yaml.org/spec/1.2.2/#61-indentation-spaces",
    ),
    (
        "https://github.com/ingydotnet/yaml-pegex-pm/blob/master/test/mapping.tml",
        "https://yaml.org/spec/1.2.2/#742-flow-mappings",
    ),
    (
        "https://github.com/ingydotnet/yaml-pegex-pm/blob/master/test/sequence.tml",
        "https://yaml.org/spec/1.2.2/#741-flow-sequences",
    ),
    (
        "https://github.com/ingydotnet/yaml-pegex-pm/blob/master/test/misc.tml",
        "https://yaml.org/spec/1.2.2/",
    ),
    (
        "https://github.com/yaml/pyyaml/blob/master/tests/data/construct-binary-py2.data",
        "https://yaml.org/spec/1.2.2/#83-block-scalars",
    ),
]


def rewrite_url(url: str) -> str:
    if not isinstance(url, str) or not url:
        return url
    cleaned = url.split()[0]  # drop " via @ingydotnet" and similar
    for old, new in REPLACEMENTS:
        if cleaned == old or cleaned.startswith(old):
            return new + cleaned[len(old) :]
    return cleaned


def walk(obj):
    changed = 0
    if isinstance(obj, dict):
        for key, val in list(obj.items()):
            if key in {"section_url", "standard_url"} and isinstance(val, str):
                new = rewrite_url(val)
                if new != val:
                    obj[key] = new
                    changed += 1
            else:
                changed += walk(val)
    elif isinstance(obj, list):
        for item in obj:
            changed += walk(item)
    return changed


def rewrite_file(path: Path) -> int:
    raw = json.loads(path.read_text(encoding="utf-8"))
    n = walk(raw)
    if n:
        ascii_ok = "logs" in path.parts
        text = json.dumps(raw, indent=2, ensure_ascii=ascii_ok) + "\n"
        blob = text.encode("utf-8", errors="surrogatepass")
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_bytes(blob)
        tmp.replace(path)
    return n


def main() -> None:
    roots = [ROOT / "compliance" / "data"]
    extra = sys.argv[1:]
    for item in extra:
        roots.append(Path(item).resolve())
    total = 0
    files = 0
    for root in roots:
        paths = [root] if root.is_file() else list(root.rglob("*.json"))
        for path in paths:
            if not path.is_file():
                continue
            n = rewrite_file(path)
            if n:
                try:
                    rel = path.relative_to(ROOT)
                except ValueError:
                    rel = path
                print(f"{n:4} {rel}")
                files += 1
                total += n
    print(f"rewrote {total} URLs in {files} files")


if __name__ == "__main__":
    main()
