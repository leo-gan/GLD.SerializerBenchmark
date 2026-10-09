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
    NestedItem,
    NestedMeta,
    NestedRow,
    Book,
    Order,
    Person,
    Region,
    Signal,
    SignalLeg,
    Strings,
    TableRow,
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
    if type_id in ("table", "table_project"):
        smin, smax = _slen(type_config)
        vocab = _shared_vocab(seed, type_id, smin, smax)
        return _make_table(rng, type_config, vocab)
    if type_id == "nested_table":
        return _make_nested_table(rng, type_config)
    if type_id == "signal":
        return _make_signal(rng, type_config)
    if type_id == "graph":
        return _make_graph(rng, type_config)
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


def _shared_vocab(seed: int, type_id: str, smin: int, smax: int, size: int = 32) -> list[str]:
    """Vocabulary from (seed, type_id) only, shared by every instance index."""
    vocab_rng = XorShift64(mix_seed(seed, f"{type_id}#vocab", 0))
    return [vocab_rng.word(smin, smax) for _ in range(size)]


def _pick_word(
    rng: XorShift64,
    vocab: list[str],
    duplication: float,
    smin: int,
    smax: int,
) -> str:
    if vocab and rng.next_f64() < duplication:
        return vocab[rng.next_int(0, len(vocab) - 1)]
    return rng.word(smin, smax)


def _make_table(rng: XorShift64, cfg: dict[str, Any], vocab: list[str]) -> TableRow:
    lo, hi = _irange(cfg)
    smin, smax = _slen(cfg)
    dup = float(cfg.get("duplication", 0.5))
    floats = [rng.next_f64() * 1000.0 for _ in range(16)]
    ints = [rng.next_int(lo, hi) for _ in range(4)]
    strs = [_pick_word(rng, vocab, dup, smin, smax) for _ in range(2)]
    return TableRow(
        f_float_0=floats[0],
        f_float_1=floats[1],
        f_float_2=floats[2],
        f_float_3=floats[3],
        f_float_4=floats[4],
        f_float_5=floats[5],
        f_float_6=floats[6],
        f_float_7=floats[7],
        f_float_8=floats[8],
        f_float_9=floats[9],
        f_float_10=floats[10],
        f_float_11=floats[11],
        f_float_12=floats[12],
        f_float_13=floats[13],
        f_float_14=floats[14],
        f_float_15=floats[15],
        f_int_0=ints[0],
        f_int_1=ints[1],
        f_int_2=ints[2],
        f_int_3=ints[3],
        f_str_0=strs[0],
        f_str_1=strs[1],
    )


def _make_nested_table(rng: XorShift64, cfg: dict[str, Any]) -> NestedRow:
    children = int(cfg.get("children", 4))
    smin, smax = _slen(cfg)
    items = [
        NestedItem(
            sku=rng.word(smin, smax),
            qty=rng.next_int(1, 100),
            price_minor=rng.next_int(0, 100_000),
        )
        for _ in range(children)
    ]
    return NestedRow(
        id=rng.word(8, 12),
        status=rng.next_int(0, 5),
        meta=NestedMeta(region=rng.word(2, 4), version=rng.next_int(1, 10)),
        items=items,
    )


def _make_signal(rng: XorShift64, cfg: dict[str, Any]) -> Signal:
    group_count = int(cfg.get("group_count", 4))
    smin, smax = _slen(cfg)
    legs = [
        SignalLeg(
            leg_id=rng.next_int(0, 1_000_000),
            leg_qty=rng.next_int(0, 10_000),
            leg_pad=0,
        )
        for _ in range(group_count)
    ]
    return Signal(
        seq=rng.next_int(0, 1_000_000_000),
        ts=_BASE_TS_MS + rng.next_int(0, 86_400_000),
        price_mantissa=rng.next_int(0, 1_000_000_000),
        qty=rng.next_int(0, 10_000),
        flags=rng.next_int(0, 65_535),
        symbol=rng.word(smin, smax),
        venue=rng.word(smin, smax),
        legs=legs,
    )


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


def _make_graph(rng: XorShift64, cfg: dict[str, Any]) -> Book:
    """One graph. Call order is the cross-language contract.

    Regions first (code, 64-char note, version), then orders (sku, qty, shared
    region by index), then person names, then the ring of references.
    """
    smin, smax = _slen(cfg)
    n_orders = int(cfg.get("order_count", 32))
    n_regions = int(cfg.get("region_count", 4))
    ring = int(cfg.get("ring_size", 8))
    if n_regions < 1:
        raise ValueError("region_count must be >= 1")
    if ring < 1:
        raise ValueError("ring_size must be >= 1")
    regions = [
        Region(
            code=rng.word(smin, smax),
            note=rng.word(64, 64),
            version=rng.next_int(1, 10),
        )
        for _ in range(n_regions)
    ]
    orders = [
        Order(
            sku=rng.word(smin, smax),
            qty=rng.next_int(1, 100),
            region=regions[i % n_regions],
        )
        for i in range(n_orders)
    ]
    people = [Person(name=rng.word(smin, smax), next=None) for _ in range(ring)]
    for i, person in enumerate(people):
        person.next = people[(i + 1) % ring]
    return Book(orders=orders, people=people)
