# The Python Ecosystem: Navigating the GIL and C-Extensions

Python's dynamic nature makes serialization uniquely challenging. While it excels at developer productivity, the runtime overhead of object instantiation and the Global Interpreter Lock (GIL) can severely bottleneck high-throughput data processing pipelines.

## Serializers in this suite (10)

Registered in [`python/src/benchmark/runner.py`](../../python/src/benchmark/runner.py). Log names in `logs/python/benchmark-log.csv` (nanoseconds). Modes: `bytes` and `stream`.

| Log name | Category | Package | Notes |
|----------|----------|---------|-------|
| orjson | JSON | `orjson` | Rust core; dataclasses / datetime via `default` |
| msgspec | JSON | `msgspec` | Typed `Struct` models; reusable encoder/decoder |
| rapidjson | JSON | `python-rapidjson` | C++ RapidJSON bindings |
| msgspec-msgpack | Binary | `msgspec` | Same Struct path, MessagePack codec |
| msgpack | Binary | `msgpack` | Reference MessagePack |
| cbor2 | Binary | `cbor2` | IETF CBOR (RFC 8949) |
| protobuf | Schema | `protobuf` | From `schemas/benchmark_data.proto` |
| avro | Schema | `fastavro` | `.avsc` under `src/benchmark/` |
| pickle | Native | stdlib | Cycles supported; **unsafe** on untrusted data |
| cloudpickle | Native | `cloudpickle` | Extended pickle; same security caveats |

**Not in this suite:** stdlib `json`, `ujson`, Pydantic, `dill`, FlatBuffers for Python.

### Caveats

- **ObjectGraph:** only `pickle` / `cloudpickle` expected to succeed.
- **Integer:** protobuf / avro typically exclude bare scalars.
- msgspec paths convert dataclasses to `Struct` **outside** timed loops.
- `tracemalloc` under-counts C/Rust extension allocations.
- Fidelity is semantic, not strict type identity.

Harness: [`python/README.md`](../../python/README.md). [Selection Guide](../serializers/index.md) · [Serialization Categories](../analysis/serialization_categories.md).

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
