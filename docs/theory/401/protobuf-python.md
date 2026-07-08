# Python: google.protobuf encode/decode path

## Problem

Python services often “use Protobuf” via generated `*_pb2.py` modules without a clear picture of **what is timed**, **what owns the bytes**, **which runtime backend runs under the hood**, and **how that backend turns a message into tags**. Client call sites alone do not train serializer developers.

## Short answer

With `google.protobuf`, `protoc` generates message classes that implement the `Message` API (`SerializeToString`, `ParseFromString`, …). At import time the library selects an **implementation backend** (default **upb**, else pure Python; legacy **cpp** exists but is no longer what PyPI ships). Serialize walks the message’s fields using **descriptors** (field numbers + types) and emits standard Protobuf binary; parse consumes tags and merges into a message instance. In this suite, **dataclass → Message is untimed `prepare_data`**; timed work is serialize/parse of the Message.

Assumes [wire format](protobuf-wire-format.md). Package: `protobuf` ([Python tutorial](https://protobuf.dev/getting-started/pythontutorial/), [encoding guide](https://protobuf.dev/programming-guides/encoding/), [python/README backends](https://github.com/protocolbuffers/protobuf/blob/main/python/README.md)).

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
protoc -I schemas --python_out=python/generated schemas/benchmark_data.proto
```

Generated modules define classes such as `Person` with field numbers from the `.proto`—Python attribute names are bindings, not wire identity.

### 2. Build a message

```python
import benchmark_data_pb2 as pb2

msg = pb2.Person()
msg.FirstName = "Ada"
msg.LastName = "Lovelace"
msg.Age = 36
msg.Passport.Number = "X1"
rec = msg.PoliceRecords.add()
rec.Id = 1
rec.CrimeCode = "A"
```

proto3: unset scalars with default values are typically **omitted** on the wire.

### 3. Encode / decode (API)

```python
data: bytes = msg.SerializeToString()
out = pb2.Person()
out.ParseFromString(data)
# or: out = pb2.Person.FromString(data)
```

Public API documentation: [Message.SerializeToString / ParseFromString](https://googleapis.dev/python/protobuf/latest/google/protobuf/message.html). Optional `deterministic=True` on serialize requests stable map key ordering when maps are present.

## How the package implements serialization (step-by-step)

The following is the **logical** path shared by backends; exact C/upb/Python frames differ, but the stages match the library design and [wire encoding](https://protobuf.dev/programming-guides/encoding/).

### S1 — Resolve the runtime backend

On first use, `google.protobuf` picks an implementation ([python/README.md](https://github.com/protocolbuffers/protobuf/blob/main/python/README.md)):

| Backend | What it is | Notes |
|---------|------------|--------|
| **upb** | Extension on the [upb](https://github.com/protocolbuffers/protobuf/tree/main/upb) C library | **Default** since 4.21; preferred for speed; ships in PyPI wheels |
| **cpp** | Extension wrapping C++ protobuf | **Deprecated / not in modern PyPI wheels**; legacy zero-copy C++ sharing |
| **python** | Pure Python in `google/protobuf/internal` | Fallback; slowest; no native extension |

Priority is normally **upb → cpp (if present) → python**. Override for diagnosis: env `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=upb|cpp|python`. Ad-hoc check: `google.protobuf.internal.api_implementation.Type()` (not a stable public API, useful for debugging).

**Why it matters:** the same `SerializeToString()` call may run native code or pure Python loops; Results and production must not mix backends accidentally.

### S2 — Message holds values + descriptor metadata

A generated class is more than a bag of attributes:

- **Field values** live in the message instance (and nested messages / repeated containers).  
- A **descriptor** (from codegen) lists each field’s **number**, **type**, label (singular/repeated), and Python name.  
- Wire identity is the **number + type**, not the Python identifier.

When you assign `msg.Age = 36`, you update the in-memory value; nothing is written to the network yet.

### S3 — `SerializeToString` entry

Public method (simplified contract):

1. Ensure the message is in a state the API allows (proto2 “required” / initialization checks where applicable; proto3 is laxer).  
2. Optionally request **deterministic** serialization (map key order).  
3. Dispatch into the active backend’s serialize implementation.  
4. Return a new Python **`bytes`** object containing the binary payload.

### S4 — Size / buffer preparation (backend)

Backends typically:

1. Walk fields (via descriptor or generated layout) and **compute encoded size** (or grow a buffer while writing).  
2. Allocate an output buffer of that size (or a resizable buffer).  
3. Write into that buffer, then wrap as `bytes` for Python.

upb/cpp do this in native code with far fewer Python-level object touches than pure Python.

### S5 — Field walk → wire primitives

For each field that is **present** for encoding (proto3: non-default singulars; always-encoded repeated elements; etc.):

1. Emit **key** = `(field_number << 3) | wire_type` as a varint.  
2. Emit **payload** by type:
   - integers/bool/enum → varint (or fixed32/64 for fixed types);  
   - string/bytes → length-delimited;  
   - nested message → serialize nested message to temporary bytes, then length-delimit;  
   - repeated → one field or packed length-delimited block per language/proto rules;  
   - map → repeated entries as synthetic key/value messages.

This is the same algorithm as the [lab](lab-mini-protobuf-encoder.md) and [wire article](protobuf-wire-format.md)—the package is a production implementation of those rules.

### S6 — Nested messages and recursion

Nested messages call the same serialize path recursively (with a depth budget in native backends). The parent sees only a **length-delimited blob**.

### S7 — Hand off to Python

The finished buffer becomes an immutable `bytes` instance. The caller owns it; the Message is unchanged unless you clear it.

```text
  msg fields  →  backend field walk  →  tag+payload bytes  →  PyBytes
```

## How the package implements deserialization (step-by-step)

### D1 — `ParseFromString` / `FromString` entry

1. `ParseFromString(data)` merges into **existing** `self` (often after `Clear()` semantics depending on call).  
2. `FromString(data)` constructs a **new** message, then parses.  
3. Backend receives a pointer/view of the input buffer (zero-copy into C for upb when possible for the raw read; Python objects for field values are still allocated as needed).

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

### D4 — Merge semantics

Parsing **merges** into the message: repeated fields append; singulars overwrite; submessages merge field-by-field. That is why “parse into an already-filled message” can surprise you—prefer a fresh instance or clear first when you want replace semantics.

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

Functionally interchangeable for ordinary use; performance and some edge behaviors differ. Pin and document the backend for benchmarks.

## Buffers & ownership

| Object | Owner |
|--------|--------|
| Generated Message | Python GC |
| `bytes` from serialize | Immutable; caller-owned |
| Parse input buffer | Caller must keep alive through `ParseFromString` |
| Unknown fields | Held on message when the backend retains them |

## In this suite

| Location | Role |
|----------|------|
| `python/src/benchmark/serializers/schema_protobuf.py` | `prepare_data` → Message; `serialize_bytes` → `SerializeToString` |
| `python/generated/benchmark_data_pb2.py` | Generated types |
| Log name | `protobuf` |
| [Python Results](../../python/results.md) | Cost under whatever backend the environment selected |

Harness keeps conversion **out** of the timed path so Results compare codec work, not model mapping.

## Common mistakes

- Timing `prepare_data` + serialize together.  
- Assuming pure-Python behavior while upb is active (or the reverse).  
- Mutating a message while another thread serializes it.  
- Parsing untrusted bytes without size limits.  
- Hand-editing `*_pb2.py`.

## What this article is not

- Line-by-line tour of upb C sources.  
- gRPC Python stubs.  
- From-scratch encoder ([lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- Client API: **codegen → Message → SerializeToString / ParseFromString**.  
- Implementation: **backend** + **descriptor-driven** field walk = wire tags.  
- Default backend is **upb**; pure Python remains the portable fallback.  
- Deserialize is a **tag loop** with merge and skip-unknown.  
- Parallel: [Rust prost](protobuf-rust-prost.md), [C protobuf-c](protobuf-c-protobuf-c.md).
