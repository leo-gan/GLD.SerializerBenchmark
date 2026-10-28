"""Splice calculated Kiln and Fortran Arrow rows into the dashboard payload.

Reads one JSON object per language from an outcomes directory. Each object
has language, serializer, serializer_version, and cases[{id, outcome,
observed, detail}]. Fortran Arrow sets ``format`` to ``arrow``; Kiln rows
use the Kiln catalog.

Patches logs/compliance/latest-<lang>.json when that file exists, dropping
only the rows this directory replaces. Run dashboard/scripts/sync-compliance.py
afterwards so the dashboard gzip is rebuilt from those reports.
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location(
    "sync_compliance",
    ROOT / "dashboard" / "scripts" / "sync-compliance.py",
)
sync_compliance = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sync_compliance)

CATALOGS = {
    "kiln": ROOT / "compliance" / "data" / "kiln" / "v2.json",
    "arrow": ROOT / "compliance" / "data" / "arrow" / "ipc-stream.json",
}
LOG_DIR = ROOT / "logs" / "compliance"


def _load_outcomes(directory: Path) -> list[dict]:
    docs = []
    for path in sorted(directory.glob("*.json")):
        doc = json.loads(path.read_text())
        if not isinstance(doc, dict) or "cases" not in doc:
            continue
        docs.append(doc)
    if not docs:
        raise SystemExit(f"no outcome files in {directory}")
    return docs


def _rows_for(doc: dict) -> list[dict]:
    fmt = str(doc.get("format") or "kiln")
    corpus = json.loads(CATALOGS[fmt].read_text())
    by_id = {case["id"]: case for case in corpus["cases"]}
    version = str(corpus.get("version") or "")
    rows = []
    seen = set()
    for item in doc["cases"]:
        case = by_id.get(item["id"])
        if case is None:
            raise SystemExit(f"{doc.get('language')} unknown case {item['id']}")
        seen.add(item["id"])
        rows.append(
            {
                "id": case["id"],
                "language": doc["language"],
                "serializer": doc["serializer"],
                "serializer_version": str(doc.get("serializer_version") or ""),
                "format": fmt,
                "standard": corpus.get("standard") or "",
                "standard_url": corpus.get("standard_url") or "",
                "version": version,
                "version_key": f"{fmt}.{version}",
                "requirement": case.get("requirement") or "",
                "expect": case.get("expect") or "",
                "section": case.get("section") or "",
                "section_title": case.get("section_title") or case.get("section") or "",
                "paragraph": case.get("paragraph") or "",
                "title": case.get("title") or "",
                "section_url": case.get("section_url") or "",
                "input": case.get("input") or "",
                "input_encoding": case.get("input_encoding") or "",
                "detail": str(item.get("detail") or ""),
                "observed": str(item.get("observed") or ""),
                "outcome": item["outcome"],
            }
        )
    missing = [case["id"] for case in corpus["cases"] if case["id"] not in seen]
    if missing:
        raise SystemExit(f"{doc.get('language')} {fmt} missing {len(missing)} cases, first {missing[0]}")
    return rows


def _targets(docs: list[dict]) -> set[tuple[str, str, str]]:
    out = set()
    for doc in docs:
        fmt = str(doc.get("format") or "kiln")
        out.add((str(doc["language"]), fmt, str(doc["serializer"])))
    return out


def _splice_results(results: list[dict], rows: list[dict], targets: set[tuple[str, str, str]]) -> list[dict]:
    kept = [
        row
        for row in results
        if (str(row.get("language") or ""), str(row.get("format") or ""), str(row.get("serializer") or ""))
        not in targets
    ]
    kept.extend(rows)
    return kept


def _counts(results: list[dict]) -> dict[str, int]:
    return {
        "passed": sum(1 for row in results if row.get("outcome") == "pass"),
        "failed": sum(1 for row in results if row.get("outcome") == "fail"),
        "skipped": sum(1 for row in results if row.get("outcome") == "skip"),
        "errors": sum(1 for row in results if row.get("outcome") not in ("pass", "fail", "skip")),
    }


# Languages whose gld-kiln 0.2.0 port was scored. A stale "no kiln adapter"
# line in that language's report would contradict the new rows. PHP has no
# Kiln library, so its miss stays.
_SCORED_KILN = {
    "c",
    "cpp",
    "csharp",
    "go",
    "java",
    "javascript",
    "python",
    "rust",
    "swift",
    "zig",
}
_KILN_MISS = {
    "no adapter registered for format kiln",
    "no adapter registered for format kiln (kiln wire v2 (v2))",
    "no adapter registered for format 'kiln' (kiln wire v2 (v2))",
    "gld-kiln/kiln",
}


def _clean_errors(errors: list, language: str) -> list:
    if language not in _SCORED_KILN:
        return list(errors or [])
    kept = []
    for err in errors or []:
        text = str(err).strip()
        low = text.lower()
        if low in _KILN_MISS:
            continue
        if "gld-kiln" in low and "adapter" in low:
            continue
        kept.append(err)
    return kept


def _patch_latest(language: str, rows: list[dict], targets: set[tuple[str, str, str]]) -> None:
    path = LOG_DIR / f"latest-{language}.json"
    if not path.is_file():
        print(f"no {path.name}; skip latest patch")
        return
    raw = json.loads(path.read_bytes().decode("utf-8", errors="surrogatepass"))
    results = raw.get("results") if isinstance(raw.get("results"), list) else []
    lang_rows = [row for row in rows if row["language"] == language]
    lang_targets = {key for key in targets if key[0] == language}
    raw["results"] = _splice_results(results, lang_rows, lang_targets)
    raw.pop("matrix", None)
    raw.update(_counts(raw["results"]))
    if "serializer_errors" in raw:
        raw["serializer_errors"] = _clean_errors(raw.get("serializer_errors") or [], language)
    path.write_text(
        json.dumps(sync_compliance._sanitize(raw), ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def publish(directory: Path) -> dict[str, tuple[int, int]]:
    """Patch latest-<lang>.json. The caller runs sync-compliance.py afterwards."""
    docs = _load_outcomes(directory)
    rows: list[dict] = []
    for doc in docs:
        rows.extend(_rows_for(doc))
    targets = _targets(docs)
    by_lang: dict[str, list[dict]] = {}
    for row in rows:
        by_lang.setdefault(row["language"], []).append(row)
    for language in by_lang:
        _patch_latest(language, rows, targets)
    summary = {}
    for doc in docs:
        summary[f"{doc['language']}:{doc['serializer']}"] = (
            sum(1 for case in doc["cases"] if case["outcome"] == "pass"),
            sum(1 for case in doc["cases"] if case["outcome"] != "pass"),
        )
    return summary


def main() -> int:
    directory = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/kiln-scores")
    summary = publish(directory)
    for name, (passed, failed) in sorted(summary.items()):
        print(f"{name}: {passed} pass, {failed} fail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
