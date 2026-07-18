# C: protobuf-c path

## Problem

C clients often call `pack` and `unpack` without seeing that **protobuf-c** is a **descriptor-driven interpreter**. Generated structs supply field **offsets** (byte distances into the struct) and **types**. A shared runtime walks those descriptors to emit or parse wire data. Serializer developers need that split—and how it differs from prost’s monomorphized (per-type specialized) `encode_raw`.

## Short answer

Code generation emits C structs plus a `ProtobufCMessageDescriptor`: a field array that records id, type, offset, label, and related metadata. **`protobuf_c_message_get_packed_size`** walks the descriptor and sums sizes. **`protobuf_c_message_pack`** writes tags and payloads into a **caller-owned** buffer. **`protobuf_c_message_unpack`** scans the buffer into a **heap** message. **`protobuf_c_message_free_unpacked`** frees that tree. The implementation lives mainly in [`protobuf-c/protobuf-c.c`](https://github.com/protobuf-c/protobuf-c/blob/master/protobuf-c/protobuf-c.c); API overview: [packing docs](https://protobuf-c.github.io/protobuf-c/pack.html).

**nanopb** is a different C design (static budgets and streams). See the short comparison box below and the full article [nanopb vs protobuf-c](protobuf-c-nanopb-compare.md).

This article assumes the [wire format](protobuf-wire-format.md) article.

**Suite pin (this monorepo):** **protobuf-c v1.5.0** (`c/third_party/VERSIONS.md`).

## Prerequisites

- Intermediate C: pointers, `malloc`, struct layout.  
- Serialization 201: schema-dependent encoding.  
- Soft: [301 untrusted input](../301/untrusted-input.md).

## Mental model

```text
  .proto ──protoc-gen-c──►  struct MessageV2 { ... };  /* illustrative */
                            ProtobufCMessageDescriptor person_descriptor
                                      │
   message* + descriptor ──get_packed_size / pack──► uint8_t[]
   bytes + descriptor ──unpack──► heap message ──free_unpacked──►
```

Every message instance begins with descriptor linkage so the runtime can treat it as a generic `ProtobufCMessage *`.

## Minimum recipe (what you write)

```c
/* names are illustrative—generators apply their own prefixing */
/* illustrative */ Suite__Message msg = SUITE__MESSAGE__INIT;
person.first_name = "Ada";
person.age = 36;

size_t sz = protobuf_c_message_get_packed_size((const ProtobufCMessage *)&person);
uint8_t *buf = malloc(sz);
size_t n = protobuf_c_message_pack((const ProtobufCMessage *)&person, buf);

Suite__Message *out =
    benchmark_data__person__unpack(NULL, n, buf);
/* use out */
benchmark_data__person__free_unpacked(out, NULL);
free(buf);
```

Code generation:

```bash
protoc --c_out=gen -I schemas schemas/v2/protobuf/benchmark_v2.proto
```

Alternatively, **`protobuf_c_message_pack_to_buffer`** streams chunks through a `ProtobufCBuffer` vtable (an append callback) without precomputing a single allocation size.

For the teaching [MiniUser](lab-mini-protobuf-encoder.md) goldens, compile a separate tiny `mini.proto`—not the suite `schemas/v2/protobuf/benchmark_v2.proto`.

## How protobuf-c implements serialization (step-by-step)

The following follows the structure of `protobuf_c_message_get_packed_size` and `protobuf_c_message_pack` in `protobuf-c.c` (descriptor iteration plus per-label helpers).

### S1 — Descriptor is the schema at runtime

Each field descriptor carries at least:

| Metadata | Use in pack |
|----------|-------------|
| **id** (field number) | Tag |
| **type** (int32, string, message, …) | Wire type and pack helper |
| **label** (required / optional / none / repeated) | Whether and how to emit |
| **offset** | `member = (char*)message + offset` → field storage |
| **quantifier_offset** | `has` bit, repeated count, or oneof case |
| **flags** | oneof, packed repeated, and similar |

Code generation fills this table once. The runtime never parses `.proto` text at pack time.

### S2 — `protobuf_c_message_get_packed_size`

Logic (simplified from source):

```text
size = 0
for i in 0 .. descriptor->n_fields:
  field = descriptor->fields[i]
  member = message + field.offset
  quant  = message + field.quantifier_offset
  switch field.label:
    REQUIRED:  size += required_field_get_packed_size(field, member)
    OPTIONAL:  size += optional_field_get_packed_size(field, *has, member)
    NONE:      size += unlabeled_field_get_packed_size(...)   # proto3-ish
    REPEATED:  size += repeated_field_get_packed_size(field, count, array)
    ONEOF:     size += oneof_field_get_packed_size(field, case, member)
for each unknown_field:
  size += unknown_field_get_packed_size(...)
return size
```

Size helpers account for **tag bytes plus payload** (varint length of integers, string length plus bytes, nested `get_packed_size` for submessages, and so on).

### S3 — `protobuf_c_message_pack`

Same field loop; instead of summing, call pack helpers that **write** into `out + rv` and return the number of bytes written:

```text
rv = 0
for each field (as above):
  rv += *_field_pack(...)   # label-specific
for each unknown_field:
  rv += unknown_field_pack(...)
return rv
```

### S4 — Type dispatch (tag + payload)

Regardless of label, the core write is **tag (field id plus wire type) then payload**, dispatched on the field **type** in the descriptor:

- Varint types (int, bool, enum) → varint encoding  
- Fixed32 / float → 4-byte little-endian  
- Fixed64 / double → 8-byte  
- String / bytes → length prefix plus data  
- Message → length prefix plus recursive pack of the sub-message  

Source helpers are often named like `required_field_pack` even when called from optional or repeated paths. Think “type-dispatch pack,” not “proto2 required only.”

This design is **descriptor-driven** (one shared interpreter loop) rather than monomorphized per-message code.

### S5 — Optional / repeated / oneof

| Label | Gate before pack |
|-------|------------------|
| Optional | `has` quantifier (or a non-NULL pointer for some message/string variants) |
| Repeated | `count` at the quantifier; loop or packed encoding |
| Oneof | case enum must equal this field’s id |
| Unknown | re-emitted so round-trips can preserve them |

### S6 — Buffer responsibility

`pack` assumes that **`out` has at least `get_packed_size` bytes**. Undersized buffers are undefined or truncated—**you** measure, then allocate (or use `pack_to_buffer`).

```text
  struct + descriptor  →  size walk  →  pack walk (tag|wire + payload)  →  buffer
```

## How protobuf-c implements deserialization (step-by-step)

Public entry: **`protobuf_c_message_unpack(descriptor, allocator, len, data)`** (generated `foo__unpack` wrappers pass the type’s descriptor). The result must be freed with **`protobuf_c_message_free_unpacked`** or the generated `foo__free_unpacked`.

### D1 — Scan phase

The unpacker walks the byte buffer as a Protocol Buffers stream:

1. Read a tag → field number plus wire type.  
2. Slice the **payload** for that field (varint, fixed width, or length-prefixed blob).  
3. Build a list of **scanned members** (a pointer into the input plus field metadata when the number is known).

This separates “find fields in the buffer” from “store into C structs.”

**Sketch — G1 bytes `08 01 12 03 41 64 61` (`id=1`, `name=Ada` on a MiniUser-shaped schema):**

| Scan step | Bytes | Result |
|-----------|-------|--------|
| Tag | `08` | field 1, VARINT |
| Payload | `01` | varint value 1 |
| Tag | `12` | field 2, LEN |
| Len | `03` | 3 payload bytes |
| Payload | `41 64 61` | `Ada` |

### D2 — Lookup field by number

Known numbers map through descriptor **field ranges** and tables to a `ProtobufCFieldDescriptor *`. Unknown numbers become **unknown field** entries (stored for later pack) after the runtime skips them by wire type.

### D3 — Parse into struct members

For each scanned member the code calls type-specific helpers that write into the struct at the descriptor’s offset:

- Scalars → direct store  
- String/bytes → allocate and copy  
- Message → recursive unpack  
- Repeated → grow the array and append  

The key point: everything is driven by the runtime descriptor, not by generated straight-line code per field.

### D4 — Merge when the same field appears twice

Protocol Buffers allows multiple occurrences of the same field. protobuf-c **merges** them (documented in-source near `merge_messages`): repeated fields concatenate, submessages merge, and singulars prefer later values with care not to double-free. That is why unpack is not always a naive “last write wins” overwrite for messages.

### D5 — Allocator

Unpack takes a `ProtobufCAllocator *` (`NULL` means a default libc-like allocator). All heap nodes from unpack must be released with the matching `free_unpacked` so nested strings and messages are not leaked.

### D6 — Errors

On failure, unpack returns **NULL** (and should not leak partial trees—the implementation frees on error paths). Always check the pointer. Always bound `len` for untrusted data.

```text
  bytes  →  scan tags  →  lookup descriptor  →  parse/merge into heap struct
```

## Descriptor-driven vs monomorphized (prost)

| | **protobuf-c** | **prost** |
|--|----------------|-----------|
| Schema at runtime | Descriptor tables | Compiled into `encode_raw` / `merge_field` |
| Pack loop | One shared interpreter | Per-type specialized code |
| Typical use | C without heavy templates | Rust type system |
| Teaching value | Offsets and labels are explicit | Trait methods are explicit |

Both emit the **same wire format** if schemas and field numbers match. The hub [three engines table](index.md#three-engines-at-a-glance) includes Python and nanopb as well.

## nanopb comparison box

Short form only—full treatment: [nanopb vs protobuf-c](protobuf-c-nanopb-compare.md).

| Axis | **protobuf-c** | **nanopb** |
|------|----------------|------------|
| Allocation | Heap unpack is common | Static buffers / callbacks |
| Engine | Descriptor pack/unpack | Stream encode/decode with max sizes |
| Suite | `protobuf-c` | Separate registration |
| When | General C services | Embedded / constrained RAM |

## Buffers and ownership (simple diagram)

**Ownership** in C is manual: whoever allocates must free, and buffers you pass to `pack` must be large enough.

```text
struct (stack or heap)
     │
     ▼ pack
caller buffer (you allocated)
     ▲
     │ unpack
heap message → free_unpacked()
```

| Stage | Ownership |
|-------|-----------|
| Input struct for pack | Caller (stack or heap) |
| Packed `uint8_t[]` | Caller-allocated |
| Unpacked message | Heap via the allocator; free with **free_unpacked** |
| Nested/repeated | Owned by the parent free |

## In this suite

| Location | Role |
|----------|------|
| `c/src/serializers/ser_protobuf_c.c` | Register log name `protobuf-c` |
| Timed encode/decode | Shared suite proto3 wire helper `fixture_pb_v2.h` (field tags match `benchmark_v2.proto`)—**not** a full protoc-gen-c `pack`/`unpack` path yet |
| Official Google C++/C runtime row | Log name `protobuf` (libprotobuf) on the [C Overview](../../c/index.md) |
| Pin (linked) | protobuf-c v1.5.0 in `c/third_party/VERSIONS.md` |
| [C Results](../../c/results.md) | Schema-driven C peers (regenerate after harness changes) |

Do not rank C against Python or Rust from Results alone ([cross-language fidelity](protobuf-cross-language-fidelity.md)).

## Common mistakes

- Skipping `free_unpacked` (leaks under load).  
- Packing into an undersized buffer.  
- Using a descriptor from a different `.proto` revision than your peers.  
- Treating unpack success as “safe for untrusted input” without a size and depth policy.

## What this article is not

- A full nanopb tutorial.  
- A custom-allocator cookbook.  
- A hand-rolled varint lab (see the [lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- protobuf-c is **generated layout plus a shared descriptor runtime**.  
- Pack is a **size walk then a pack walk**, with tag|wire plus payload type dispatch.  
- Unpack is **scan → lookup → parse/merge → heap message** (see the G1 scan sketch).  
- Same wire as Python and Rust; different engineering of the engine.  
- Parallel articles: [Python](protobuf-python.md), [Rust prost](protobuf-rust-prost.md).
