# Python: `orjson` vs. stdlib `json`

This note inspects Python's Rust-backed `orjson` and standard-library `json` adapters on the `document` ($n = 1$, `bytes` mode) payload. Both receive an identical pre-built Python `dict` from untimed `prepare_data` and emit the **exact same 448-byte** compact UTF-8 JSON document, isolating pure implementation overhead in CPython.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=python&standard=json&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=json&ser=orjson&ser=json#compare) · [Python overview](../../python/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `orjson` | `json` (CPython stdlib) |
|---|---|---|
| Standard | `json` (RFC 8259, compact UTF-8) | `json` (RFC 8259, compact UTF-8) |
| Encoded size (`document`, $n = 1$) | **448 B** | **448 B** (identical) |
| Input / output model | Nested Python `dict` ↔ `bytes` | Nested Python `dict` ↔ `bytes` |
| Intermediate `str` allocation | None (direct Rust UTF-8 buffer) | Encode builds `str` then `.encode("utf-8")`; decode decodes `bytes` to `str` first |
| Encoder caching | Stateless Rust entry point (`orjson.dumps`) | `separators=(",", ":")` bypasses CPython `_default_encoder` (constructs `JSONEncoder` per call) |

## Timed Call Sites

**`orjson`** (`python/src/benchmark/serializers/json_orjson.py`) reads and writes UTF-8 `bytes` directly from Rust:

```python
def serialize_bytes(self, obj):
    return orjson.dumps(obj)

def deserialize_bytes(self, data):
    return orjson.loads(data)
```

**stdlib `json`** (`python/src/benchmark/serializers/json_stdlib.py`) passes `ensure_ascii=False` and compact `separators=(",", ":")` to match `orjson`'s 448-byte output, then encodes the resulting `str` to UTF-8:

```python
def serialize_bytes(self, obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

def deserialize_bytes(self, data):
    return json.loads(data)
```

## Mechanistic Analysis and Scope Limits

1. **Double string conversion on stdlib `json`:** `json.dumps` returns a Python Unicode `str`, forcing a second allocation and copy via `.encode("utf-8")` to produce wire `bytes`. Symmetrically, `json.loads(bytes)` first calls `detect_encoding` and `.decode(...)` into a `str` before invoking CPython's C `_json` scanner. `orjson` bypasses intermediate Unicode `str` objects in both directions and uses SIMD-style UTF-8 scanning in Rust.
2. **Missed `_default_encoder` fast path:** In CPython's `Lib/json/__init__.py`, `_default_encoder` is reused only when every keyword argument stays at its default. Passing `ensure_ascii=False, separators=(",", ":")` instantiates a fresh `JSONEncoder` on every timed encode. Caching a long-lived `JSONEncoder` instance in `prepare` would remove the per-call constructor overhead, though it would not eliminate the intermediate `str` ↔ `bytes` round trip or the C vs. Rust inner-loop gap.
3. **Scope limits:** Both adapters still materialize ten Python `dict` objects per decoded `document`; to see the additional effect of replacing dynamic dictionaries with typed positional C structs, see [4.8 Python: `msgspec-msgpack` vs. `orjson`](../../theory/401/python-msgspec-vs-orjson.md).
