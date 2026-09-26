---
title: "Python"
---

Python
======

Python's dynamic nature makes serialization uniquely challenging. While it excels at developer productivity, the runtime overhead of object instantiation and the Global Interpreter Lock (GIL) can severely bottleneck high-throughput data processing pipelines.

## Runtime

### What it is

This suite measures **CPython**, the usual C implementation of the Python interpreter. Other implementations such as PyPy are not used here. CPython compiles source to bytecode and then runs that bytecode in a virtual machine. Almost every value is a heap object with a type pointer and a reference count. That design makes Python easy to write and expensive to decode into, because even a small integer is a full object.

The **Global Interpreter Lock (GIL)** is a lock that lets only one thread run Python bytecode at a time inside a process. If a decode takes 10 ms of Python bytecode, the whole process is blocked for those 10 ms, unless the library releases the GIL while it works in C, C++, or Rust.

| | This suite |
|---|---|
| Interpreter | CPython **3.12 or newer**. Not PyPy or Jython. |
| Host toolchain | [uv](https://docs.astral.sh/uv/) (`uv sync`) |
| Prepare | `./scripts/install-host-requirements.sh python` |
| Run | `python/scripts/run-benchmarks.sh` |
| Memory | Reference counting plus a cyclic garbage collector. The GIL is present. |

### What this suite runs

`python/pyproject.toml` requires Python 3.12 or newer. The `uv` tool creates a local virtual environment and installs the packages listed in the lock file. The benchmark runner is ordinary CPython on the command line. It is not a web server such as FastAPI or Flask.

### What changes the numbers

Libraries with a C or Rust core, such as `orjson`, `msgspec`, and `protobuf`, spend most of the timed path outside the interpreter. They can release the GIL while they parse bytes. Pure-Python paths, such as `dill` serialize and the official FlatBuffers Builder, stay inside the virtual machine and look much slower.

Deserializing into a `dict` is usually cheaper than building a class or a Pydantic model, because constructing Python objects is itself expensive. The `tracemalloc` tool under-counts allocations that happen inside C or Rust extensions.

### Suite-specific gotchas

The official FlatBuffers Python package builds with a pure-Python Builder. The C++ and Rust FlatBuffers libraries are a different speed class. This suite measures the Python binding. See [caveats](#why-flatbuffers-and-dill-opss-look-low).

`pickle`, `cloudpickle`, and `dill` work only in Python. Loading untrusted input with them can run arbitrary code.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`python/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/python/README.md). The language overview is [The Python interpreter](https://docs.python.org/3/tutorial/interpreter.html). For the GIL and garbage collection in latency, see [Latency tails and GC](../theory/301/latency-tails-and-gc.md).

## Benchmark runner

- Directory: `python/` (repository root)
- Output: monorepo `logs/python/YYYY-MM-DD-HHMMSS.csv` (`Language=python`, times in **nanoseconds**)
- Runner: `python/scripts/run-benchmarks.sh` (or project docs for modes)
- Registration: [`python/src/benchmark/runner.py`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/python/src/benchmark/runner.py)
- Modes: `bytes` and `stream`

## Serializers

| Log name | Category | Package | Native input (`prepare_data`) | Stream mode | Notes |
|----------|----------|---------|---------------------------------|-------------|-------|
| [avro](https://github.com/fastavro/fastavro) | Schema | `fastavro` | record dict | adapted | Compact schemaless size; dict/union path slower than protobuf C++ |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | Schema | generated (`dagr build`, runtime shipped in-tree) | dataclass → generated `@dataclass` node | adapted | Pure-Python reflective runtime (eager `to_bytes` / `restore`); ~35–390× slower than protobuf (upb), size ≈ protobuf. See [caveat](#why-dagr-opss-look-low) |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | Schema | generated (`dagr build`, runtime shipped in-tree) | dataclass → generated `@dataclass` node | adapted | Same runtime and call path as `dagr-packed`; regular (vtable) nodes — evolvable, larger than `packed`. See [layouts](#dagr-node-layouts) |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | Schema | generated (`dagr build`, runtime shipped in-tree) | dataclass → generated `@dataclass` node | adapted | `frozen` (positional) nodes — no schema evolution. See [layouts](#dagr-node-layouts) |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | Schema | generated (`dagr build`, runtime shipped in-tree) | dataclass → generated `@dataclass` node | adapted | `frozen`+`packed` (positional, self-sizing) — smallest Dagr row, no schema evolution. See [layouts](#dagr-node-layouts) |
| [cbor2](https://github.com/agronholm/cbor2) | Binary | `cbor2` | dict | native | IETF CBOR (RFC 8949) |
| [cloudpickle](https://github.com/cloudpipe/cloudpickle) | Native | `cloudpickle` | dataclass | native | Extended pickle; same security caveats |
| [dill](https://github.com/uqfoundation/dill) | Native | `dill` | dataclass | native | Graphs/dynamics; **ser** much slower than pickle (pure-Python dispatch) |
| [flatbuffers](https://github.com/google/flatbuffers) | Schema | `flatbuffers` | dataclass → Builder | adapted | Python Builder ser is slow; deser is zero-copy `GetRootAs` view |
| [json](https://github.com/python/cpython/tree/main/Lib/json) | JSON | stdlib | dict | adapted | Baseline text JSON |
| [mashumaro](https://github.com/Fatal1ty/mashumaro) | JSON | `mashumaro` | dataclass | adapted | ORJSONEncoder/Decoder |
| [msgpack](https://github.com/msgpack/msgpack-python) | Binary | `msgpack` | dict | native | Reference MessagePack |
| [msgspec](https://github.com/jcrist/msgspec) | JSON | `msgspec` | Struct | native (`encode_into`) | Typed array-like Structs |
| [msgspec-msgpack](https://github.com/jcrist/msgspec) | Binary | `msgspec` | Struct | native | Same Struct path, MessagePack |
| [orjson](https://github.com/ijl/orjson) | JSON | `orjson` | dict | adapted | Rust core; conversion untimed |
| [pickle](https://github.com/python/cpython/tree/main/Lib/pickle.py) | Native | stdlib | dataclass | native | Cycles supported; **unsafe** untrusted |
| [protobuf](https://github.com/protocolbuffers/protobuf) | Schema | `protobuf` | Message | adapted | From suite protobuf schemas under `schemas/v2/` / language generated modules |
| [pydantic](https://github.com/pydantic/pydantic) | JSON | `pydantic` | BaseModel | adapted | Validation-oriented API models |
| [rapidjson](https://github.com/python-rapidjson/python-rapidjson) | JSON | `python-rapidjson` | dict | adapted | C++ RapidJSON bindings |
| [serpyco-rs](https://github.com/opengovsg/serpyco-rs) | JSON | `serpyco-rs` + `orjson` | dataclass | adapted | dump/load + orjson wire |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [avro](https://github.com/fastavro/fastavro) · `1.12.2`

fastavro is a Cython Avro reader/writer for Python. Avro was created so data systems could store compact records with the schema out of band. fastavro solves the CPython performance problem of the older pure-Python Avro stack.

#### [dagr](https://codeberg.org/mzaks/dagr)

Dagr ("Data Graph") is a schema-driven binary format for data graphs — shared and cyclic nodes included — built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The `dagr-packed` row uses the `packed` layout. The timed path is `<graph>.to_bytes(node)` on encode and the eager `<graph>.restore(bytes)` on decode. The Python target has no lazy reader and no direct builder.

##### Dagr node layouts

The schema emits every suite type in four node layouts (spec/16 of the Dagr repo). Each gets its own generated module (`message_graph`, `message_regular_graph`, `message_frozen_graph`, `message_frozen_packed_graph`, …), and one `DagrSerializer(flavour)` serves all four rows:

| Row | Layout | Evolution | Size, n=1 (message / document / telemetry / strings / event, bytes) |
|-----|--------|-----------|------------------------------------------------------------------|
| `dagr-packed` | `packed` (tagged) | add / deprecate fields | 54 / 161 / 304 / 328 / 158 |
| `dagr-regular` | regular (vtable) | add / deprecate fields | 64 / 240 / 307 / 392 / 171 |
| `dagr-frozen` | `frozen` (positional) | none | 55 / 223 / 302 / 390 / 161 |
| `dagr-frozen-packed` | `frozen`+`packed` | none | 48 / 150 / 302 / 328 / 151 |

Sizes are for seed 42 and vary a few bytes with the run's seed. The frozen rows give up all schema evolution, so compare them with fixed-schema codecs, not with protobuf.

#### [cbor2](https://github.com/agronholm/cbor2) · `6.1.4`

cbor2 is a Python implementation of IETF CBOR (RFC 8949). CBOR was created as a binary JSON-like format for constrained devices and IETF protocols. cbor2 solves the Python side with a widely used encoder/decoder.

#### [cloudpickle](https://github.com/cloudpipe/cloudpickle) · `3.1.2`

cloudpickle extends pickle so cluster and serverless runtimes can ship functions and dynamic objects, not just importable classes. The problem was that pickle cannot serialize many constructs that job schedulers need. cloudpickle solves that by capturing more of the Python object model — with the same security caveats.

#### [dill](https://github.com/uqfoundation/dill) · `0.4.1`

dill extends pickle further for scientific Python: graphs, lambdas, and interpreter state. The problem was that pickle and even cloudpickle still failed on objects researchers actually use. dill solves that with a broader, mostly pure-Python save path.

#### [flatbuffers](https://github.com/google/flatbuffers) · `25.12.19`

FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.

#### [json](https://github.com/python/cpython/tree/main/Lib/json) · `python-3.14.0`

The CPython `json` module is the language's standard JSON encoder/decoder (RFC 8259). It was added so Python programs had a stdlib way to speak the web's data format. The implementation is a C-accelerated codec over Python objects; this suite times that path as the baseline.

#### [mashumaro](https://github.com/Fatal1ty/mashumaro) · `3.22`

mashumaro was written to serialize Python dataclasses to JSON and other formats with code generation, not runtime reflection on every call. The problem was slow dataclass codecs. This row times the ORJSON encoder/decoder path.

#### [msgpack](https://github.com/msgpack/msgpack-python) · `1.2.2`

msgpack-python is the official MessagePack implementation for Python. MessagePack was created to be as compact as a binary format and as simple as JSON. The package exposes pack/unpack (and stream APIs) on Python objects.

#### [msgspec](https://github.com/jcrist/msgspec) · `0.21.1`

msgspec was created as a high-performance serialization library for Python with typed structures, not just dicts. The problem was that fast JSON libraries still paid for untyped Python objects, and validation libraries were slow. msgspec solves it with array-like Structs and a compiled encode/decode path (JSON and MessagePack).

#### [msgspec-msgpack](https://github.com/jcrist/msgspec) · `0.21.1`

msgspec was created as a high-performance serialization library for Python with typed structures, not just dicts. The problem was that fast JSON libraries still paid for untyped Python objects, and validation libraries were slow. msgspec solves it with array-like Structs and a compiled encode/decode path (JSON and MessagePack). This row times the MessagePack encoder/decoder on the same Struct types.

#### [orjson](https://github.com/ijl/orjson) · `3.12.0`

orjson was written to give CPython a JSON codec that is both fast and correct. The problem was that stdlib `json` is slow on large payloads, while many speed-focused alternatives cut corners on Unicode, strictness, or types. orjson solves that with a Rust extension that implements RFC 8259 on dataclasses and common types.

#### [pickle](https://github.com/python/cpython/tree/main/Lib/pickle.py) · `python-3.14.0`

pickle is CPython's native object serializer. It exists so Python processes can snapshot almost any object graph. That power is also the problem: loading untrusted pickle can run arbitrary code. This row times the stdlib C implementation.

#### [protobuf](https://github.com/protocolbuffers/protobuf) · `7.36.1`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [pydantic](https://github.com/pydantic/pydantic) · `2.13.5`

Pydantic was created to validate and serialize Python data for APIs (later FastAPI). The problem was that ad-hoc dicts and hand-written validators were error-prone. Pydantic solves it with typed models and JSON dump/load (`model_dump_json` / TypeAdapter).

#### [rapidjson](https://github.com/python-rapidjson/python-rapidjson) · `1.25`

python-rapidjson wraps Tencent RapidJSON so CPython can use that C++ parser/generator. RapidJSON was written for speed with a SAX and DOM API. The Python binding exposes `dumps`/`loads` on dicts.

#### [serpyco-rs](https://github.com/opengovsg/serpyco-rs) · `1.22.0`

serpyco-rs is a fast dataclass JSON serializer (Rust core) for Python. The problem was that dataclass-to-JSON in pure Python is slow. It solves that by compiling the dump/load path and using orjson on the wire.

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

#### Why dagr ops/s look low

- **Pure-Python runtime:** the Dagr Python target is a reflective runtime (typed `@dataclass` layer over a generic node model); there is no C extension. `serialize` is `<graph>.to_bytes(node)` on nodes built in `prepare_data`, `deserialize` is `<graph>.restore(bytes)` back to the generated dataclasses (eager — Python has no lazy reader). Peer-smoke medians: ~20–75× slower than `protobuf` (upb C core) on single messages and ~40–125× on n=100 cells (protobuf's packed `repeated double` is close to a memcpy in C). Size is within a few % of protobuf, and smaller on `strings`.
- **Hot-path audit:** cProfile shows no per-call imports or schema loading. The generated module caches the schema's per-node facts once (lookup, field plans, elidability). Its dataclasses feed the serializer directly and are built directly by `restore`, with no intermediate node graph, so what remains is the per-field Python work.
- **Layouts:** all four `dagr*` rows run the same reflective runtime, so their ops/s differ only by the per-layout work in the runtime, not by a different code path.
- **Framing:** N>1 cells encode N independent Dagr buffers in a `u32 count` + `u32 len` frame (same frame as the Rust `dagr-packed` row, used by all four `dagr*` rows), so n=100 carries 404 bytes of framing that protobuf's `Batch*` wrapper does not.

### Other caveats

- `tracemalloc` under-counts C/Rust extension allocations.
- Fidelity is semantic, not strict type identity (dict vs dataclass, enum vs int, datetime ms truncation).

Benchmark runner: [`python/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/python/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=python&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
