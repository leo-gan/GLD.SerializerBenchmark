# Python: google.protobuf encode/decode path

## Problem

Python services often “use Protobuf” via generated `*_pb2.py` modules without a clear picture of **what is timed**, **what owns the bytes**, **which runtime backend runs under the hood**, and **how that backend turns a message into tags**. Client call sites alone do not train serializer developers.

## Short answer

With `google.protobuf`, `protoc` generates message classes that implement the `Message` API (`SerializeToString`, `ParseFromString`, …). At import time the library selects an **implementation backend** (default **upb**, else pure Python; legacy **cpp** exists but is no longer what PyPI ships). Serialize walks the message’s fields using **descriptors** (field numbers + types) and emits standard Protobuf binary; parse consumes tags and fills a message instance. In this suite, **dataclass → Message is untimed `prepare_data`**; timed work is serialize/parse of the Message.

Assumes [wire format](protobuf-wire-format.md). Package: `protobuf` ([Python tutorial](https://protobuf.dev/getting-started/pythontutorial/), [encoding guide](https://protobuf.dev/programming-guides/encoding/), [python/README backends](https://github.com/protocolbuffers/protobuf/blob/main/python/README.md)).

**Suite pin (this monorepo):** `protobuf>=7.34.1,<8` in `python/pyproject.toml`—patterns below track that line; always re-check your installed version.

## Prerequisites

- 201: schema-dependent encoding.  
- Ability to read generated Python modules.  
- Soft: [301 trust](../301/trust-boundaries.md) / [untrusted input](../301/untrusted-input.md).

## Mental model

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

```bash
protoc -I schemas --python_out=python/generated schemas/v2/protobuf/benchmark_v2.proto
```

Generated modules define message classes with field numbers from the `.proto`—Python attribute names are bindings, not wire identity.

### 2. Build a message (generated class)

```python
import benchmark_v2_pb2 as pb2  # illustrative import

msg = pb2.Message()  # any generated message class
msg.f_string = "Ada"
msg.f_int32 = 36
msg.f_bool = True
```

proto3: unset scalars with default values are typically **omitted** on the wire.

### 3. Teaching MiniUser (not suite codegen)

`MiniUser` is the [wire](protobuf-wire-format.md) / [lab](lab-mini-protobuf-encoder.md) teaching message. It is **not** part of the suite wire schema. Generate from a local `mini.proto`:

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

Same APIs on any generated message (including teaching MiniUser):

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

Public API documentation: [Message.SerializeToString / ParseFromString](https://googleapis.dev/python/protobuf/latest/google/protobuf/message.html). Optional `deterministic=True` on serialize requests stable map key ordering when maps are present.

## How the package implements serialization (step-by-step)

The logical flow is the same across backends. The package turns a populated message into wire bytes using **descriptors** (field numbers, types, labels) that come from code generation.

### S1 — Resolve backend

At import time the library selects an **implementation backend**: **upb** by default in modern PyPI wheels; **pure Python** as the portable fallback; legacy **cpp** extension exists but is no longer what `pip install protobuf` ships. You usually do not choose this explicitly; set `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` (or `upb`) to force one for debugging or benchmarks.

### S2 — Field walk (descriptor-driven)

`SerializeToString()` iterates the message's **present fields** using descriptor metadata (field numbers, types, labels) baked in at codegen time. For each field it emits a **key** (field number + wire type) followed by the payload.

### S3 — Emit tag + payload

Each field becomes exactly the tag + payload pair from the [wire format article](protobuf-wire-format.md):

- Varint types (int, bool, enum) → key + varint encoding.
- Fixed32/64 → key + 4/8 little-endian bytes.
- String/bytes → key + length varint + raw data.
- Nested message → key + length varint + recursive serialize of the submessage.

### S4 — Produce output bytes

The result is a new **immutable `bytes` object** — the caller owns it. No reference to the original message is retained in the output.

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
| You care about speed in hot paths | upb (default) is usually best |
| You need zero-copy sharing with C++ | Legacy cpp extension (rare now) |
| You must run without any native extension | `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` |
| Benchmarking or debugging | Pin backend via env var for reproducibility |

## How the package implements deserialization (step-by-step)

### D1 — `ParseFromString` / `MergeFromString` / `FromString`

| API | Behavior |
|-----|----------|
| **`ParseFromString(data)`** | **Replace:** clears `self`, then parses `data` into it |
| **`MergeFromString(data)`** | **Merge:** does not clear; merges fields into existing state |
| **`FromString(data)`** | Constructs a **new** message, then parse (replace into empty) |

1. Backend receives a pointer/view of the input buffer (zero-copy into C for upb when possible for the raw read; Python objects for field values are still allocated as needed).  
2. Prefer `FromString` or a fresh instance + `ParseFromString` when you want replace semantics; use `MergeFromString` only when merge is intentional.

### D2 — Tag loop

While input remains:

1. Read **key** varint → `field_number`, `wire_type`.  
2. Look up `field_number` in the message **descriptor**.  
3. If **known**: decode payload for that field’s type and **set/merge** into the message.  
4. If **unknown**: **skip** the payload using `wire_type` (and often retain unknown fields for round-trip, depending on backend/version).

This matches the decode loop in the wire article.

### D3 — Type-specific decode

| Wire/content | Action |
|--------------|--------|
| Varint field | Decode varint → store as int/bool/enum |
| Fixed32/64 | Read 4/8 little-endian bytes |
| String | Read len + UTF-8 → Python `str` |
| Bytes | Read len + raw → `bytes` |
| Nested message | Read len-delimited slice → recursive parse into submessage |
| Repeated | Append element (or unpack packed block into multiple elements) |
| Map | Decode as repeated entry messages → Python map |

### D4 — Merge semantics (when merging)

When using **`MergeFromString`** (or merge paths inside nested updates): repeated fields append; singulars overwrite; submessages merge field-by-field. That is why “parse into an already-filled message” with merge APIs can surprise you—use `ParseFromString` / fresh instance when you want replace.

### D5 — Allocate Python-visible structure

Even with upb, exposing fields to Python often materializes Python objects (`str`, `list` wrappers, submessage proxies). That cost is part of “Python Protobuf,” not pure wire CPU.

### D6 — Errors

Truncated input, illegal varints, or invalid UTF-8 (where checked) raise parse errors. Always bound untrusted input size **before** parse ([301 untrusted input](../301/untrusted-input.md)).

```text
  bytes  →  tag loop  →  descriptor lookup  →  set fields / skip unknown  →  Message
```

## Pure Python vs upb (what changes)

| Stage | Pure Python | upb (default wheel) |
|-------|-------------|---------------------|
| Field walk | Python loops in `internal` | Native C |
| Varint/tag | Python integer ops | Native |
| Nested | Recursive Python | Native + recursion limit |
| API | Same `Message` methods | Same |

Functionally interchangeable for ordinary use; performance and some edge behaviors differ. Pin via `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` (or `upb`) and document the backend for benchmarks.

## Buffers & ownership (simple diagram)

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
| Generated Message | Python GC |
| `bytes` from serialize | Immutable; caller-owned |
| Parse input | Caller; ordinary `bytes` are fine; if you pass a view into a mutable buffer, keep that buffer alive for the call |
| Unknown fields | Held on message when the backend retains them |

## In this suite

| Location | Role |
|----------|------|
| `python/src/benchmark/serializers/schema_protobuf.py` | `prepare_data` → Message; `serialize_bytes` → `SerializeToString` |
| suite generated `*_pb2.py` modules | Generated suite messages—not MiniUser |
| Log name | `protobuf` |
| Pin | `protobuf>=7.34.1,<8` |
| [Python Results](../../python/results.md) | Cost under whatever backend the environment selected |

Harness keeps conversion **out** of the timed path so Results compare codec work, not model mapping. Do not rank Python vs Rust/C from Results alone ([cross-language fidelity](protobuf-cross-language-fidelity.md)).

## Common mistakes

- Timing `prepare_data` + serialize together.  
- Assuming pure-Python behavior while upb is active (or the reverse).  
- Using `MergeFromString` when you meant replace (`ParseFromString` / fresh message).  
- Mutating a message while another thread serializes it.  
- Parsing untrusted bytes without size limits.  
- Hand-editing `*_pb2.py`.  
- Expecting `MiniUser` in suite generated modules (teaching schema only).

## What this article is not

- Line-by-line tour of upb C sources.  
- gRPC Python stubs.  
- From-scratch encoder ([lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- Client API: **codegen → Message → SerializeToString / ParseFromString**.  
- **ParseFromString** replaces (clear + parse); **MergeFromString** merges.  
- Implementation: **backend** + **descriptor-driven** field walk = wire tags.  
- Default backend is **upb**; pure Python remains the portable fallback.  
- Parallel: [Rust prost](protobuf-rust-prost.md), [C protobuf-c](protobuf-c-protobuf-c.md).
