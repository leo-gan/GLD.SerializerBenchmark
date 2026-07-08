# C: protobuf-c path

## Problem

C has several Protobuf stories: **protobuf-c** (classic generated structs + runtime), **nanopb** (embedded, static allocation), and others. Serializer developers need one clear primary path and a honest contrast—not a merged mash of both APIs.

## Short answer

**Primary stack: protobuf-c.** From a `.proto`, the protobuf-c code generator emits C structs and descriptors; the runtime **packs** (encode) and **unpacks** (decode) with explicit buffers and **caller-managed memory** (often free via generated free functions). This suite registers `protobuf-c` via thin wrappers over shared fixture helpers. **nanopb** is summarized in a comparison box only (full article deferred).

Assumes [wire format](protobuf-wire-format.md).

## Prerequisites

- Intermediate C (pointers, lifetimes, `malloc`).  
- 201 schema-dependent encoding.  
- Soft: [301 untrusted input](../301/untrusted-input.md).

## Mental model

```text
  .proto --protoc-gen-c-->  *.pb-c.c / *.pb-c.h  (structs + ProtobufCMessageDescriptor)
                                │
  fill struct fields ──► protobuf_c_message_pack / pack_to_buffer ──► bytes
  bytes ──► protobuf_c_message_unpack ──► heap message ──► free
```

## Step-by-step

### 1. Codegen

Typical:

```bash
protoc --c_out=gen -I schemas schemas/benchmark_data.proto
```

You get a C struct per message and a `*_descriptor` used by the runtime.

### 2. Populate

```c
BenchmarkData__Person person = BENCHMARK_DATA__PERSON__INIT;
person.first_name = "Ada";   /* naming depends on generator */
person.last_name = "Lovelace";
person.age = 36;
```

(Exact identifiers follow protobuf-c’s naming; suite helpers may abstract fixtures.)

### 3. Encode (pack)

```c
size_t sz = protobuf_c_message_get_packed_size((const ProtobufCMessage *)&person);
uint8_t *buf = malloc(sz);
if (!buf) { /* handle */ }
size_t packed = protobuf_c_message_pack((const ProtobufCMessage *)&person, buf);
```

Or pack into a `ProtobufCBuffer` abstraction. **You** size and own the output buffer.

### 4. Decode (unpack)

```c
BenchmarkData__Person *out =
    benchmark_data__person__unpack(NULL, len, data);
if (!out) { /* parse error */ }
/* use out->… */
benchmark_data__person__free_unpacked(out, NULL);
```

Unpack allocates; always free with the generated free function to avoid leaks.

### 5. Errors and untrusted data

- Check unpack return for NULL.  
- Bound `len` before parse.  
- Do not assume stack allocation for arbitrary messages—heap is the common pattern for unpacked trees.

## Buffers & ownership

| Stage | Ownership |
|-------|-----------|
| Input struct for pack | Caller; may be stack if no nested heap fields |
| Packed bytes | Caller-allocated buffer |
| Unpacked message | Heap via allocator; free with `*_free_unpacked` |
| Nested/repeated | Owned by parent message free |

## nanopb comparison box

| Axis | **protobuf-c** (primary) | **nanopb** (contrast) |
|------|--------------------------|------------------------|
| Allocation | Heap unpack common | Static / stream-friendly callbacks |
| Target | General C services | Embedded / constrained |
| API feel | Struct + pack/unpack | Streams, field callbacks, max sizes in options |
| Suite | Registered `protobuf-c` | Also registered in C harness—**different design** |
| Teaching focus | Classic runtime path | Memory policy specialization |

Do not mix APIs. Choose one stack per component; see C Overview for what the harness measures.

## In this suite

| Location | Role |
|----------|------|
| `c/src/serializers/ser_protobuf_c.c` | Registers `protobuf-c`; encode/decode via fixture helpers |
| Fixture helpers (`fixture_pb_full`, etc.) | Map harness fixtures ↔ protobuf-c messages |
| Log name | `protobuf-c` |
| [C Results](../../c/results.md) | Among C schema-driven entries |
| nanopb registration | Separate serializer—compare only within C + paradigm |

## Common mistakes

- Forgetting `free_unpacked` (leaks under load).  
- Packing into an undersized buffer.  
- Using protobuf-c numbers from a different `.proto` revision than peers.  
- Treating nanopb static size limits as protobuf-c behavior.

## What this article is not

- Full nanopb tutorial (second-wave compare article).  
- Custom allocator deep dive.  
- Hand-rolled varint encoder ([lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- Path: **codegen structs → pack/unpack → explicit free**.  
- C makes **buffer ownership** visible—good training for implementers.  
- nanopb is a different product design, not a drop-in rename.  
- Parallel: [Python](protobuf-python.md), [Rust prost](protobuf-rust-prost.md).
