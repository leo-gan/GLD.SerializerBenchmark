# Python: google.protobuf encode/decode path

## Why this article exists

Python services often “use Protocol Buffers” through generated `*_pb2.py` modules without a clear picture of **what is timed in a benchmark**, **who owns the output bytes**, **which runtime backend runs under the hood**, and **how that backend turns a message into wire tags**. Reading only client call sites does not train serializer developers.

In this article you will follow the path from a `.proto` file through code generation, backend selection, and the public encode/decode APIs. After reading it, you should be able to explain who allocates the output `bytes` object and what happens when `ParseFromString` differs from `MergeFromString`.

## Short answer

With the `google.protobuf` package, **`protoc`** (the Protocol Buffers compiler) generates message classes that implement the `Message` API—methods such as `SerializeToString` and `ParseFromString`. At import time the library selects an **implementation backend** (by default **upb**, a fast native core; otherwise pure Python; a legacy **cpp** extension still exists but is no longer what PyPI ships for ordinary installs). Serialize walks the message’s fields using **descriptors** (metadata that records field numbers and types) and emits standard Protocol Buffers binary. Parse consumes tags and fills a message instance.

In this benchmark suite, converting a domain object into a Message is untimed **`prepare_data`**. Timed work is only serialize and parse of the Message. This matters because Results pages are meant to compare codec work, not model-mapping work.

This article assumes the [wire format](protobuf-wire-format.md) article. Package: `protobuf` ([Python tutorial](https://protobuf.dev/getting-started/pythontutorial/), [encoding guide](https://protobuf.dev/programming-guides/encoding/), [python/README backends](https://github.com/protocolbuffers/protobuf/blob/main/python/README.md)).

**Suite pin (this monorepo):** `protobuf>=7.34.1,<8` in `python/pyproject.toml`. Patterns below track that line; always re-check your installed version.

## Prerequisites

- Serialization 201: schema-dependent encoding.
- Ability to read generated Python modules.
- Soft: [301 trust](../301/trust-boundaries.md) and [untrusted input](../301/untrusted-input.md).

## Mental model

**Codegen** (code generation) is the step that turns a `.proto` schema into language source files. In Python that produces modules whose names end in `_pb2.py`.

```text
  .proto
    │ protoc --python_out
    ▼
  *_pb2.py  (classes + DESCRIPTOR metadata)
    │
    │  runtime selects backend: upb  >  (legacy cpp)  >  pure python
    ▼
  Message instance  ──SerializeToString──►  bytes   (wire tags)
  Message instance  ◄─ParseFromString────  bytes
```

## Client path (what you write)

### 1. Codegen

In this step you run the Protocol Buffers compiler so it emits Python modules from your schema.

```bash
protoc -I schemas --python_out=python/generated schemas/v2/protobuf/benchmark_v2.proto
```

Generated modules define message classes whose field numbers come from the `.proto` file. Python attribute names are language bindings; **wire identity is the field number**, not the Python name. In other words, renaming a field in the `.proto` without changing its number does not change the wire layout.

### 2. Build a message (generated class)

```python
import benchmark_v2_pb2 as pb2  # illustrative import

msg = pb2.Message()  # any generated message class
msg.f_string = "Ada"
msg.f_int32 = 36
msg.f_bool = True
```

In proto3, unset scalars that still hold their default values are typically **omitted** on the wire. For example, an integer that is still zero often does not appear as a tag at all.

### 3. Teaching MiniUser (not suite codegen)

`MiniUser` is the teaching message from the [wire](protobuf-wire-format.md) and [lab](lab-mini-protobuf-encoder.md) articles. It is **not** part of the suite wire schema. Generate it from a local `mini.proto`:

```bash
protoc --python_out=. mini.proto   # defines message MiniUser
```

```python
import mini_pb2

msg = mini_pb2.MiniUser()
msg.id = 1
msg.name = "Ada"
data = msg.SerializeToString()   # b'\x08\x01\x12\x03Ada'
```

### 4. Encode / decode (API)

The same APIs work on any generated message (including teaching MiniUser):

```python
data: bytes = msg.SerializeToString()

# Replace semantics: clear message, then parse
out = pb2.Message()  # illustrative
out.ParseFromString(data)

# Or construct fresh:
out = type(msg).FromString(data)

# True merge into an existing message (does not clear first):
# out.MergeFromString(data)
```

Public API documentation: [Message.SerializeToString / ParseFromString](https://googleapis.dev/python/protobuf/latest/google/protobuf/message.html). The optional `deterministic=True` argument on serialize requests stable map-key ordering when maps are present.

## How the package implements serialization (step-by-step)

The logical flow is the same across backends. The package turns a populated message into wire bytes using **descriptors**—tables of field numbers, types, and labels that code generation baked in.

### S1 — Resolve backend

At import time the library selects an **implementation backend**:

- **upb** is the default in modern PyPI wheels. It is a native (C) implementation of Protocol Buffers that Python calls into.
- **pure Python** is the portable fallback when no native extension is available.
- A legacy **cpp** extension exists, but it is no longer what `pip install protobuf` ships for ordinary use.

You usually do not choose this explicitly. Set `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` (or `upb`) to force one backend for debugging or reproducible benchmarks.

### S2 — Field walk (descriptor-driven)

`SerializeToString()` iterates the message’s **present fields** using descriptor metadata (field numbers, types, labels). For each field it emits a **key** (field number plus wire type) followed by the payload. This is the same tag-plus-payload layout you saw in the wire format article.

### S3 — Emit tag + payload

Each field becomes exactly the tag-plus-payload pair described in the [wire format article](protobuf-wire-format.md):

- Varint types (integers, bool, enum) → key plus varint encoding.
- Fixed32/64 → key plus 4 or 8 little-endian bytes.
- String/bytes → key plus length varint plus raw data.
- Nested message → key plus length varint plus a recursive serialize of the submessage.

### S4 — Produce output bytes

The result is a new **immutable `bytes` object**. The **caller owns it**. No reference to the original message is retained inside that output. The garbage collector will reclaim the `bytes` object when nothing else refers to it.

```text
  Message fields
       │
       ▼
  S1  resolve backend (upb / pure Python)
       │
       ▼
  S2  descriptor walk (by field number)
       │
       ▼
  S3  emit key (varint) + payload (varint / fixed / LEN)
       │
       ▼
  S4  bytes (immutable, caller-owned)
```

### Decision frame: which backend matters?

| Situation | Practical note |
|-----------|----------------|
| You care about speed in hot paths | upb (the default) is usually best |
| You need zero-copy sharing with C++ | Legacy cpp extension (rare now) |
| You must run without any native extension | `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` |
| Benchmarking or debugging | Pin the backend via the environment variable for reproducibility |

## How the package implements deserialization (step-by-step)

### D1 — `ParseFromString` / `MergeFromString` / `FromString`

These three APIs look similar but mean different things. Choose carefully.

| API | Behavior |
|-----|----------|
| **`ParseFromString(data)`** | **Replace:** clears `self`, then parses `data` into it |
| **`MergeFromString(data)`** | **Merge:** does not clear; merges fields into the existing state |
| **`FromString(data)`** | Constructs a **new** message, then parses (replace into empty) |

1. The backend receives a pointer or view of the input buffer (zero-copy into C for upb when possible for the raw read; Python objects for field values are still allocated as needed).
2. Prefer `FromString` or a fresh instance plus `ParseFromString` when you want replace semantics. Use `MergeFromString` only when merge is intentional.

### D2 — Tag loop

While input remains:

1. Read the **key** varint and split it into `field_number` and `wire_type`.
2. Look up `field_number` in the message **descriptor**.
3. If the field is **known**, decode the payload for that field’s type and set or merge it into the message.
4. If the field is **unknown**, **skip** the payload using `wire_type` (and often retain unknown fields for round-trip, depending on backend and version).

This matches the decode loop in the wire article.

### D3 — Type-specific decode

| Wire/content | Action |
|--------------|--------|
| Varint field | Decode varint → store as int, bool, or enum |
| Fixed32/64 | Read 4 or 8 little-endian bytes |
| String | Read length plus UTF-8 → Python `str` |
| Bytes | Read length plus raw data → `bytes` |
| Nested message | Read a length-delimited slice → recursive parse into a submessage |
| Repeated | Append an element (or unpack a packed block into multiple elements) |
| Map | Decode as repeated entry messages → Python map |

### D4 — Merge semantics (when merging)

When you use **`MergeFromString`** (or merge paths inside nested updates), repeated fields append, singular scalars overwrite, and submessages merge field-by-field. That is why “parse into an already-filled message” with merge APIs can surprise you. Use `ParseFromString` or a fresh instance when you want replace.

### D5 — Allocate Python-visible structure

Even with upb, exposing fields to Python often materializes Python objects (`str`, list wrappers, submessage proxies). That cost is part of “Python Protocol Buffers,” not pure wire CPU time.

### D6 — Errors

Truncated input, illegal varints, or invalid UTF-8 (where checked) raise parse errors. Always bound untrusted input size **before** parse ([301 untrusted input](../301/untrusted-input.md)).

```text
  bytes  →  tag loop  →  descriptor lookup  →  set fields / skip unknown  →  Message
```

## Pure Python vs upb (what changes)

| Stage | Pure Python | upb (default wheel) |
|-------|-------------|---------------------|
| Field walk | Python loops in `internal` | Native C |
| Varint/tag | Python integer operations | Native |
| Nested | Recursive Python | Native plus a recursion limit |
| API | Same `Message` methods | Same |

The two backends are functionally interchangeable for ordinary use. Performance and some edge behaviors differ. Pin via `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` (or `upb`) and document the backend when you publish benchmarks.

## Buffers and ownership (simple diagram)

**Ownership** here means: who allocated this object, who is responsible for freeing it (or letting the garbage collector take it), and how long a buffer must stay valid.

```text
Python Message object
     │
     ▼ SerializeToString
new bytes (immutable, you own it)
     ▲
     │ ParseFromString
input bytes (or memoryview — underlying buffer must remain valid for the call)
```

| Object | Owner |
|--------|--------|
| Generated Message | Python garbage collector |
| `bytes` from serialize | Immutable; caller-owned |
| Parse input | Caller; ordinary `bytes` are fine; if you pass a view into a mutable buffer, keep that buffer alive for the call |
| Unknown fields | Held on the message when the backend retains them |

## In this suite

| Location | Role |
|----------|------|
| `python/src/benchmark/serializers/schema_protobuf.py` | `prepare_data` builds a Message; `serialize_bytes` calls `SerializeToString` |
| suite generated `*_pb2.py` modules | Generated suite messages—not MiniUser |
| Log name | `protobuf` |
| Pin | `protobuf>=7.34.1,<8` |
| [Python Results](../../python/results.md) | Cost under whatever backend the environment selected |

The benchmark runner keeps domain-to-Message conversion **out** of the timed path so Results compare codec work, not model mapping. Do not rank Python against Rust or C from Results alone ([cross-language fidelity](protobuf-cross-language-fidelity.md)).

## Common mistakes

- Timing `prepare_data` and serialize together.
- Assuming pure-Python behavior while upb is active (or the reverse).
- Using `MergeFromString` when you meant replace (`ParseFromString` or a fresh message).
- Mutating a message while another thread serializes it.
- Parsing untrusted bytes without size limits.
- Hand-editing `*_pb2.py`.
- Expecting `MiniUser` in suite-generated modules (it is a teaching schema only).

## What this article is not

- A line-by-line tour of the upb C sources.
- gRPC Python stubs.
- A from-scratch encoder (see the [lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- Client API path: **codegen → Message → SerializeToString / ParseFromString**.
- **ParseFromString** replaces (clear, then parse); **MergeFromString** merges.
- Implementation: a **backend** plus a **descriptor-driven** field walk produces wire tags.
- The default backend is **upb**; pure Python remains the portable fallback.
- Parallel articles: [Rust prost](protobuf-rust-prost.md), [C protobuf-c](protobuf-c-protobuf-c.md).
