"""Typed catalog records loaded from compliance/data/*.json."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal

Expect = Literal["accept", "reject", "roundtrip", "any"]
Requirement = Literal["MUST", "MUST NOT", "SHOULD", "SHOULD NOT", "MAY"]
InputEncoding = Literal["utf-8", "hex", "latin-1"]


@dataclass(frozen=True)
class Case:
    """One normative check against a published section of a spec.

    This is not a suite **data type** (``message``, ``document``, …).
    Those names are reserved for the benchmark sample shapes.
    """

    id: str
    title: str
    section: str
    section_title: str
    section_url: str
    paragraph: str
    requirement: Requirement
    expect: Expect
    input: str
    input_encoding: InputEncoding = "utf-8"
    decoded: Any = None
    has_decoded: bool = False
    notes: str = ""
    skip_adapters: tuple[str, ...] = ()

    def input_bytes(self) -> bytes:
        if self.input_encoding == "hex":
            compact = "".join(self.input.split())
            return bytes.fromhex(compact)
        if self.input_encoding == "latin-1":
            return self.input.encode("latin-1")
        return self.input.encode("utf-8")


@dataclass(frozen=True)
class Suite:
    """One standard version (one JSON file)."""

    format: str
    standard: str
    version: str
    standard_url: str
    provenance: str
    cases: tuple[Case, ...]
    notes: str = ""
    source_path: str = ""
    adapters: tuple[str, ...] = ()

    @property
    def label(self) -> str:
        return f"{self.standard} ({self.version})"


@dataclass
class CaseResult:
    suite: Suite
    case: Case
    adapter: str
    outcome: Literal["pass", "fail", "skip", "error"]
    detail: str = ""
    observed: str = ""
    serializer_version: str = ""

    def failure_block(self) -> str:
        """Human-readable compliance diagnostic with a spec link."""
        c = self.case
        s = self.suite
        return (
            f"COMPLIANCE {c.requirement} {self.outcome.upper()} [{c.id}] "
            f"{self.adapter}\n"
            f"  Standard : {s.standard} {s.version}\n"
            f"  Section  : {c.section} — {c.section_title}\n"
            f"  Spec     : {c.section_url}\n"
            f"  Rule     : {c.paragraph}\n"
            f"  Expected : {c.expect}\n"
            f"  Observed : {self.observed or self.detail}\n"
            f"  Case     : {c.title}"
            + (f"\n  Notes    : {c.notes}" if c.notes else "")
        )


@dataclass
class Report:
    results: list[CaseResult] = field(default_factory=list)
    catalog_errors: list[str] = field(default_factory=list)
    adapter_errors: list[str] = field(default_factory=list)

    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.outcome == "pass")

    @property
    def failed(self) -> int:
        return sum(1 for r in self.results if r.outcome == "fail")

    @property
    def skipped(self) -> int:
        return sum(1 for r in self.results if r.outcome == "skip")

    @property
    def errors(self) -> int:
        return sum(1 for r in self.results if r.outcome == "error")

    @property
    def failures(self) -> list[CaseResult]:
        return [r for r in self.results if r.outcome in ("fail", "error")]
