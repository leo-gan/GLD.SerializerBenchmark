"""Publish the Compliance roster: serializer name to version, per language.

The page used to download every stats_<lang>_latest.json.gz (tens of megabytes
of measurements) to read those two fields. This file is that map and nothing else.
"""

from __future__ import annotations

import json
from pathlib import Path


def versions_from_stats(stats: dict) -> dict[str, str]:
    """First SerializerVersion for each SerializerName, in group order."""
    out: dict[str, str] = {}
    for group in stats.get("groups") or []:
        name = group.get("serializer")
        if not name or name in out:
            continue
        version = group.get("serializer_version")
        out[str(name)] = str(version) if version else ""
    return out


def note_stats_file(path, stats: dict) -> None:
    """Update the roster when a stats_<lang>_latest.json.gz file is written."""
    name = Path(path).name
    prefix, suffix = "stats_", "_latest.json.gz"
    if not (name.startswith(prefix) and name.endswith(suffix)):
        return
    save_language_versions(Path(path).parent, name[len(prefix) : -len(suffix)], stats)


def save_language_versions(data_dir, lang: str, stats: dict | None) -> None:
    """Replace one language in bench-versions.json. No stats drops the language."""
    directory = Path(data_dir)
    path = directory / "bench-versions.json"
    current: dict = {}
    if path.is_file():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            loaded = None
        if isinstance(loaded, dict):
            current = loaded
    if stats and stats.get("groups"):
        current[lang] = versions_from_stats(stats)
    else:
        current.pop(lang, None)
    ordered = {key: current[key] for key in sorted(current)}
    path.write_text(json.dumps(ordered, separators=(",", ":")) + "\n", encoding="utf-8")
