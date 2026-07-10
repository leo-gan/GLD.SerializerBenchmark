"""Logical instance models for Data Model v2 (plain dataclasses / dict-friendly)."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass
class Message:
    """Single-level mixed primitives (default field_count=8 slots)."""

    f_bool: bool
    f_int32: int
    f_int64: int
    f_float64: float
    f_string: str
    f_bool_2: bool
    f_int32_2: int
    f_string_2: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class DocumentMeta:
    region: str
    version: int


@dataclass
class DocumentItem:
    sku: str
    qty: int
    price_minor: int


@dataclass
class Document:
    id: str
    status: int
    meta: DocumentMeta
    items: list[DocumentItem] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Telemetry:
    source: str
    ts: int
    tags: list[str]
    values: list[float]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Strings:
    items: list[str]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class EventAttr:
    key: str
    value: str


@dataclass
class Event:
    event_id: str
    event_type: str
    occurred_at: int
    producer: str
    attrs: list[EventAttr]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
