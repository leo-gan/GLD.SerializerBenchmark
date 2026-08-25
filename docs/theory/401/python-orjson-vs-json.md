# Python: why orjson outruns the standard library on the same JSON

## Why this article exists

On this suite’s **document** fixture, one instance, **orjson** and the standard library `json` module emit the **same 448 bytes**. orjson finishes about **five times** as many encode-and-decode cycles per second. There is no format lesson here. The bytes are JSON objects with the same keys. The gap is how each library walks a Python dictionary and how it hands bytes back to the caller.

This page compares the two timed wrappers and the library functions they call. After reading it you should be able to point at the extra `str` and the missed cached encoder in the standard-library path.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=python&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=json&ser=orjson&ser=json#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Python overview](../../python/)

## Short answer

orjson writes UTF-8 **bytes** in Rust and parses those bytes back into dictionaries. The standard-library wrapper builds a Python **Unicode string**, then encodes it to UTF-8, and it constructs a new `JSONEncoder` on every call because `separators=(",", ":")` misses the cached encoder. Decode first turns bytes back into a `str`. Same JSON. Five times the work.

| | orjson 3.11.9 | stdlib json (Python 3.14) |
|--|---------------|---------------------------|
| Mean encode + decode, document, *n* = 1 | **242 thousand / s** | 48 thousand / s |
| Encode | **1.62 µs** | 12.4 µs |
| Decode | **2.50 µs** | 8.53 µs |
| Encoded size | **448 B** | **448 B** |

Equal size is the teaching fact. Speed is implementation.

## The two timed call sites

Both wrappers convert the dataclass to a dictionary in untimed `prepare_data`. Timed work is only dump and load.

```python
# python/src/benchmark/serializers/json_orjson.py
def serialize_bytes(self, obj):
    return orjson.dumps(obj)

def deserialize_bytes(self, data):
    return orjson.loads(data)
```

```python
# python/src/benchmark/serializers/json_stdlib.py
def serialize_bytes(self, obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

def deserialize_bytes(self, data):
    return json.loads(data)
```

`separators=(",", ":")` is there so the standard library emits compact JSON, matching orjson’s default. It is also what takes the slow path.

## What the standard library does on every encode

`json.dumps` keeps a single cached encoder for the *default* argument combination. Any other combination builds a new encoder:

```python
# CPython 3.14, Lib/json/__init__.py
if (not skipkeys and ensure_ascii and
    check_circular and allow_nan and
    cls is None and indent is None and separators is None and
    default is None and not sort_keys and not kw):
    return _default_encoder.encode(obj)
# otherwise:
return cls(..., separators=separators, ...).encode(obj)
```

This runner sets `ensure_ascii=False` *and* `separators=...`. Both conditions fail. Every timed encode constructs a `JSONEncoder`, walks the dictionary, and returns a `str`. The wrapper then calls `.encode("utf-8")` and allocates a `bytes` object. Two Python strings’ worth of data for one JSON document.

`json.loads` on a `bytes` object first decodes to `str`:

```python
# same file
else:
    s = s.decode(detect_encoding(s), 'surrogatepass')
return _default_decoder.decode(s)
```

The C accelerator `_json` then parses Unicode. orjson never builds that intermediate `str`.

## What orjson does instead

orjson (`dumps` / `loads` in the Rust crate `ijl/orjson`) takes a Python object and writes UTF-8 into a byte buffer. `loads` parses those bytes and allocates dictionaries. There is still a dictionary per nested record — this is not msgspec’s typed Struct path. The win versus the standard library is:

1. no Unicode detour;
2. no per-call `JSONEncoder` construction;
3. a Rust inner loop that examines many characters at once (the simdjson tradition of Geoff Langdale and Daniel Lemire, 2018–2019).

**History.** The standard library’s `json` module (Bob Ippolito and contributors, Python 2.6 onward) is the portable, always-there encoder. It was written to be correct and maintainable, not to win a microbenchmark. orjson (late 2010s) exists because web services paid real time for that portability. The format did not change. The path from a `dict` to bytes did.

## What this page is not

It is not “JSON is slow.” jsoniter, Glaze, yyjson, and V8 `JSON.stringify` show that JSON can be fast when the implementation is specialized. It is not “orjson beats msgspec.” [msgspec-msgpack versus orjson](python-msgspec-vs-orjson.md) is a different experiment: positional MessagePack Structs versus named JSON dictionaries.

A fairer stdlib call would keep a long-lived `JSONEncoder(ensure_ascii=False, separators=(",", ":"))` and write with `encode`. That would remove the per-call constructor. It would not remove the `str` then UTF-8 copy. The five-times gap would shrink. It would not vanish.

## Self-check

1. Why is equal size essential to this lesson?
2. Which two extra allocations does `.dumps(...).encode("utf-8")` perform that `orjson.dumps` does not?
3. Why does passing `separators=` make CPython skip `_default_encoder`?
