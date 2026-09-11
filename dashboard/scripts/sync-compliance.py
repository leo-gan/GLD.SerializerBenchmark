#!/usr/bin/env python3
"""Copy the latest full compliance report into the dashboard payload.

Reads ``logs/compliance/latest.json`` when present (written by an unfiltered
``./scripts/run-compliance.sh``). Otherwise uses the newest timestamped file.

Writes ``dashboard/public/data/compliance.json`` for the Dashboard Compliance view.

Run:
    python3 dashboard/scripts/sync-compliance.py
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


SCHEMA = "gld.dashboard.compliance/1"
SCOPE_NOTE = (
    "Official parse suites (MIT/BSD/Apache) plus original extras: "
    "JSONTestSuite, yaml-test-suite, toml-test, msgpack-test-suite, "
    "cbor-wg, ion-tests, apache/avro test_io. Schema formats expanded "
    "to the published encoding rules. XML is out of scope. "
    "Language-native / private binaries have no public spec column."
)


def _paths() -> tuple[Path, Path, Path]:
    dashboard = Path(__file__).resolve().parents[1]
    repo = dashboard.parent
    return repo, repo / "logs" / "compliance", dashboard / "public" / "data" / "compliance.json"


def merge_reports(reports: list[dict]) -> dict:
    """Combine per-language reports into one Dashboard payload."""
    if not reports:
        raise ValueError("no reports to merge")
    if len(reports) == 1:
        return reports[0]
    results: list[dict] = []
    catalog_errors: list[str] = []
    serializer_errors: list[str] = []
    langs: list[str] = []
    for raw in reports:
        lang = str(raw.get("language") or "python")
        langs.append(lang)
        results.extend(_normalize_results(raw.get("results") if isinstance(raw.get("results"), list) else [], lang))
        catalog_errors.extend(raw.get("catalog_errors") or [])
        serializer_errors.extend(raw.get("serializer_errors") or raw.get("adapter_errors") or [])
    langs = sorted(set(langs))
    passed = sum(1 for r in results if r.get("outcome") == "pass")
    failed = sum(1 for r in results if r.get("outcome") == "fail")
    skipped = sum(1 for r in results if r.get("outcome") == "skip")
    errors = sum(1 for r in results if r.get("outcome") not in ("pass", "fail", "skip"))
    return {
        "schema": SCHEMA,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "language": langs[0] if len(langs) == 1 else "all",
        "languages": langs,
        "policy": "report-only",
        "scope": {
            "formats": sorted({str(r.get("format") or "") for r in results if r.get("format")}),
            "note": SCOPE_NOTE,
        },
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "errors": errors,
        "catalog_errors": catalog_errors,
        "serializer_errors": serializer_errors,
        "matrix": _matrix_from_results(results, langs[0] if langs else "python"),
        "results": results,
    }


def _pick_sources(log_dir: Path) -> list[Path]:
    named = []
    for lang in ("python", "javascript", "go", "rust", "java", "csharp", "cpp", "c"):
        p = log_dir / f"latest-{lang}.json"
        if p.is_file() and p.stat().st_size > 0:
            named.append(p)
    if named:
        return named
    latest = log_dir / "latest.json"
    if latest.is_file() and latest.stat().st_size > 0:
        return [latest]
    stamped = sorted(
        (p for p in log_dir.glob("*.json") if p.name != "latest.json"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return stamped[:1] if stamped else []


def _serializer(row: dict) -> str:
    return str(row.get("serializer") or row.get("adapter") or "")


def _language(row: dict, default: str = "python") -> str:
    return str(row.get("language") or default)


def _matrix_from_results(results: list[dict], default_lang: str = "python") -> list[dict]:
    cells: dict[tuple[str, str, str, str, str], dict] = {}
    for row in results:
        lang = _language(row, default_lang)
        ser = _serializer(row)
        fmt = str(row.get("format") or "")
        ver = str(row.get("version") or "")
        key = (lang, fmt, str(row.get("standard") or ""), ver, ser)
        cell = cells.setdefault(
            key,
            {
                "language": lang,
                "format": fmt,
                "standard": str(row.get("standard") or ""),
                "standard_url": str(row.get("standard_url") or ""),
                "version": ver,
                "version_key": str(row.get("version_key") or f"{fmt}.{ver}"),
                "serializer": ser,
                "serializer_version": str(row.get("serializer_version") or ""),
                "passed": 0,
                "failed": 0,
                "skipped": 0,
                "errors": 0,
                "total": 0,
            },
        )
        cell["total"] += 1
        outcome = row.get("outcome")
        if outcome == "pass":
            cell["passed"] += 1
        elif outcome == "fail":
            cell["failed"] += 1
        elif outcome == "skip":
            cell["skipped"] += 1
        else:
            cell["errors"] += 1
    out = []
    for cell in cells.values():
        judged = cell["passed"] + cell["failed"]
        cell["pass_rate"] = (cell["passed"] / judged) if judged else None
        out.append(cell)
    out.sort(key=lambda c: (c["language"], c["format"], c["standard"], c["version"], c["serializer"]))
    return out


def _normalize_results(results: list[dict], default_lang: str) -> list[dict]:
    out = []
    for row in results:
        if not isinstance(row, dict):
            continue
        item = dict(row)
        item["language"] = _language(item, default_lang)
        item["serializer"] = _serializer(item)
        fmt = str(item.get("format") or "")
        ver = str(item.get("version") or "")
        item["version_key"] = str(item.get("version_key") or f"{fmt}.{ver}")
        out.append(item)
    return out


def build_payload(raw: dict, source_name: str) -> dict:
    default_lang = raw.get("language") or "python"
    results = _normalize_results(
        raw.get("results") if isinstance(raw.get("results"), list) else [],
        default_lang,
    )
    langs = sorted({str(r.get("language") or default_lang) for r in results})
    matrix = raw.get("matrix") if isinstance(raw.get("matrix"), list) else None
    if matrix:
        for cell in matrix:
            if isinstance(cell, dict):
                cell.setdefault("language", default_lang)
                if "serializer" not in cell and "adapter" in cell:
                    cell["serializer"] = cell["adapter"]
                cell.setdefault(
                    "version_key",
                    f"{cell.get('format', '')}.{cell.get('version', '')}",
                )
    else:
        matrix = _matrix_from_results(results, default_lang)
    payload = {
        "schema": SCHEMA,
        "generated_at": raw.get("generated_at")
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": source_name,
        "language": default_lang,
        "languages": langs or [default_lang],
        "policy": raw.get("policy") or "report-only",
        "scope": raw.get("scope")
        if isinstance(raw.get("scope"), dict)
        else {"formats": sorted({str(r.get("format") or "") for r in results if r.get("format")}), "note": SCOPE_NOTE},
        "passed": int(raw.get("passed") or 0),
        "failed": int(raw.get("failed") or 0),
        "skipped": int(raw.get("skipped") or 0),
        "errors": int(raw.get("errors") or 0),
        "catalog_errors": raw.get("catalog_errors") or [],
        "serializer_errors": raw.get("serializer_errors") or raw.get("adapter_errors") or [],
        "matrix": matrix,
        "results": results,
    }
    if not payload["scope"].get("note"):
        payload["scope"]["note"] = SCOPE_NOTE
    return payload


def main() -> int:
    _repo, log_dir, out_path = _paths()
    srcs = _pick_sources(log_dir)
    if not srcs:
        print(f"No compliance report under {log_dir}", file=sys.stderr)
        print("Run ./scripts/run-compliance.sh first.", file=sys.stderr)
        return 1
    reports = []
    for src in srcs:
        raw = json.loads(src.read_bytes().decode("utf-8", errors="surrogatepass"))
        if not isinstance(raw, dict):
            print(f"{src} is not a JSON object", file=sys.stderr)
            return 1
        reports.append(raw)
    merged = merge_reports(reports)
    payload = build_payload(merged, "+".join(s.name for s in srcs))
    import gzip

    out_path.parent.mkdir(parents=True, exist_ok=True)
    blob = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8", errors="surrogatepass"
    )
    gz_path = out_path.with_suffix(out_path.suffix + ".gz")
    gz_path.write_bytes(gzip.compress(blob, compresslevel=6))
    if out_path.is_file():
        out_path.unlink()
    print(
        f"Wrote {gz_path.relative_to(_repo)} "
        f"from {'+'.join(s.name for s in srcs)} ({payload['passed']} pass / {payload['failed']} fail / "
        f"{len(payload['results'])} rows, {len(blob)} bytes -> {gz_path.stat().st_size} gzip)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
