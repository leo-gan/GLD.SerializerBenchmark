#!/usr/bin/env python3
"""Author config/serializer-sources.json and the dashboard symlink.

Each registered serializer gets a source URL (GitHub / stdlib tree / this
repo for in-tree baselines), the last measured SerializerVersion from the
latest bench JSON, and a short origin paragraph: why the library exists,
what problem it solved, and how.

The compliance catalog supplies the registered (language, name) list, and
config/serializer-specifics.json supplies URL overrides and origin text.
Versions are filled from dashboard/public/data/<lang>_latest.json.gz.

    python3 dashboard/scripts/write-serializer-sources.py
"""
from __future__ import annotations

import copy
import gzip
import importlib.util
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = Path(__file__).resolve().parent
SPECIFICS_JSON = ROOT / "config" / "serializer-specifics.json"
CONFIG_OUT = ROOT / "config" / "serializer-sources.json"
DASH_OUT = ROOT / "dashboard" / "public" / "data" / "serializer-sources.json"

GITHUB_RE = re.compile(r"https?://github\.com/([^/]+)/([^/#?]+)")
CODEBERG_RE = re.compile(r"https?://codeberg\.org/([^/]+)/([^/#?]+)")


def _split_key(key: str) -> tuple[str, str]:
    lang, name = key.split("/", 1)
    return lang, name


def _load_specifics_config() -> tuple[
    dict[tuple[str, str], str],
    list[tuple[str, str, str]],
    dict[tuple[str, str], str],
    dict[str, str],
    dict[tuple[str, str], str],
]:
    raw = json.loads(SPECIFICS_JSON.read_text(encoding="utf-8"))
    url_override = {_split_key(k): str(v) for k, v in (raw.get("url_override") or {}).items()}
    extra_rows = [(str(r[0]), str(r[1]), str(r[2])) for r in (raw.get("extra_rows") or [])]
    spec_key = {_split_key(k): str(v) for k, v in (raw.get("spec_key") or {}).items()}
    specifics = {str(k): str(v) for k, v in (raw.get("specifics") or {}).items()}
    extra = {_split_key(k): str(v) for k, v in (raw.get("extra") or {}).items()}
    return url_override, extra_rows, spec_key, specifics, extra


URL_OVERRIDE, EXTRA_ROWS, SPEC_KEY, SPECIFICS, EXTRA = _load_specifics_config()


def _load_compliance_catalog():
    path = SCRIPTS / "write-compliance-catalog.py"
    spec = importlib.util.spec_from_file_location("write_compliance_catalog", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return list(mod.CATALOG)


def _repo_root_from_url(url: str) -> str | None:
    m = GITHUB_RE.search(url)
    if m:
        owner, repo = m.group(1), m.group(2)
        if repo.endswith(".git"):
            repo = repo[:-4]
        if "/tree/" in url or "/blob/" in url:
            return url.split("#")[0].rstrip("/")
        return f"https://github.com/{owner}/{repo}"
    m = CODEBERG_RE.search(url)
    if m:
        owner, repo = m.group(1), m.group(2)
        if repo.endswith(".git"):
            repo = repo[:-4]
        return f"https://codeberg.org/{owner}/{repo}"
    return None


def load_measured_versions() -> dict[tuple[str, str], str]:
    """Map (language, SerializerName) → SerializerVersion from latest benches."""
    out: dict[tuple[str, str], str] = {}
    data_dir = ROOT / "dashboard" / "public" / "data"
    for path in sorted(data_dir.glob("*_latest.json.gz")):
        stem = path.name.removesuffix("_latest.json.gz")
        try:
            payload = json.loads(gzip.open(path).read())
        except (OSError, json.JSONDecodeError) as exc:
            print(f"WARN skip versions in {path.name}: {exc}", file=sys.stderr)
            continue
        if stem.startswith("stats_"):
            lang = stem.removeprefix("stats_")
            groups = payload.get("groups") or []
        else:
            lang = stem
            groups = (payload.get("stats") or {}).get("groups") or []
            items = ((payload.get("configs") or {}).get("serializers") or {}).get("items") or []
            for it in items:
                name = it.get("name")
                ver = it.get("version")
                if name and ver:
                    out[(lang, str(name))] = str(ver)
        for g in groups:
            name = g.get("serializer")
            ver = g.get("serializer_version")
            if name and ver:
                out.setdefault((lang, str(name)), str(ver))
    return out


def source_url(lang: str, name: str, docs: str) -> str:
    if (lang, name) in URL_OVERRIDE:
        return URL_OVERRIDE[(lang, name)]
    repo = _repo_root_from_url(docs)
    if repo:
        return repo
    return docs


def specifics_text(lang: str, name: str) -> str:
    key = SPEC_KEY.get((lang, name))
    base = SPECIFICS.get(key or "", "")
    extra = EXTRA.get((lang, name), "")
    parts = [p for p in (base, extra) if p]
    if parts:
        return " ".join(parts)
    return (
        f"{name} is a registered serializer in the {lang} suite. "
        "This page links its upstream source; the language inventory table "
        "describes the timed call path."
    )


def _record(lang: str, name: str, docs: str, versions: dict[tuple[str, str], str]) -> dict[str, str]:
    rec = {"source_url": source_url(lang, name, docs)}
    ver = versions.get((lang, name))
    if ver:
        rec["version"] = ver
    rec["specifics"] = specifics_text(lang, name)
    return rec


def build() -> dict:
    versions = load_measured_versions()
    languages: dict[str, dict[str, dict[str, str]]] = defaultdict(dict)
    for lang, name, _formats, docs, _evidence in _load_compliance_catalog():
        languages[lang][name] = _record(lang, name, docs, versions)
    for lang, name, url in EXTRA_ROWS:
        languages[lang].setdefault(name, _record(lang, name, url, versions))
    missing_keys = []
    n_ver = 0
    for lang, items in languages.items():
        for name, rec in items.items():
            if rec["specifics"].startswith(f"{name} is a registered"):
                missing_keys.append(f"{lang}/{name}")
            if rec.get("version"):
                n_ver += 1
    if missing_keys:
        print("WARN fallback specifics:", ", ".join(missing_keys), file=sys.stderr)
    print(f"attached SerializerVersion to {n_ver} / {sum(len(v) for v in languages.values())} rows")
    return {
        "version": 1,
        "description": (
            "Source repository (or stdlib / in-tree path), last measured "
            "SerializerVersion from the latest bench, and origin text for "
            "every registered serializer. Dashboard name links and "
            "docs/<lang>/index.md Specifics are generated from this file."
        ),
        "languages": {k: dict(sorted(v.items())) for k, v in sorted(languages.items())},
    }


def dumps_serializer_sources(data: dict) -> str:
    """Format serializer-sources.json with 2-space outer indent and one line per serializer."""
    clone = copy.deepcopy(data)
    inline: dict[str, str] = {}
    idx = 0
    for _lang, items in (clone.get("languages") or {}).items():
        if not isinstance(items, dict):
            continue
        for name, rec in list(items.items()):
            tok = f"__SER_{idx}__"
            idx += 1
            inline[f'"{tok}"'] = json.dumps(rec, separators=(",", ":"), ensure_ascii=False)
            items[name] = tok
    out = json.dumps(clone, indent=2, ensure_ascii=False)
    for k, v in inline.items():
        out = out.replace(k, v)
    return out + "\n"


def ensure_dashboard_symlink() -> None:
    DASH_OUT.parent.mkdir(parents=True, exist_ok=True)
    rel_target = os.path.relpath(CONFIG_OUT, DASH_OUT.parent)
    if DASH_OUT.is_symlink() and os.readlink(DASH_OUT) == rel_target:
        return
    if DASH_OUT.exists() or DASH_OUT.is_symlink():
        DASH_OUT.unlink()
    DASH_OUT.symlink_to(rel_target)


def main() -> int:
    data = build()
    text = dumps_serializer_sources(data)
    CONFIG_OUT.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_OUT.write_text(text, encoding="utf-8")
    ensure_dashboard_symlink()
    n = sum(len(v) for v in data["languages"].values())
    print(f"wrote {n} serializers → {CONFIG_OUT.relative_to(ROOT)} (symlinked at {DASH_OUT.relative_to(ROOT)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
