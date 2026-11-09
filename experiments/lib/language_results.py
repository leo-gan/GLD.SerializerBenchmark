"""Where a saved experiment language block lives.

The experiment's results.json is the copy that is published. A language
folder used to store the same block again. Read the combined file. A
leftover <lang>/results.json counts only when that language is not in
the combined file yet.
"""

from __future__ import annotations

import json
from pathlib import Path


def load_language_blocks(experiment_dir: Path) -> dict[str, dict]:
    """Language id → block from <experiment>/results.json."""
    path = Path(experiment_dir) / "results.json"
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    langs = data.get("languages") if isinstance(data, dict) else None
    if not isinstance(langs, dict):
        return {}
    return {str(key): value for key, value in langs.items() if isinstance(value, dict)}


def saved_language(
    experiment_dir: Path,
    language: str,
    combined: dict[str, dict] | None = None,
) -> dict | None:
    """One saved block. The combined file wins when it has this language."""
    blocks = load_language_blocks(experiment_dir) if combined is None else combined
    block = blocks.get(language)
    if isinstance(block, dict):
        return block
    side = Path(experiment_dir) / language / "results.json"
    if not side.is_file():
        return None
    try:
        data = json.loads(side.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None
