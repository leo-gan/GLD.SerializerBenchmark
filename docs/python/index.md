---
title: "Python"
---

Python
======

Python's dynamic nature makes serialization uniquely challenging. While it excels at developer productivity, the runtime overhead of object instantiation and the Global Interpreter Lock (GIL) can severely bottleneck high-throughput data processing pipelines.

## Benchmark runner

- Directory: `python/` (repository root)
- Output: monorepo `logs/python/YYYY-MM-DD-HHMMSS.csv` (`Language=python`, times in **nanoseconds**)
- Runner: `python/scripts/run-benchmarks.sh` (or project docs for modes)
- Registration: [`python/src/benchmark/runner.py`](../../python/src/benchmark/runner.py)
- Modes: `bytes` and `stream`

## Serializers

| Log name | Category | Package | Native input (`prepare_data`) | Stream mode | Notes |
|----------|----------|---------|---------------------------------|-------------|-------|
| avro | Schema | `fastavro` | record dict | adapted | Compact schemaless size; dict/union path slower than protobuf C++ |
| cbor2 | Binary | `cbor2` | dict | native | IETF CBOR (RFC 8949) |
| cloudpickle | Native | `cloudpickle` | dataclass | native | Extended pickle; same security caveats |
| dill | Native | `dill` | dataclass | native | Graphs/dynamics; **ser** much slower than pickle (pure-Python dispatch) |
| flatbuffers | Schema | `flatbuffers` | dataclass → Builder | adapted | Python Builder ser is slow; deser is zero-copy `GetRootAs` view |
| json | JSON | stdlib | dict | adapted | Baseline text JSON |
| mashumaro | JSON | `mashumaro` | dataclass | adapted | ORJSONEncoder/Decoder |
| msgpack | Binary | `msgpack` | dict | native | Reference MessagePack |
| msgspec | JSON | `msgspec` | Struct | native (`encode_into`) | Typed array-like Structs |
| msgspec-msgpack | Binary | `msgspec` | Struct | native | Same Struct path, MessagePack |
| orjson | JSON | `orjson` | dict | adapted | Rust core; conversion untimed |
| pickle | Native | stdlib | dataclass | native | Cycles supported; **unsafe** untrusted |
| protobuf | Schema | `protobuf` | Message | adapted | From suite protobuf schemas under `schemas/v2/` / language generated modules |
| pydantic | JSON | `pydantic` | BaseModel | adapted | Validation-oriented API models |
| rapidjson | JSON | `python-rapidjson` | dict | adapted | C++ RapidJSON bindings |
| serpyco-rs | JSON | `serpyco-rs` + `orjson` | dataclass | adapted | dump/load + orjson wire |

### Call-path contract (fair timing)

Timed methods measure **codec only** on library-native values:

1. `prepare(name, type)` — encoders, schemas, buffers (untimed)
2. `prepare_data(obj, …)` — dataclass → dict / Struct / Message / Model (untimed)
3. `serialize_*` / `deserialize_*` — encode/decode only (timed)

FlatBuffers is the exception where Builder construction *is* the serialize API (no separate Message type). Stream mode is **native** when the library has a real file/stream API; otherwise **adapted** (bytes then write / read then bytes).

### Caveats

#### Why avro size is great but ops/s lag protobuf

- **Size is real:** schemaless Avro omits field names (schema out-of-band).
- **Speed is mostly library/runtime:** timed path is only `schemaless_writer`/`reader` on a pre-built dict + cached `parse_schema`. fastavro (Cython) still loses to protobuf message `SerializeToString` by ~20–30× on nested types because of Python-dict field walks and null-unions.
- **Measurement:** the benchmark runner no longer runs `tracemalloc` during timed ser/des (it was inflating alloc-heavy codecs ~2–3×).

#### Why flatbuffers and dill ops/s look low

- **flatbuffers (serialize):** the official Python package builds with a pure-Python `Builder`. Expect ~100×+ slower ser than `protobuf` on the same POCO. C++/Rust FlatBuffers are a different performance class; this suite measures the Python binding.
- **flatbuffers (deserialize):** timed path is zero-copy `GetRootAs` + a thin view. Full field materialization is *not* forced inside the timer (FlatBuffers' model: pay on field access).
- **dill (serialize):** for ordinary importable dataclasses the wire size matches pickle, but dill's pure-Python `save` path (module/type discovery) is ~15–20× slower than C `pickle`. That is inherent; `byref`/`recurse` do not close the gap on these data types. Prefer pickle when you do not need dill's dynamic-object features.

### Other caveats

- `tracemalloc` under-counts C/Rust extension allocations.
- Fidelity is semantic, not strict type identity (dict vs dataclass, enum vs int, datetime ms truncation).

Benchmark runner: [`python/README.md`](../../python/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## The Global Interpreter Lock (GIL)

In CPython, the GIL prevents multiple native threads from executing Python bytecodes simultaneously. This has massive implications for serialization in multithreaded web servers (like FastAPI or Flask).
If a JSON payload takes 10ms to deserialize, the entire Python process is blocked for that 10ms.

**The Solution:** The fastest Python serializers are written in C, C++, or Rust. They release the GIL while parsing the raw bytes and only reacquire it at the very end when they must instantiate the Python dictionary or object, allowing true concurrent processing.

## Object Instantiation Overhead

In Python, every object (even a simple integer) is a full-fledged heap-allocated structure with a reference count and a type pointer. Dictionaries have significant memory overhead compared to C structs.

*   **Dicts vs. Classes:** Deserializing into a standard Python `dict` is generally much faster than instantiating custom classes or Pydantic models.
*   **Slots:** If you must deserialize into classes, using `__slots__` reduces memory footprint and slightly speeds up attribute assignment.

## Pickling vs. Standard Formats

`pickle` is Python's built-in serialization format. It is deeply integrated into the language and can serialize almost arbitrary Python objects, including functions and classes.

*   **Security:** `pickle` is notoriously insecure. Unpickling malicious data can execute arbitrary code on your machine.
*   **Interoperability:** `pickle` is entirely Python-specific.
*   **Performance:** While the C implementation in modern Python is fast, it is often outperformed by specialized binary serializers like `msgpack` or `orjson`.
