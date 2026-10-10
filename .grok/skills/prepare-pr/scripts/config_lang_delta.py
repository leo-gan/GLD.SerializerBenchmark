#!/usr/bin/env python3
"""Classify an edit to config/benchmark_config.yaml.

Prints one line:

- ``FORCE_ALL`` when a shared key changed, or an existing language block
  changed or disappeared. Those edits can move numbers for languages that
  were already in the suite.
- A space-separated list of language ids that were added and nothing else.
  An empty line means the parsed documents select the same bench set
  (comments, key order, or an identical file).

The detector uses this so adding ``languages.fortran`` does not full-bench
C, Rust, and the rest.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml


def _shared_without_log_dirs(doc: dict[str, Any]) -> dict[str, Any]:
    """Shared keys, with paths.language_log_dirs removed.

    A new language also adds ``paths.language_log_dirs.<id>``. That line
    does not move numbers for languages that already exist. Every other
    shared key still does.
    """
    shared = {k: v for k, v in doc.items() if k != "languages"}
    paths = shared.get("paths")
    if isinstance(paths, dict) and "language_log_dirs" in paths:
        paths = {k: v for k, v in paths.items() if k != "language_log_dirs"}
        shared = dict(shared)
        shared["paths"] = paths
    return shared


def _log_dirs(doc: dict[str, Any]) -> dict[str, Any] | None:
    paths = doc.get("paths")
    if paths is None:
        return {}
    if not isinstance(paths, dict):
        return None
    dirs = paths.get("language_log_dirs", {})
    if dirs is None:
        return {}
    if not isinstance(dirs, dict):
        return None
    return dirs


def classify(old: Any, new: Any) -> list[str] | None:
    """Return added language ids, or None when every enabled language must run.

    None is the safe answer: unreadable documents, a shared-key edit, or a
    change to a language that already existed. Adding
    ``paths.language_log_dirs.<new-id>: logs/<new-id>`` is part of registering
    that language and is not a shared-key edit.
    """
    if not isinstance(old, dict) or not isinstance(new, dict):
        return None
    if _shared_without_log_dirs(old) != _shared_without_log_dirs(new):
        return None
    old_langs = old.get("languages") or {}
    new_langs = new.get("languages") or {}
    if not isinstance(old_langs, dict) or not isinstance(new_langs, dict):
        return None
    for lang_id, block in old_langs.items():
        if lang_id not in new_langs or new_langs[lang_id] != block:
            return None
    added = [str(lang_id) for lang_id in new_langs if lang_id not in old_langs]
    old_dirs = _log_dirs(old)
    new_dirs = _log_dirs(new)
    if old_dirs is None or new_dirs is None:
        return None
    for lang_id, path in old_dirs.items():
        if lang_id not in new_dirs or new_dirs[lang_id] != path:
            return None
    added_set = set(added)
    for lang_id, path in new_dirs.items():
        if lang_id in old_dirs:
            continue
        if lang_id not in added_set or path != f"logs/{lang_id}":
            return None
    return added


def _git_show(repo: Path, base: str, rel: str) -> str:
    proc = subprocess.run(
        ["git", "show", f"{base}:{rel}"],
        cwd=repo,
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git show failed for {rel}")
    return proc.stdout


def classify_repo(repo: Path, base: str, rel: str = "config/benchmark_config.yaml") -> list[str] | None:
    old_text = _git_show(repo, base, rel)
    new_path = repo / rel
    if not new_path.is_file():
        return None
    old = yaml.safe_load(old_text)
    new = yaml.safe_load(new_path.read_text(encoding="utf-8"))
    return classify(old, new)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, required=True)
    ap.add_argument("--base", required=True, help="Git tree-ish for the old file")
    args = ap.parse_args(argv)
    try:
        added = classify_repo(args.repo.resolve(), args.base)
    except Exception as exc:  # noqa: BLE001 — detector must fail closed
        print(f"[config_lang_delta] {exc}", file=sys.stderr)
        print("FORCE_ALL")
        return 0
    if added is None:
        print("FORCE_ALL")
    else:
        print(" ".join(added))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
