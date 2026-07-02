# Python

Python's dynamic nature makes serialization uniquely challenging. While it excels at developer productivity, the runtime overhead of object instantiation and the Global Interpreter Lock (GIL) can severely bottleneck high-throughput data processing pipelines.

## Serializers in this suite (16)

Registered in [`python/src/benchmark/runner.py`](../../python/src/benchmark/runner.py). Log names in `logs/python/YYYY-MM-DD-HHMMSS.csv` (nanoseconds). Modes: `bytes` and `stream`.

| Log name | Category | Package | Native input (`prepare_data`) | Stream mode | Notes |
|----------|----------|---------|---------------------------------|-------------|-------|
| json | JSON | stdlib | dict | adapted | Baseline text JSON |
| orjson | JSON | `orjson` | dict | adapted | Rust core; conversion untimed |
| msgspec | JSON | `msgspec` | Struct | native (`encode_into`) | Typed array-like Structs |
| rapidjson | JSON | `python-rapidjson` | dict | adapted | C++ RapidJSON bindings |
| pydantic | JSON | `pydantic` v2 | BaseModel | adapted | Validation-oriented API models |
| mashumaro | JSON | `mashumaro` | dataclass | adapted | ORJSONEncoder/Decoder |
| serpyco-rs | JSON | `serpyco-rs` + `orjson` | dataclass | adapted | dump/load + orjson wire |
| msgspec-msgpack | Binary | `msgspec` | Struct | native | Same Struct path, MessagePack |
| msgpack | Binary | `msgpack` | dict | native | Reference MessagePack |
| cbor2 | Binary | `cbor2` | dict | native | IETF CBOR (RFC 8949) |
| protobuf | Schema | `protobuf` | Message | adapted | From `schemas/benchmark_data.proto` |
| avro | Schema | `fastavro` | record dict | native | `.avsc` under `src/benchmark/` |
| flatbuffers | Schema | `flatbuffers` | dataclass → Builder | adapted | flatc schema; build timed |
| pickle | Native | stdlib | dataclass | native | Cycles supported; **unsafe** untrusted |
| cloudpickle | Native | `cloudpickle` | dataclass | native | Extended pickle; same security caveats |
| dill | Native | `dill` | dataclass | native | Scientific/multiprocess graphs |

### Call-path contract (fair timing)

Timed methods measure **codec only** on library-native values:

1. `prepare(name, type)` — encoders, schemas, buffers (untimed)
2. `prepare_data(obj, …)` — dataclass → dict / Struct / Message / Model (untimed)
3. `serialize_*` / `deserialize_*` — encode/decode only (timed)

FlatBuffers is the exception where Builder construction *is* the serialize API (no separate Message type). Stream mode is **native** when the library has a real file/stream API; otherwise **adapted** (bytes then write / read then bytes).

### Caveats

- **ObjectGraph:** only `pickle` / `cloudpickle` / `dill` expected to succeed.
- **Integer:** protobuf / avro / flatbuffers / serpyco-rs typically exclude bare scalars.
- `tracemalloc` under-counts C/Rust extension allocations.
- Fidelity is semantic, not strict type identity (dict vs dataclass, enum vs int, datetime ms truncation).

Harness: [`python/README.md`](../../python/README.md). [Serialization Categories](../analysis/serialization_categories.md).

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
