# Python: google.protobuf encode/decode path

## Problem

Python services often “use Protobuf” via generated `*_pb2.py` modules without a clear picture of **what is timed**, **what owns the bytes**, and **where the suite wrapper stops**. Integrators need the runtime path; serializer authors need to know what not to reimplement.

## Short answer

With `google.protobuf`, `protoc` (or an equivalent plugin) generates message classes. You populate fields on a message instance, call **`SerializeToString()`** (or serialize into a buffer), and parse with **`ParseFromString` / `FromString`**. The C++ extension accelerates much of the work under CPython; the Python objects you hold are still managed by the interpreter. In this suite, **dataclass → Message conversion is untimed `prepare_data`**; timed work is serialize/parse of the Message.

Assumes [wire format](protobuf-wire-format.md). Package used in the suite: `protobuf` (see `python/pyproject.toml`).

## Prerequisites

- 201: schema-dependent encoding.  
- Ability to read generated Python modules.  
- Soft: [301 trust](../301/trust-boundaries.md) / [untrusted input](../301/untrusted-input.md) when parsing untrusted bytes.

## Mental model

```text
  .proto  --protoc-->  benchmark_data_pb2.py (generated classes)
                              │
  app / suite dataclass  -->  Message instance  --SerializeToString-->  bytes
                              Message instance  <--ParseFromString----  bytes
```

## Step-by-step

### 1. Codegen

Typical pattern (suite-aligned):

```bash
protoc -I schemas --python_out=python/generated schemas/benchmark_data.proto
```

Output modules define classes such as `Person`, `Passport`, with field descriptors matching the `.proto` numbers—not the Python attribute names alone as wire identity.

### 2. Build a message

```python
import benchmark_data_pb2 as pb2

msg = pb2.Person()
msg.FirstName = "Ada"
msg.LastName = "Lovelace"
msg.Age = 36
# nested
msg.Passport.Number = "X1"
# repeated
rec = msg.PoliceRecords.add()
rec.Id = 1
rec.CrimeCode = "A"
```

proto3 scalar defaults: unset fields often **omit** from the encoding (default values).

### 3. Encode

```python
data: bytes = msg.SerializeToString()
```

This walks the message and emits tags/payloads per the wire rules.

### 4. Decode

```python
out = pb2.Person()
out.ParseFromString(data)
# or: out = pb2.Person.FromString(data)
```

Unknown fields are retained/skipped per runtime version policy; do not assume you can round-trip unknowns without reading current library docs.

### 5. Ownership and copies

- `SerializeToString()` returns a **new** `bytes` object (immutable).  
- Parse allocates a **new** message tree (and nested messages / repeated containers).  
- There is no zero-copy view of arbitrary Python application objects into the wire buffer—the Message is the native model.

### 6. Reflection (optional path)

`google.protobuf` also supports dynamic messages via descriptors. The suite path uses **generated** classes for speed and clarity. Dynamic paths are for tools/gateways, not the default hot path here.

## Buffers & ownership

| Object | Owner |
|--------|--------|
| Generated Message | Python GC; clear references when done |
| `bytes` from serialize | Immutable; safe to share |
| Parse input `bytes`/`buffer` | Caller keeps buffer until parse returns |

## In this suite

| Location | Role |
|----------|------|
| `python/src/benchmark/serializers/schema_protobuf.py` | Wrapper: `prepare_data` → Message; `serialize_bytes` → `SerializeToString` |
| `python/generated/benchmark_data_pb2.py` | Generated types from shared proto |
| Log name | `protobuf` |
| [Python Results](../../python/results.md) | Cost of this stack among schema-driven peers |

Harness design deliberately keeps conversion **out** of the timed serialize path so Results compare codec work, not model mapping.

## Common mistakes

- Timing `prepare_data` + serialize together when claiming “Protobuf ops/s.”  
- Mutating a message while another thread serializes it.  
- Parsing untrusted bytes without size limits ([301 untrusted input](../301/untrusted-input.md)).  
- Editing `*_pb2.py` by hand (regenerate from `.proto`).

## What this article is not

- Full `protoc` plugin ecosystem tour.  
- gRPC Python service stubs.  
- A from-scratch encoder (that is the [lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- Path: **codegen → Message → SerializeToString / ParseFromString**.  
- Wire identity is field numbers in the `.proto`; Python names are bindings.  
- Suite isolates timed codec calls from fixture conversion.  
- Next: [Rust prost](protobuf-rust-prost.md), [C protobuf-c](protobuf-c-protobuf-c.md), or the [lab](lab-mini-protobuf-encoder.md).
