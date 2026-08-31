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

Benchmark runner: [`python/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/python/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=python&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
