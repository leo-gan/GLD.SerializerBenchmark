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


@dataclass
class TableRow:
    """One wide flat row. Proto / Avro / SBE name this record Table.

    Field order is 16 float64, 4 int64, then 2 strings.
    """

    f_float_0: float
    f_float_1: float
    f_float_2: float
    f_float_3: float
    f_float_4: float
    f_float_5: float
    f_float_6: float
    f_float_7: float
    f_float_8: float
    f_float_9: float
    f_float_10: float
    f_float_11: float
    f_float_12: float
    f_float_13: float
    f_float_14: float
    f_float_15: float
    f_int_0: int
    f_int_1: int
    f_int_2: int
    f_int_3: int
    f_str_0: str
    f_str_1: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class NestedMeta:
    region: str
    version: int


@dataclass
class NestedItem:
    sku: str
    qty: int
    price_minor: int


@dataclass
class NestedRow:
    id: str
    status: int
    meta: NestedMeta
    items: list[NestedItem] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class SignalLeg:
    leg_id: int
    leg_qty: int
    leg_pad: int


@dataclass
class Signal:
    seq: int
    ts: int
    price_mantissa: int
    qty: int
    flags: int
    symbol: str
    venue: str
    legs: list[SignalLeg] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(eq=False, repr=False)
class Region:
    """Shared node. Several orders hold this same object."""

    code: str
    note: str
    version: int


@dataclass(eq=False, repr=False)
class Order:
    sku: str
    qty: int
    region: Region


@dataclass(eq=False, repr=False)
class Person:
    """Ring node. ``next`` is a reference, including back to an earlier person."""

    name: str
    next: Person | None = None


@dataclass(eq=False, repr=False)
class Book:
    """One graph instance: shared regions and a person ring."""

    orders: list[Order]
    people: list[Person]

    def __repr__(self) -> str:
        return f"Book(orders={len(self.orders)}, people={len(self.people)})"
