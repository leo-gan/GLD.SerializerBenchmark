#!/usr/bin/env python3
"""Build the dashboard experiment catalog from experiments/*/ folders.

Independent of language-latest sync. A new experiment folder with
experiment.yaml appears automatically. A new or updated results.json
is copied into dashboard/public/data/experiments/.

Run:
    python3 dashboard/scripts/sync-experiments.py
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "gld.dashboard.experiments/1"
EXP_ID_RE = re.compile(r"^(\d+)-(.+)$")

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None


def _repo_paths():
    script_dir = Path(__file__).resolve().parent
    dashboard_dir = script_dir.parent
    repo_root = dashboard_dir.parent
    experiments_dir = repo_root / "experiments"
    out_dir = dashboard_dir / "public" / "data" / "experiments"
    return repo_root, experiments_dir, out_dir


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def _number_and_slug(exp_id: str, folder_name: str):
    for raw in (exp_id, folder_name):
        m = EXP_ID_RE.match(str(raw or ""))
        if m:
            return int(m.group(1)), m.group(2)
    return None, folder_name


def _load_yaml(path: Path) -> dict:
    if yaml is None:
        raise RuntimeError("PyYAML is required to read experiment.yaml")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}


def _lang_status(results: dict | None, cfg: dict) -> list[dict]:
    out = []
    if results and isinstance(results.get("languages"), dict):
        for lang_id, block in results["languages"].items():
            if not isinstance(block, dict):
                continue
            out.append(
                {
                    "id": lang_id,
                    "status": block.get("status") or "ok",
                    "rows": len(block.get("rows") or []),
                }
            )
        return out
    for row in cfg.get("languages") or []:
        if not isinstance(row, dict) or not row.get("id"):
            continue
        out.append(
            {
                "id": row["id"],
                "status": "planned" if row.get("enabled", True) else "disabled",
                "rows": 0,
            }
        )
    return out


def collect_experiments(experiments_dir: Path) -> list[dict]:
    items = []
    if not experiments_dir.is_dir():
        return items
    for folder in sorted(experiments_dir.iterdir()):
        if not folder.is_dir():
            continue
        yaml_path = folder / "experiment.yaml"
        if not yaml_path.is_file():
            continue
        try:
            cfg = _load_yaml(yaml_path)
        except Exception as exc:
            print(f"skip {folder.name}: {exc}", file=sys.stderr)
            continue
        exp_id = str(cfg.get("id") or folder.name)
        number, slug = _number_and_slug(exp_id, folder.name)
        results_name = "results.json"
        if isinstance(cfg.get("paths"), dict) and cfg["paths"].get("results"):
            results_name = str(cfg["paths"]["results"])
        results_path = folder / results_name
        results = None
        if results_path.is_file():
            try:
                results = json.loads(results_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                print(f"skip results {results_path}: {exc}", file=sys.stderr)
        sample = cfg.get("sample") if isinstance(cfg.get("sample"), dict) else {}
        if results and isinstance(results.get("sample"), dict):
            sample = {**sample, **results["sample"]}
        items.append(
            {
                "id": exp_id,
                "folder": folder.name,
                "number": number,
                "slug": slug,
                "title": cfg.get("title") or cfg.get("question") or exp_id,
                "question": cfg.get("question") or "",
                "has_results": bool(results),
                "payload": f"experiments/{exp_id}.json.gz" if results else None,
                "generated_at": (results or {}).get("generated_at"),
                "sample": {
                    "kind": sample.get("kind"),
                    "n": sample.get("n") or sample.get("records_per_write"),
                },
                "languages": _lang_status(results, cfg),
                "_results": results,
                "_results_path": results_path if results else None,
            }
        )
    items.sort(key=lambda x: (x["number"] is None, x["number"] or 0, x["id"]))
    return items


def sync_experiments(experiments_dir: Path | None = None, out_dir: Path | None = None) -> dict:
    if experiments_dir is None or out_dir is None:
        _, experiments_dir, out_dir = _repo_paths()
    out_dir.mkdir(parents=True, exist_ok=True)
    items = collect_experiments(experiments_dir)
    keep = {"index.json"}
    for item in items:
        results = item.pop("_results")
        results_path = item.pop("_results_path")
        if not results:
            continue
        dest = out_dir / f"{item['id']}.json.gz"
        raw = json.dumps(results, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        with gzip.open(dest, "wb") as fh:
            fh.write(raw)
        keep.add(dest.name)
        if results_path:
            item["source_bytes"] = results_path.stat().st_size
    catalog = {
        "schema": SCHEMA,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(items),
        "with_results": sum(1 for i in items if i["has_results"]),
        "experiments": items,
    }
    index_path = out_dir / "index.json"
    index_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    for stale in out_dir.iterdir():
        if stale.is_file() and stale.name not in keep and stale.suffix in {".gz", ".json"}:
            stale.unlink()
            print(f"removed stale {stale.name}")
    print(f"experiments catalog: {catalog['count']} folders, {catalog['with_results']} with results -> {index_path}")
    return catalog


def main() -> int:
    sync_experiments()
    return 0


if __name__ == "__main__":
    sys.exit(main())
