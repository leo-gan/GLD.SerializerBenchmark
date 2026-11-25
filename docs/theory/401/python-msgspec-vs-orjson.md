# 4.8 Case Study: Typed Positional vs. Dynamic Maps (Python)

## Problem Statement

On this suite's `document` payload ($n = 1$, in-memory `bytes` mode), **`msgspec-msgpack`** completes more encode+decode cycles per second than **`orjson`** and produces a wire payload roughly $3.5\times$ smaller—even though both libraries execute their hot loops in native compiled code (C and Rust respectively), and **`orjson` actually encodes faster** than `msgspec-msgpack`. Meanwhile, the standard PyPI **`msgpack`** package (also implemented in C) trails `msgspec-msgpack` by more than $2\times$ despite emitting MessagePack bytes.

Inspecting the actual timed call sites explains all three observations from first principles: **wire layout (positional typed slots vs. string-keyed maps)** dominates decode allocation cost.

> **Illustrative L1 snapshot (`document`, $n = 1$, `bytes` mode):** Live authoritative numbers belong to the [Python Dashboard comparison](../../dashboard/index.html?lang=python&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=orjson&ser=msgspec-msgpack&ser=orjson#compare) ([Claims L1](../../analysis/CLAIMS_AND_REPLICATION.md) · [Python Overview](../../python/index.md)).

| Metric (Quoted L1 Snapshot) | `msgspec-msgpack` 0.21.1 | `orjson` 3.11.9 | PyPI `msgpack` 1.2.1 |
|---|---:|---:|---:|
| Throughput (encode + decode) | **272k ops/s** | 242k ops/s | 113k ops/s |
| Encode latency | 1.73 µs | **1.62 µs** | 4.17 µs |
| Decode latency | **1.95 µs** | 2.50 µs | 4.72 µs |
| Encoded wire size | **129 B** | 448 B | 325 B |

---

## Source-Level Call Sites

All three adapters keep domain-model conversion in untimed `prepare_data`, timing only encode and decode of the library's native Python representation ([Timing honesty](../../analysis/TIMING_HONESTY.md)):

### 1. `msgspec-msgpack` (`python/src/benchmark/serializers/json_msgspec.py`)

`prepare_data` maps the suite dataclass into a C-backed `msgspec.Struct` generated with **`array_like=True`** (positional fields):[^1]

```python
_STRUCT_TYPES[cls] = msgspec.defstruct(
    f"Msgspec{cls.__name__}",
    struct_fields,
    module=__name__,
    array_like=True,
)

def serialize_bytes(self, obj: Any) -> bytes:
    return self._encoder.encode(obj)

def deserialize_bytes(self, data: bytes) -> Any:
    return self._decoder.decode(data)   # Decoder(type=MsgspecDocument)
```

### 2. `orjson` (`python/src/benchmark/serializers/json_orjson.py`)

`prepare_data` converts the record to plain nested Python `dict` objects, and the timed path calls Rust `orjson.dumps` / `orjson.loads`:[^2]

```python
def serialize_bytes(self, obj):
    return orjson.dumps(obj)

def deserialize_bytes(self, data):
    return orjson.loads(data)
```

### 3. PyPI `msgpack` (`python/src/benchmark/serializers/binary_msgpack.py`)

Operates on plain nested `dict` objects as well—writing string-keyed MessagePack maps rather than positional arrays:

```python
return self._packer.pack(obj)
return msgpack.unpackb(data, ...)
```

---

## Mechanistic Analysis

The `document` record contains top-level metadata plus eight line items (`sku`, `qty`, `price_minor`).

### Wire Layout Divergence

- **`orjson` (448 B):** Emits self-describing JSON objects (`{"id":...,"items":[{"sku":...,"qty":2,"price_minor":300},...]}`). The key string `"price_minor"` is serialized eight times.
- **PyPI `msgpack` (325 B):** Replaces JSON punctuation and decimal numbers with binary type tags, but still emits string-keyed maps—repeating every field name eight times on the wire.
- **`msgspec-msgpack` with `array_like=True` (129 B):** Emits nested positional MessagePack arrays (`[id, status, [region, version], [[sku, qty, price_minor], ...]]`). Field names never touch the wire; they live strictly in the compiled `MsgspecDocument` type definition ([2.4 Self-describing vs. schema-dependent](../201/self-describing-vs-schema-dependent.md)).

### Why `orjson` Wins Encode While `msgspec-msgpack` Wins Decode

1. **Encode (`1.62 µs` vs. `1.73 µs`):** `orjson.dumps` walks CPython `dict` internals directly from Rust and streams UTF-8 straight into a single output `bytes` buffer—avoiding the intermediate Python `str` that slows stdlib `json.dumps(...).encode("utf-8")` down to ~47k ops/s (see [Python: `orjson` vs. `json`](../../analysis/call-sites/python-orjson-vs-json.md)). On a 448-byte document, streaming raw UTF-8 bytes from SIMD-tuned Rust slightly beats walking eight nested structs to emit MessagePack headers.
2. **Decode (`1.95 µs` vs. `2.50 µs` vs. `4.72 µs`):** Decoding reveals the structural cost of dynamic maps. `msgspec.msgpack.Decoder(type=MsgspecDocument)` knows the exact field count and slot offsets ahead of time: its C loop allocates compact fixed-slot C structs and populates each slot directly—**zero key hashing and zero `dict` allocations**. By contrast, `orjson.loads` must scan 448 bytes, allocate ten separate Python `dict` objects (document + `meta` + 8 items), and look up/hash every key (mitigated partially by `orjson`'s key cache). PyPI `msgpack` pays generic C unpacking *plus* string-keyed map hashing and ten `dict` allocations.

*(To isolate the wire encoding from the library, see the companion control study [Python: `msgspec` JSON vs. MessagePack](../../analysis/call-sites/python-msgspec-json-vs-msgpack.md).)*

---

## Trade-Off Summary

| Dimension | `msgspec-msgpack` (`array_like=True`) | `orjson` (JSON `dict`) |
|---|---|---|
| **Wire inspectability** | Binary, positional (requires schema to read) | Self-describing UTF-8 JSON |
| **Schema evolution coupling** | Positional field order must remain synchronized across peers | Field names allow arbitrary ordering and ad hoc inspection |
| **Decode allocations** | Compact fixed-slot C structs (no per-object hash tables) | Nested Python `dict` objects |
| **Model assumption** | Application uses typed `msgspec.Struct` models | Application operates on plain dictionaries |

---

## Exercises

1. **Isolating layout vs. wire syntax:** On this same payload, `msgspec` configured for **JSON** (`array_like=True`) writes 192 bytes—less than half of `orjson`'s 448 bytes, yet larger than `msgspec-msgpack`'s 129 bytes. Explain both gaps precisely.

??? note "Solution"
    - **192 B vs. 448 B:** Both are valid JSON, but `msgspec` (`array_like=True`) emits positional JSON **arrays** (omitting all repeated field-name keys like `"price_minor"`), whereas `orjson` emits named JSON **objects**.
    - **192 B vs. 129 B:** Both omit field names, so the remaining 63-byte difference is pure **text vs. binary encoding overhead** (ASCII decimal digits, commas, brackets, and quotes vs. compact MessagePack binary integers and headers).

2. **Benchmark validity audit:** Suppose a contributor moved `to_dict(obj)` inside `orjson`'s timed `serialize_bytes` while leaving dataclass-to-`Struct` conversion inside `msgspec`'s untimed `prepare_data`. Why would that invalidate the comparison?

??? note "Solution"
    It would violate [Timing honesty](../../analysis/TIMING_HONESTY.md) by timing model-conversion overhead on `orjson` alone while pre-converting `msgspec`'s input off the clock—measuring Python `dataclass` traversal rather than `orjson.dumps`.

3. **Why beating PyPI `msgpack` is not purely "C speed":** Explain why the $2.4\times$ gap between `msgspec-msgpack` and PyPI `msgpack` does not prove `msgspec`'s C compiler output is $2.4\times$ faster than `msgpack`'s C extension.

??? note "Solution"
    The two adapters solve different problems: `msgspec-msgpack` decodes a 129-byte **positional array** into pre-typed fixed-slot structs, whereas PyPI `msgpack` decodes a 325-byte **string-keyed map** into dynamically allocated Python `dict` objects with hash-table insertions on every key.

---

## References

[^1]: Crist-Harif, J. *`msgspec` Documentation: Structs and `array_like` Encoding*. <https://jcristharif.com/msgspec/structs.html>
[^2]: `orjson` Contributors. *`orjson`: Fast, Correct Python JSON Library*. <https://github.com/ijl/orjson>
