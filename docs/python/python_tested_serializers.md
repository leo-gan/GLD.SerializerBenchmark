# Python Tested Serializers

All **10** entries below are registered in [`python/src/benchmark/runner.py`](../../python/src/benchmark/runner.py) (`ALL_SERIALIZERS`). **Log name** is `SerializerName` in `logs/python/benchmark-log.csv`. Times are **nanoseconds**. Modes: `bytes` and `stream` (BytesIO adaptation when the library has no native stream API).

**Not in this suite:** stdlib `json`, `ujson`, Pydantic (validation, not a harness entry), `dill`, FlatBuffers for Python.

Format advice: [Selection Guide](../serializers/index.md). Suite categories: [Serialization Categories](../analysis/serialization_categories.md).

| Log name | Category | Package | Notes |
|----------|----------|---------|-------|
| orjson | JSON | `orjson` | Rust core; dataclasses / datetime via `default` |
| msgspec | JSON | `msgspec` | Typed `Struct` models (`array_like`); reusable encoder/decoder |
| rapidjson | JSON | `python-rapidjson` | C++ RapidJSON bindings; hooks for dataclasses |
| msgspec-msgpack | Binary | `msgspec` | Same Struct path as msgspec JSON, MessagePack codec |
| msgpack | Binary | `msgpack` | Reference MessagePack; `default` / `object_hook` for dataclasses |
| cbor2 | Binary | `cbor2` | IETF CBOR (RFC 8949); cycle support optional, not used for ObjectGraph here |
| protobuf | Schema | `protobuf` | Generated code from `schemas/benchmark_data.proto` |
| avro | Schema | `fastavro` | Schemas under `src/benchmark/` (`.avsc`) |
| pickle | Native | stdlib | Cycles supported; **unsafe** on untrusted data |
| cloudpickle | Native | `cloudpickle` | Extended pickle for dynamic / distributed use; same security caveats |

## Caveats (read before citing)

- **ObjectGraph** (cycles): only **pickle** and **cloudpickle** are expected to succeed. JSON / MessagePack / CBOR / protobuf / avro entries skip or fail cycles by design in this harness.
- **Integer** (bare primitive): **protobuf** and **avro** typically exclude bare scalars (schema messages only).
- **msgspec** / **msgspec-msgpack** convert shared dataclass fixtures to msgspec `Struct` instances **outside** timed loops (fair for typed codecs, not for “raw dict” JSON).
- **protobuf** / **avro** use code/schema generation; datetime often becomes epoch milliseconds (microsecond truncation).
- **tracemalloc** peak memory under-counts allocations inside C/Rust extensions (orjson, msgpack, etc.).
- Fidelity is **semantic** (e.g. datetime vs ISO string, tuple vs list), not strict Python type identity.
- Security: never unpickle untrusted payloads (**pickle** / **cloudpickle**).

## Related

- Harness: [`python/README.md`](../../python/README.md)
- Ecosystem context: [Python overview](index.md)
