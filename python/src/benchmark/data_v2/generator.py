"""make_one generators for Data Model v2 types."""

from __future__ import annotations

from typing import Any

from .models import (
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    Message,
    Strings,
    Telemetry,
)
from .prng import XorShift64, mix_seed

# Fixed epoch base so runs are stable (not wall clock).
_BASE_TS_MS = 1_704_067_200_000  # 2024-01-01T00:00:00Z


def make_one(
    type_id: str,
    type_config: dict[str, Any],
    seed: int,
    instance_index: int = 0,
) -> Any:
    """Build one instance. type_config must already be resolved (no all_available)."""
    rng = XorShift64(mix_seed(seed, type_id, instance_index))
    if type_id == "message":
        return _make_message(rng, type_config)
    if type_id == "document":
        return _make_document(rng, type_config)
    if type_id == "telemetry":
        return _make_telemetry(rng, type_config)
    if type_id == "strings":
        return _make_strings(rng, type_config)
    if type_id == "event":
        return _make_event(rng, type_config)
    raise ValueError(f"unknown type_id: {type_id!r}")


def instances_for_cell(
    type_id: str,
    type_config: dict[str, Any],
    seed: int,
    data_type_instance_count: int,
) -> list[Any]:
    return [
        make_one(type_id, type_config, seed, i)
        for i in range(data_type_instance_count)
    ]


def _slen(cfg: dict[str, Any]) -> tuple[int, int]:
    sl = cfg.get("string_len") or {}
    return int(sl.get("min", 3)), int(sl.get("max", 16))


def _irange(cfg: dict[str, Any]) -> tuple[int, int]:
    ir = cfg.get("int_range") or {}
    return int(ir.get("min", 0)), int(ir.get("max", 1_000_000))


def _make_message(rng: XorShift64, cfg: dict[str, Any]) -> Message:
    lo, hi = _irange(cfg)
    smin, smax = _slen(cfg)
    # field_count reserved for future variable width; default maps to fixed Message
    return Message(
        f_bool=rng.next_bool(),
        f_int32=rng.next_int(lo, min(hi, 2**31 - 1)),
        f_int64=rng.next_int(lo, hi),
        f_float64=rng.next_f64() * 1000.0,
        f_string=rng.word(smin, smax),
        f_bool_2=rng.next_bool(),
        f_int32_2=rng.next_int(lo, min(hi, 2**31 - 1)),
        f_string_2=rng.word(smin, smax),
    )


def _make_document(rng: XorShift64, cfg: dict[str, Any]) -> Document:
    children = int(cfg.get("children", 8))
    smin, smax = _slen(cfg)
    items = [
        DocumentItem(
            sku=rng.word(smin, smax),
            qty=rng.next_int(1, 100),
            price_minor=rng.next_int(0, 100_000),
        )
        for _ in range(children)
    ]
    return Document(
        id=rng.word(8, 12),
        status=rng.next_int(0, 5),
        meta=DocumentMeta(region=rng.word(2, 4), version=rng.next_int(1, 10)),
        items=items,
    )


def _make_telemetry(rng: XorShift64, cfg: dict[str, Any]) -> Telemetry:
    points = int(cfg.get("points", 32))
    tag_count = int(cfg.get("tag_count", 2))
    smin, smax = _slen(cfg)
    tags = [rng.word(smin, smax) for _ in range(tag_count)]
    number_type = cfg.get("number_type", "float64")
    if number_type == "int64":
        values = [float(rng.next_int(0, 10_000)) for _ in range(points)]
    else:
        values = [rng.next_f64() * 100.0 for _ in range(points)]
    return Telemetry(
        source=rng.word(smin, smax),
        ts=_BASE_TS_MS + rng.next_int(0, 86_400_000),
        tags=tags,
        values=values,
    )


def _make_strings(rng: XorShift64, cfg: dict[str, Any]) -> Strings:
    count = int(cfg.get("count", 32))
    smin, smax = _slen(cfg)
    dup = float(cfg.get("duplication", 0.0))
    pool: list[str] = []
    items: list[str] = []
    for _ in range(count):
        if pool and rng.next_f64() < dup:
            items.append(pool[rng.next_int(0, len(pool) - 1)])
        else:
            w = rng.word(smin, smax)
            pool.append(w)
            items.append(w)
    return Strings(items=items)


def _make_event(rng: XorShift64, cfg: dict[str, Any]) -> Event:
    attr_count = int(cfg.get("attr_count", 4))
    smin, smax = _slen(cfg)
    attrs = [
        EventAttr(key=rng.word(smin, smax), value=rng.word(smin, smax))
        for _ in range(attr_count)
    ]
    return Event(
        event_id=rng.word(8, 12),
        event_type=rng.word(smin, smax),
        occurred_at=_BASE_TS_MS + rng.next_int(0, 86_400_000),
        producer=rng.word(smin, smax),
        attrs=attrs,
    )
