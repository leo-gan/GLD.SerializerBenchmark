"""Run catalog suites against adapters and collect RFC-linked results."""

from __future__ import annotations

from typing import Iterable

from .adapters import Adapter, builtin_adapters
from .catalog import load_all_suites
from .compare import preview, values_equal
from .context import current_schema
from .models import Case, CaseResult, Report, Suite

LAST_REPORT: Report | None = None


def run_suites(
    suites: Iterable[Suite] | None = None,
    adapters: Iterable[Adapter] | None = None,
    *,
    formats: Iterable[str] | None = None,
    adapter_names: Iterable[str] | None = None,
) -> Report:
    global LAST_REPORT
    report = Report()
    try:
        suite_list = list(suites) if suites is not None else load_all_suites()
    except Exception as exc:  # noqa: BLE001
        report.catalog_errors.append(str(exc))
        LAST_REPORT = report
        return report

    if formats:
        want = {f.lower() for f in formats}
        suite_list = [s for s in suite_list if s.format.lower() in want]

    try:
        adapter_list = list(adapters) if adapters is not None else builtin_adapters()
    except Exception as exc:  # noqa: BLE001
        report.adapter_errors.append(str(exc))
        LAST_REPORT = report
        return report

    if adapter_names:
        want_ad = {n.lower() for n in adapter_names}
        adapter_list = [a for a in adapter_list if a.name.lower() in want_ad]

    by_format: dict[str, list[Adapter]] = {}
    for adapter in adapter_list:
        by_format.setdefault(adapter.format, []).append(adapter)

    for suite in suite_list:
        chosen = _adapters_for_suite(suite, by_format.get(suite.format, []))
        if not chosen:
            report.adapter_errors.append(
                f"No adapter registered for format {suite.format!r} ({suite.label})"
            )
            continue
        for adapter in chosen:
            for case in suite.cases:
                report.results.append(_run_one(suite, case, adapter))

    LAST_REPORT = report
    return report


def _adapters_for_suite(suite: Suite, available: list[Adapter]) -> list[Adapter]:
    if suite.adapters:
        want = set(suite.adapters)
        return [a for a in available if a.name in want]
    return list(available)


def _result(suite: Suite, case: Case, adapter: Adapter, outcome: str, **kwargs) -> CaseResult:
    return CaseResult(
        suite,
        case,
        adapter.name,
        outcome,
        serializer_version=adapter.version,
        **kwargs,
    )


def _run_one(suite: Suite, case: Case, adapter: Adapter) -> CaseResult:
    if adapter.name in case.skip_adapters:
        return _result(suite, case, adapter, "skip", detail="listed in skip_adapters")

    raw = case.input_bytes()
    token = current_schema.set(case.schema)
    try:
        try:
            observed = adapter.decode(raw)
            decoded_ok = True
            decode_error: str | None = None
        except Exception as exc:  # noqa: BLE001 — library under test
            observed = None
            decoded_ok = False
            decode_error = f"{type(exc).__name__}: {exc}"
    finally:
        current_schema.reset(token)

    if case.expect == "any":
        return _result(
            suite,
            case,
            adapter,
            "pass",
            observed=decode_error or preview(observed),
            detail="implementation-defined (recorded, not scored)",
        )

    if case.expect == "reject":
        if not decoded_ok:
            return _result(suite, case, adapter, "pass", observed=decode_error or "rejected")
        return _result(
            suite,
            case,
            adapter,
            "fail",
            detail="parser accepted input the spec requires to be rejected",
            observed=f"accepted as {preview(observed)}",
        )

    if not decoded_ok:
        return _result(
            suite,
            case,
            adapter,
            "fail",
            detail="parser rejected input the spec requires to accept",
            observed=decode_error or "rejected",
        )

    if case.has_decoded and not values_equal(case.decoded, observed):
        return _result(
            suite,
            case,
            adapter,
            "fail",
            detail="decoded value does not match the catalog case",
            observed=f"got {preview(observed)}, want {preview(case.decoded)}",
        )

    if case.expect == "roundtrip":
        if adapter.encode is None:
            return _result(suite, case, adapter, "skip", detail="serializer has no encoder")
        try:
            encoded = adapter.encode(observed)
            again = adapter.decode(encoded)
        except Exception as exc:  # noqa: BLE001
            return _result(
                suite,
                case,
                adapter,
                "fail",
                detail="round-trip encode/decode raised",
                observed=f"{type(exc).__name__}: {exc}",
            )
        if case.has_decoded:
            if not values_equal(case.decoded, again):
                return _result(
                    suite,
                    case,
                    adapter,
                    "fail",
                    detail="round-trip value does not match the catalog case",
                    observed=preview(again),
                )
        elif not values_equal(observed, again):
            return _result(
                suite,
                case,
                adapter,
                "fail",
                detail="round-trip did not preserve the decoded value",
                observed=preview(again),
            )

    return _result(suite, case, adapter, "pass", observed=preview(observed))
