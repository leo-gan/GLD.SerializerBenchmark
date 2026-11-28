---
title: "Python"
---

# Python

Python serialization reflects a sharp boundary between CPython object-allocation overhead and compiled C/C++/Rust extensions. Libraries such as `orjson`, `msgspec`, `protobuf` (upb), and `pyarrow` move scanning and conversion into native code, whereas pure-Python paths (`dill`, Python `flatbuffers` Builder, pure-Python `Dagr`) execute inside the bytecode interpreter.

## Runtime & Environment

This runner executes under **CPython 3.12+** (not PyPy or Jython), managed via [`uv`](https://docs.astral.sh/uv/) and `python/pyproject.toml`. Every Python value is a heap-allocated object with reference counting and a cyclic garbage collector, guarded during bytecode execution by the Global Interpreter Lock (GIL). Consequently, decoding into dictionaries or `msgspec.Struct` C objects avoids Python-level class instantiation costs, while native extensions can also release the GIL during buffer processing (see [Latency tails and GC](../theory/301/latency-tails-and-gc.md)). Language semantics are defined by the [Python Language Reference](https://docs.python.org/3/reference/index.html).

| Property | Configuration |
|---|---|
| Language / spec | CPython 3.12+ (reference implementation; Python Language Reference) |
| Build & toolchain | `uv sync` (`python/pyproject.toml`, local `.venv`) |
| Memory model | Reference counting + cyclic garbage collector; GIL active for bytecode |
| Runner & logs | `python/scripts/run-benchmarks.sh` → `logs/python/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`python/src/benchmark/runner.py`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/python/src/benchmark/runner.py) |
| Data sets | `suite`, `columnar`, `graph`, `array`, `tensor` |

## Registered Serializers

`prepare_data` converts suite dataclasses to each library's native input (`dict`, `Struct`, `Message`, `BaseModel`, or generated node) outside the timer; exceptions for `columnar` and `flatbuffers` follow [Timing contract](../analysis/TIMING_HONESTY.md).

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [adios2](https://github.com/ornladios/ADIOS2) | `adios2` | `array` | `native` | Official ADIOS2 serial BP5 directory; `set_selection` for `grid_window` |
| [amazon-ion](https://github.com/amazon-ion/ion-python) | `ion` | `suite` | `native` | Official `amazon-ion` binary `simpleion` dump/load on `dict` |
| [arrow-ipc](https://arrow.apache.org/docs/python/ipc.html) | `arrow` | `columnar`, `tensor` | `adapted` | `pyarrow` IPC stream; `Table.from_pylist` timed; `table_project` uses `included_fields`; `tensor_view` returns stream buffer |
| [avro](https://github.com/fastavro/fastavro) | `avro` | `suite`, `columnar` | `adapted` | `fastavro` Cython `schemaless_writer` / `schemaless_reader` with cached `parse_schema` |
| [cbor2](https://github.com/agronholm/cbor2) | `cbor` | `suite` | `native` | IETF CBOR (RFC 8949) on `dict` |
| [cloudpickle](https://github.com/cloudpipe/cloudpickle) | `custom` | `suite`, `graph` | `native` | Extended Python `pickle` on dataclasses (unsafe on untrusted input) |
| [ctoon](https://github.com/MohammadRaziei/ctoon) | `toon` | `suite` | `adapted` | Python binding over C99 TOON core; size in UTF-8 bytes |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Pure-Python reflective runtime (`to_bytes` / `restore`), `frozen` positional layout |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Pure-Python reflective runtime, `frozen`+`packed` layout |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Pure-Python reflective runtime, `packed` tagged layout |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Pure-Python reflective runtime, `regular` vtable layout |
| [dill](https://github.com/uqfoundation/dill) | `custom` | `suite` | `native` | Pure-Python extended pickler on dataclasses (unsafe on untrusted input) |
| [flatbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite`, `columnar`, `tensor` | `adapted` | Pure-Python `Builder` on encode; zero-copy `GetRootAs` view on decode (`tensor_view` reads in place) |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | `pyfory` native mode on pre-registered dataclasses |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-python) | `kiln` | `suite`, `tensor` | `adapted` | `gld-kiln` 0.2.0 positional codec; `tensor_view` borrows `float32` payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `array`, `tensor` | `adapted` | Pure x86-64 Assembly Kiln v2 codec via thin CPython C extension (`libkiln_asm_bench.a`); `TableColumns` + `KILN_OPT_EMBEDDED` O(1) skip; KLNT v2 `grid_window` & zero-copy `memoryview` `tensor_view` |
| [h5py](https://docs.h5py.org/) | `hdf5` | `array` | `adapted` | Official `h5py` using HDF5 core virtual file driver; hyperslab read for `grid_window` |
| [json](https://github.com/python/cpython/tree/main/Lib/json) | `json` | `suite` | `adapted` | Stdlib `json.dumps` / `json.loads` on `dict` (compact baseline) |
| [mashumaro](https://github.com/Fatal1ty/mashumaro) | `json` | `suite` | `adapted` | Code-generated dataclass `ORJSONEncoder` / `ORJSONDecoder` |
| [msgpack](https://github.com/msgpack/msgpack-python) | `msgpack` | `suite` | `native` | Official PyPI `msgpack` C extension on `dict` (named maps) |
| [msgspec](https://github.com/jcrist/msgspec) | `json` | `suite` | `native` | Typed `msgspec.Struct` (`array_like=True`) JSON via `encode_into` |
| [msgspec-msgpack](https://github.com/jcrist/msgspec) | `msgpack` | `suite` | `native` | Same typed `msgspec.Struct` (`array_like=True`) MessagePack encoder/decoder |
| [netCDF4](https://unidata.github.io/netcdf4-python/) | `netcdf` | `array` | `adapted` | Official `netCDF4` file write/read; slice read for `grid_window` |
| [orc](https://arrow.apache.org/docs/python/orc.html) | `orc` | `columnar` | `adapted` | `pyarrow.orc.write_table` / `read_table` (pyarrow defaults to uncompressed); `table_project` passes `columns=['f_float_0']` |
| [orc-uncompressed](https://arrow.apache.org/docs/python/orc.html) | `orc` | `columnar` | `adapted` | Explicit `compression="uncompressed"` (identical bytes to `orc` on pyarrow 25) |
| [orjson](https://github.com/ijl/orjson) | `json` | `suite`, `columnar` | `adapted` | Rust `orjson.dumps` / `loads` on pre-built `dict` |
| [parquet](https://arrow.apache.org/docs/python/parquet.html) | `parquet` | `columnar` | `adapted` | `pyarrow.parquet` with library-default Snappy pages; `table_project` passes `columns=['f_float_0']` |
| [parquet-uncompressed](https://arrow.apache.org/docs/python/parquet.html) | `parquet` | `columnar` | `adapted` | Same `pyarrow.parquet` writer with `compression="NONE"` |
| [pickle](https://github.com/python/cpython/tree/main/Lib/pickle.py) | `custom` | `suite`, `graph` | `native` | Stdlib C `_pickle` on dataclasses (cycles supported; unsafe on untrusted input) |
| [protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite`, `columnar` | `adapted` | Official `protobuf` (upb C core) on generated `benchmark_v2.proto` messages |
| [py3amf-amf0](https://github.com/zhangxaochen/Py3AMF) | `amf0` | `suite` | `adapted` | `Py3AMF` AMF0 (`pyamf.encode` / `decode` on `dict`; numbers as doubles) |
| [py3amf-amf3](https://github.com/zhangxaochen/Py3AMF) | `amf3` | `suite` | `adapted` | `Py3AMF` AMF3 (`pyamf.encode` / `decode` on `dict`; compact ints/references) |
| [pydantic](https://github.com/pydantic/pydantic) | `json` | `suite` | `adapted` | Validation-oriented `BaseModel` (`model_dump_json` / `TypeAdapter`) |
| [rapidjson](https://github.com/python-rapidjson/python-rapidjson) | `json` | `suite` | `adapted` | C++ RapidJSON bindings (`dumps` / `loads` on `dict`) |
| [serpyco-rs](https://github.com/opengovsg/serpyco-rs) | `json` | `suite` | `adapted` | Rust-accelerated dataclass dump/load over `orjson` |
| [toon-format](https://github.com/toon-format/toon-python) | `toon` | `suite` | `adapted` | Official Python TOON codec; size in UTF-8 bytes (not token count) |
| [toons](https://github.com/alesanfra/toons) | `toon` | `suite` | `adapted` | Rust-backed Python TOON codec (`dumps` / `loads`); size in UTF-8 bytes |
| [yaml](https://github.com/yaml/pyyaml) | `yaml` | `suite` | `text_on_stream` | `PyYAML` `safe_dump` / `safe_load` |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[adios2](https://github.com/ornladios/ADIOS2)** — adios2 is the official ADIOS2 Python API. The engine is BP5 and MPI is off. This row times one float64 variable named grid. grid_window reads with a 0-based start and count. The buffer is a packed copy of the BP5 directory. The row does not time the five suite types.
    - **[amazon-ion](https://github.com/amazon-ion/ion-python)** — Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. ion-python is the official Python implementation.
    - **[arrow-ipc](https://arrow.apache.org/docs/python/ipc.html)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times pyarrow's IPC stream writer and reader inside the suite's bytes mode, not the Arrow file format. Schema objects are selected in prepare. Row-to-column conversion stays inside serialize. table_project deserialize reads f_float_0 only. On the tensor data set this row runs every type. The matrix, the prompt, and the shard are IPC tensor messages. request is those prompt tensors plus one record batch in the same buffer. tensor_view returns a buffer inside the stream.
    - **[avro](https://github.com/fastavro/fastavro)** — fastavro is a Cython Avro reader/writer for Python. Avro was created so data systems could store compact records with the schema out of band. fastavro solves the CPython performance problem of the older pure-Python Avro stack.
    - **[cbor2](https://github.com/agronholm/cbor2)** — cbor2 is a Python implementation of IETF CBOR (RFC 8949). CBOR was created as a binary JSON-like format for constrained devices and IETF protocols. cbor2 solves the Python side with a widely used encoder/decoder.
    - **[cloudpickle](https://github.com/cloudpipe/cloudpickle)** — cloudpickle extends pickle so cluster and serverless runtimes can ship functions and dynamic objects, not just importable classes. The problem was that pickle cannot serialize many constructs that job schedulers need. cloudpickle solves that by capturing more of the Python object model — with the same security caveats.
    - **[ctoon](https://github.com/MohammadRaziei/ctoon)** — ctoon is a C99 TOON core. This row is the Python binding. The timed path is dumps and loads. The Size column is the UTF-8 byte length.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.
    - **[dill](https://github.com/uqfoundation/dill)** — dill extends pickle further for scientific Python: graphs, lambdas, and interpreter state. The problem was that pickle and even cloudpickle still failed on objects researchers actually use. dill solves that with a broader, mostly pure-Python save path.
    - **[flatbuffers](https://github.com/google/flatbuffers)** — FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place. On the tensor data set the Builder runs every type: tensor, tensor_view, prompt, shard, and request. tensor_view reads the float vector in place.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses pyfory in native mode on registered dataclasses.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-python)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) bound via thin CPython C-API extension statically linking shared `libkiln_asm_bench.a`. Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), `array` (KLNT v2 `grid` + strided `grid_window`), and `tensor` (KLNT v2 with zero-copy `memoryview` `tensor_view`).
    - **[h5py](https://docs.h5py.org/)** — h5py is the standard Python binding for HDF5. This row times the array data set: one contiguous float64 dataset named grid on the core virtual file driver. The byte size is the flushed file image. grid_window reads an interior hyperslab. The row does not time the five suite types.
    - **[json](https://github.com/python/cpython/tree/main/Lib/json)** — The CPython `json` module is the language's standard JSON encoder/decoder (RFC 8259). It was added so Python programs had a stdlib way to speak the web's data format. The implementation is a C-accelerated codec over Python objects; this suite times that path as the baseline.
    - **[mashumaro](https://github.com/Fatal1ty/mashumaro)** — mashumaro was written to serialize Python dataclasses to JSON and other formats with code generation, not runtime reflection on every call. The problem was slow dataclass codecs. This row times the ORJSON encoder/decoder path.
    - **[msgpack](https://github.com/msgpack/msgpack-python)** — msgpack-python is the official MessagePack implementation for Python. MessagePack was created to be as compact as a binary format and as simple as JSON. The package exposes pack/unpack (and stream APIs) on Python objects.
    - **[msgspec](https://github.com/jcrist/msgspec)**, **[msgspec-msgpack](https://github.com/jcrist/msgspec)** — msgspec was created as a high-performance serialization library for Python with typed structures, not just dicts. The problem was that fast JSON libraries still paid for untyped Python objects, and validation libraries were slow. msgspec solves it with array-like Structs and a compiled encode/decode path (JSON and MessagePack).
        - `msgspec-msgpack`: This row times the MessagePack encoder/decoder on the same Struct types.
    - **[netCDF4](https://unidata.github.io/netcdf4-python/)** — netCDF4 is the Python interface to the NetCDF C library. This row times one float64 variable named grid in a NetCDF-4 file. grid_window reads that variable with a 0-based slice. The returned buffer is the file. The row does not time the five suite types.
    - **[orc](https://arrow.apache.org/docs/python/orc.html)** — Apache ORC was created at Hive as a columnar stripe file with indexes and compression. This row times pyarrow.orc.write_table and read_table with no compression argument. pyarrow's default is uncompressed. Apache ORC's own C++ and Java writers default to Zlib; this binding does not. table_project passes columns=['f_float_0'] on read.
    - **[orc-uncompressed](https://arrow.apache.org/docs/python/orc.html)** — This is the same pyarrow ORC writer as orc, with compression='uncompressed'. On pyarrow 25 that codec is also the default, so the bytes match orc. The name stays so the allow-list matches languages whose ORC writer defaults to Zlib.
    - **[orjson](https://github.com/ijl/orjson)** — orjson was written to give CPython a JSON codec that is both fast and correct. The problem was that stdlib `json` is slow on large payloads, while many speed-focused alternatives cut corners on Unicode, strictness, or types. orjson solves that with a Rust extension that implements RFC 8259 on dataclasses and common types.
    - **[parquet](https://arrow.apache.org/docs/python/parquet.html)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times pyarrow.parquet.write_table and read_table with pyarrow's default page compression, Snappy. Encodings stay at the library default. table_project passes columns=['f_float_0'] on read.
    - **[parquet-uncompressed](https://arrow.apache.org/docs/python/parquet.html)** — This is the same pyarrow Parquet writer as parquet, with compression='NONE'. Encodings stay at the library default. The name is the override. Use this size when the question is layout rather than Snappy.
    - **[pickle](https://github.com/python/cpython/tree/main/Lib/pickle.py)** — pickle is CPython's native object serializer. It exists so Python processes can snapshot almost any object graph. That power is also the problem: loading untrusted pickle can run arbitrary code. This row times the stdlib C implementation.
    - **[protobuf](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[py3amf-amf0](https://github.com/zhangxaochen/Py3AMF)**, **[py3amf-amf3](https://github.com/zhangxaochen/Py3AMF)** — Py3AMF is a Python 3 fork of PyAMF implementing Adobe Action Message Format (AMF0/AMF3) over Python dictionaries via `pyamf.encode` and `pyamf.decode`.
        - `py3amf-amf0`: Uses AMF0 (RTMP command encoding), where every number is written as an IEEE 754 double.
        - `py3amf-amf3`: Uses AMF3, which encodes small integers compactly and supports reference sharing for repeated strings and objects.
    - **[pydantic](https://github.com/pydantic/pydantic)** — Pydantic was created to validate and serialize Python data for APIs (later FastAPI). The problem was that ad-hoc dicts and hand-written validators were error-prone. Pydantic solves it with typed models and JSON dump/load (`model_dump_json` / TypeAdapter).
    - **[rapidjson](https://github.com/python-rapidjson/python-rapidjson)** — python-rapidjson wraps Tencent RapidJSON so CPython can use that C++ parser/generator. RapidJSON was written for speed with a SAX and DOM API. The Python binding exposes `dumps`/`loads` on dicts.
    - **[serpyco-rs](https://github.com/opengovsg/serpyco-rs)** — serpyco-rs is a fast dataclass JSON serializer (Rust core) for Python. The problem was that dataclass-to-JSON in pure Python is slow. It solves that by compiling the dump/load path and using orjson on the wire.
    - **[toon-format](https://github.com/toon-format/toon-python)** — toon-format is the official Python codec for TOON, a text encoding of the JSON data model made so prompts can carry the same values in fewer tokens. The timed path is encode and decode. The Size column is the UTF-8 byte length. A token count is a separate measure and is not timed.
    - **[toons](https://github.com/alesanfra/toons)** — toons is a Python TOON codec whose core is Rust. It speaks the same JSON data model through loads and dumps. The timed path is that text. The Size column is the UTF-8 byte length, not a token count.
    - **[yaml](https://github.com/yaml/pyyaml)** — PyYAML is the long-standing YAML 1.1 processor for Python. YAML was created as a human-friendly superset of JSON for config and documents. PyYAML implements that model with dump/load.

## Measurement Caveats

- **Pure-Python vs. C-core gaps:** `flatbuffers` serialize builds via a pure-Python `Builder` (orders of magnitude slower than C++/Rust FlatBuffers, whereas decode returns a zero-copy `GetRootAs` view without forcing full materialization). `dill` serialize uses a pure-Python dispatch path (~15–20× slower than C `pickle`). All four `dagr-*` rows run a pure-Python reflective runtime (`to_bytes` / `restore`) with $N > 1$ framed as `[u32 count][u32 len][record]` (404 B framing overhead at $N = 100$). `fastavro` (Cython) still walks Python dicts and unions, lagging upb-backed `protobuf` on nested structures.
- **Columnar and array boundaries:** Per [Timing contract rule 8](../analysis/TIMING_HONESTY.md), `pyarrow` rows select schemas in `prepare` and time `Table.from_pylist` inside `serialize_bytes`, while `table_project` projects `f_float_0` directly (`IpcReadOptions.included_fields` or `columns=["f_float_0"]`). `h5py`, `netCDF4`, and `adios2` run on `array` only.
- **Security and instrumentation:** `pickle`, `cloudpickle`, and `dill` execute arbitrary code on untrusted input and are Python-only. `tracemalloc` is disabled during timed loops (it inflated allocation-heavy codecs 2–3×) and under-counts native C/Rust allocations. Fidelity checks are semantic (dict vs. dataclass, enum vs. int, millisecond timestamp truncation).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Python)](../dashboard/index.html?lang=python&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Python)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Python: `orjson` vs. stdlib `json`](../analysis/call-sites/python-orjson-vs-json.md) · [Python: `msgspec` JSON vs. MessagePack](../analysis/call-sites/python-msgspec-json-vs-msgpack.md) · [4.3 Python: `google.protobuf`](../theory/401/protobuf-python.md) · [4.8 Python: `msgspec-msgpack` vs. `orjson`](../theory/401/python-msgspec-vs-orjson.md)
- **Build & run guide:** [`python/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/python/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
