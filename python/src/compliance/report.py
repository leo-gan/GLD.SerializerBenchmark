"""Format compliance reports for the terminal and for JSON sidecar files."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

from .models import CaseResult, Report


def format_summary(report: Report, *, max_failures: int = 40) -> str:
    lines = [
        "Serialization compliance (library deviations are catalogued, not a red build)",
        f"  {report.passed} pass  {report.failed} fail  "
        f"{report.skipped} skip  {report.errors} error  "
        f"{len(report.results)} total",
    ]
    if report.catalog_errors:
        lines.append("  Catalog errors:")
        lines.extend(f"    - {e}" for e in report.catalog_errors)
    if report.adapter_errors:
        lines.append("  Adapter errors:")
        lines.extend(f"    - {e}" for e in report.adapter_errors)

    by_key: dict[tuple[str, str], list[CaseResult]] = defaultdict(list)
    for row in report.results:
        by_key[(row.suite.label, row.adapter)].append(row)
    lines.append("  By suite × adapter:")
    for (label, adapter), rows in sorted(by_key.items()):
        p = sum(1 for r in rows if r.outcome == "pass")
        f = sum(1 for r in rows if r.outcome == "fail")
        s = sum(1 for r in rows if r.outcome == "skip")
        lines.append(f"    {label} × {adapter}: {p} pass, {f} fail, {s} skip")

    failures = report.failures
    if failures:
        lines.append("")
        lines.append(f"  Detailed failures (first {min(max_failures, len(failures))}):")
        for row in failures[:max_failures]:
            lines.append("")
            lines.append("  " + row.failure_block().replace("\n", "\n  "))
        remaining = len(failures) - max_failures
        if remaining > 0:
            lines.append(f"  … {remaining} more failure(s)")
    return "\n".join(lines)


def format_detailed(report: Report) -> str:
    """One block per failure; pass lines stay one-liners."""
    chunks = [format_summary(report, max_failures=0)]
    for row in report.results:
        if row.outcome == "pass":
            chunks.append(f"PASS [{row.case.id}] {row.adapter} {row.case.section_url}")
        elif row.outcome == "skip":
            chunks.append(f"SKIP [{row.case.id}] {row.adapter} — {row.detail}")
        else:
            chunks.append(row.failure_block())
    return "\n".join(chunks)


def report_to_json(report: Report) -> dict:
    from datetime import datetime, timezone

    matrix_map: dict[tuple[str, str, str, str, str], dict] = {}
    language = "python"
    for r in report.results:
        key = (language, r.suite.format, r.suite.standard, r.suite.version, r.adapter)
        cell = matrix_map.setdefault(
            key,
            {
                "language": language,
                "format": r.suite.format,
                "standard": r.suite.standard,
                "standard_url": r.suite.standard_url,
                "version": r.suite.version,
                "version_key": f"{r.suite.format}.{r.suite.version}",
                "serializer": r.adapter,
                "serializer_version": r.serializer_version,
                "passed": 0,
                "failed": 0,
                "skipped": 0,
                "errors": 0,
                "total": 0,
            },
        )
        cell["total"] += 1
        if r.outcome == "pass":
            cell["passed"] += 1
        elif r.outcome == "fail":
            cell["failed"] += 1
        elif r.outcome == "skip":
            cell["skipped"] += 1
        else:
            cell["errors"] += 1
    matrix = []
    for cell in matrix_map.values():
        judged = cell["passed"] + cell["failed"]
        cell["pass_rate"] = (cell["passed"] / judged) if judged else None
        matrix.append(cell)
    matrix.sort(
        key=lambda c: (c["language"], c["format"], c["standard"], c["version"], c["serializer"])
    )

    return {
        "schema": "gld.dashboard.compliance/1",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "language": "python",
        "languages": ["python"],
        "policy": "report-only",
        "scope": {
            "formats": sorted({r.suite.format for r in report.results}),
            "note": (
                "Official parse suites (MIT/BSD/Apache) plus original extras. "
                "XML is out of scope. Language-native / private binaries have "
                "no public spec column."
            ),
        },
        "passed": report.passed,
        "failed": report.failed,
        "skipped": report.skipped,
        "errors": report.errors,
        "catalog_errors": report.catalog_errors,
        "serializer_errors": report.adapter_errors,
        "matrix": matrix,
        "results": [
            {
                "id": r.case.id,
                "language": language,
                "serializer": r.adapter,
                "serializer_version": r.serializer_version,
                "format": r.suite.format,
                "standard": r.suite.standard,
                "standard_url": r.suite.standard_url,
                "version": r.suite.version,
                "version_key": f"{r.suite.format}.{r.suite.version}",
                "requirement": r.case.requirement,
                "expect": r.case.expect,
                "outcome": r.outcome,
                "section": r.case.section,
                "section_title": r.case.section_title,
                "section_url": r.case.section_url,
                "paragraph": r.case.paragraph,
                "title": r.case.title,
                "input": r.case.input,
                "input_encoding": r.case.input_encoding,
                "detail": r.detail,
                "observed": r.observed,
            }
            for r in report.results
        ],
    }


def write_json(report: Report, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report_to_json(report), indent=2) + "\n", encoding="utf-8")
