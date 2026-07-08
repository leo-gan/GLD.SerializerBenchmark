# C: protobuf-c path

## Problem

C clients call `pack` / `unpack` without seeing that protobuf-c is a **descriptor-driven interpreter**: generated structs supply field **offsets** and **types**; a shared runtime walks those descriptors to emit or parse wire data. Serializer developers need that split—and how it differs from prost’s monomorphized `encode_raw`.

## Short answer

**Primary stack: protobuf-c.** Codegen emits C structs plus a `ProtobufCMessageDescriptor` (field array: id, type, offset, label, …). **`protobuf_c_message_get_packed_size`** sums sizes; **`protobuf_c_message_pack`** writes tags/payloads into a caller buffer; **`protobuf_c_message_unpack`** scans the buffer into a **heap** message; **`protobuf_c_message_free_unpacked`** frees it. Implementation lives mainly in [`protobuf-c/protobuf-c.c`](https://github.com/protobuf-c/protobuf-c/blob/master/protobuf-c/protobuf-c.c); API overview: [packing docs](https://protobuf-c.github.io/protobuf-c/pack.html). **nanopb** is a different design (comparison box only).

Assumes [wire format](protobuf-wire-format.md).

## Prerequisites

- Intermediate C (pointers, `malloc`, struct layout).  
- 201 schema-dependent encoding.  
- Soft: [301 untrusted input](../301/untrusted-input.md).

## Mental model

```text
  .proto ──protoc-gen-c──►  struct Person { ... };
                            ProtobufCMessageDescriptor person_descriptor
                                      │
   message* + descriptor ──get_packed_size / pack──► uint8_t[]
   bytes + descriptor ──unpack──► heap message ──free_unpacked──►
```

Every message instance begins with descriptor linkage so the runtime can treat it as a generic `ProtobufCMessage *`.

## Client path (what you write)

### 1. Codegen

```bash
protoc --c_out=gen -I schemas schemas/benchmark_data.proto
```

### 2. Populate / pack / unpack

```c
/* names are illustrative—generators apply their own prefixing */
BenchmarkData__Person person = BENCHMARK_DATA__PERSON__INIT;
person.first_name = "Ada";
person.age = 36;

size_t sz = protobuf_c_message_get_packed_size((const ProtobufCMessage *)&person);
uint8_t *buf = malloc(sz);
size_t n = protobuf_c_message_pack((const ProtobufCMessage *)&person, buf);

BenchmarkData__Person *out =
    benchmark_data__person__unpack(NULL, n, buf);
/* use out */
benchmark_data__person__free_unpacked(out, NULL);
free(buf);
```

Alternatively **`protobuf_c_message_pack_to_buffer`** streams chunks through a `ProtobufCBuffer` vtable (append callback) without precomputing a single allocation size.

## How protobuf-c implements serialization (step-by-step)

The following follows the structure of `protobuf_c_message_get_packed_size` / `protobuf_c_message_pack` in `protobuf-c.c` (descriptor iteration + per-label helpers).

### S1 — Descriptor is the schema at runtime

Each field descriptor carries at least:

| Metadata | Use in pack |
|----------|-------------|
| **id** (field number) | Tag |
| **type** (int32, string, message, …) | Wire type + pack helper |
| **label** (required / optional / none / repeated) | Whether/how to emit |
| **offset** | `member = (char*)message + offset` → field storage |
| **quantifier_offset** | `has` bit, repeated count, or oneof case |
| **flags** | oneof, packed repeated, etc. |

Codegen fills this table once; the runtime never parses `.proto` text at pack time.

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

`required_field_get_packed_size` accounts for **tag bytes + payload** (varint length of integers, string length + bytes, nested `get_packed_size` for submessages, etc.).

### S3 — `protobuf_c_message_pack`

Same field loop; instead of summing, call `*_pack` helpers that **write** into `out + rv` and return bytes written:

```text
rv = 0
for each field (as above):
  rv += required_field_pack / optional_field_pack / repeated_field_pack / ...
for each unknown_field:
  rv += unknown_field_pack(...)
return rv
```

### S4 — `required_field_pack` (core primitive)

From the implementation pattern in `required_field_pack`:

1. **`tag_pack(field->id, out)`** — write field number as a tag base.  
2. **OR in the wire type** on the first tag byte (`VARINT`, `32BIT`, `64BIT`, `LENGTH_PREFIXED`).  
3. **Type switch** packs the payload:
   - `UINT32` / `INT32` / `ENUM` / … → varint packers  
   - `FIXED32` / `FLOAT` → 4-byte little-endian  
   - `FIXED64` / `DOUBLE` → 8-byte  
   - `STRING` → length-prefixed bytes  
   - `BYTES` → length-prefixed `ProtobufCBinaryData`  
   - `MESSAGE` → nested `get_packed_size` + length + recursive `pack` (`prefixed_message_pack`)

This is the C analogue of prost’s `encode_raw` field write—except driven by **data** (descriptor) rather than generated straight-line code per message type.

### S5 — Optional / repeated / oneof

| Label | Gate before pack |
|-------|------------------|
| Optional | `has` quantifier (or pointer non-NULL for message/string variants) |
| Repeated | `count` at quantifier; loop or packed encoding |
| Oneof | case enum must equal this field’s id |
| Unknown | re-emitted so round-trips can preserve them |

### S6 — Buffer responsibility

`pack` assumes **`out` has at least `get_packed_size` bytes**. Undersized buffers are undefined/truncated—**you** measure then allocate (or use `pack_to_buffer`).

```text
  struct + descriptor  →  size walk  →  pack walk (tag|wire + payload)  →  buffer
```

## How protobuf-c implements deserialization (step-by-step)

Public entry: **`protobuf_c_message_unpack(descriptor, allocator, len, data)`** (generated `foo__unpack` wrappers pass the type’s descriptor). Result must be freed with **`protobuf_c_message_free_unpacked`** / generated `foo__free_unpacked`.

### D1 — Scan phase

The unpacker walks the byte buffer as a Protobuf stream:

1. Read tag → field number + wire type.  
2. Slice the **payload** for that field (varint length, fixed width, or length-prefixed blob).  
3. Build a list of **scanned members** (pointer into input + field metadata when the number is known).

This separates “find fields in the buffer” from “store into C structs.”

### D2 — Lookup field by number

Known numbers map through descriptor **field ranges** / tables to a `ProtobufCFieldDescriptor *`. Unknown numbers become **unknown field** entries (stored for later pack) after skipping by wire type.

### D3 — Parse into struct members

For each scanned member, type-specific parsers (e.g. `parse_required_member`, `parse_optional_member`, `parse_repeated_member`, packed variants):

| Type | Storage action |
|------|----------------|
| Integers / bool / enum | Store into `member` at `offset` |
| String | Allocate copy (or allocator policy); set `char *` |
| Bytes | Allocate `ProtobufCBinaryData` |
| Message | Recursive **`protobuf_c_message_unpack`** on the slice; store pointer |
| Repeated | Grow array; parse element at next index; bump count |

### D4 — Merge when the same field appears twice

Protobuf allows multiple occurrences; protobuf-c **merges** (documented in-source near `merge_messages`): repeated concatenate; submessages merge; singulars prefer later values with care not to double-free. That is why unpack is not always “last write wins” with naive overwrites for messages.

### D5 — Allocator

Unpack takes a `ProtobufCAllocator *` (NULL → default libc-like). All heap nodes from unpack must be released with the matching free_unpacked so nested strings/messages are not leaked.

### D6 — Errors

On failure, unpack returns **NULL** (and should not leak partial trees—implementation frees on error paths). Always check the pointer; always bound `len` for untrusted data.

```text
  bytes  →  scan tags  →  lookup descriptor  →  parse/merge into heap struct
```

## Descriptor-driven vs monomorphized (prost)

| | **protobuf-c** | **prost** |
|--|----------------|-----------|
| Schema at runtime | Descriptor tables | Compiled into `encode_raw` / `merge_field` |
| Pack loop | One shared interpreter | Per-type specialized code |
| Typical use | C without heavy templates | Rust type system |
| Teaching value | Offsets + labels are explicit | Trait methods are explicit |

Both emit the **same wire format** if schemas and field numbers match.

## nanopb comparison box

Short form only—full treatment: [nanopb vs protobuf-c](protobuf-c-nanopb-compare.md).


| Axis | **protobuf-c** (primary) | **nanopb** |
|------|--------------------------|------------|
| Allocation | Heap unpack common | Static buffers / callbacks |
| Engine | Descriptor pack/unpack | Stream encode/decode with max sizes |
| Suite | `protobuf-c` | Separate registration |
| When | General C services | Embedded / constrained RAM |

## Buffers & ownership

| Stage | Ownership |
|-------|-----------|
| Input struct for pack | Caller (stack or heap) |
| Packed `uint8_t[]` | Caller-allocated |
| Unpacked message | Heap via allocator; **free_unpacked** |
| Nested/repeated | Owned by parent free |

## In this suite

| Location | Role |
|----------|------|
| `c/src/serializers/ser_protobuf_c.c` | Register `protobuf-c`; call fixture encode/decode helpers |
| Fixture helpers | Map harness fixtures ↔ protobuf-c messages |
| Log name | `protobuf-c` |
| [C Results](../../c/results.md) | Schema-driven C peers |

## Common mistakes

- Skipping `free_unpacked` (leaks under load).  
- Packing into an undersized buffer.  
- Using a descriptor from a different `.proto` revision than peers.  
- Treating unpack success as “safe for untrusted input” without size/depth policy.

## What this article is not

- Full nanopb tutorial.  
- Custom allocator cookbook.  
- Hand-rolled varint lab ([lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- protobuf-c = **generated layout + shared descriptor runtime**.  
- Pack: **size walk → pack walk** with `required_field_pack`-style tag|wire + payload.  
- Unpack: **scan → lookup → parse/merge → heap message**.  
- Same wire as Python/Rust; different engineering of the engine.  
- Parallel: [Python](protobuf-python.md), [Rust prost](protobuf-rust-prost.md).
