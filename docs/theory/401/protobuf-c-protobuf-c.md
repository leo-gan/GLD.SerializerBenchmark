# 4.5 C: `protobuf-c` Descriptor Runtime

## Problem Statement

Whereas Rust's `prost` ([4.4 Rust: `prost`](protobuf-rust-prost.md)) compiles every message schema into specialized per-type machine code, C lacks generics and templates. **`protobuf-c`** therefore implements a **descriptor-driven runtime interpreter**: code generation emits plain C structs alongside static `ProtobufCMessageDescriptor` metadata tables (recording field IDs, types, and `offsetof` byte offsets), and one shared C library walks those tables to pack and unpack any message.[^1]

Understanding this table-driven design—and its manual heap ownership contract—is essential for safe, leak-free C integration (pinned at `protobuf-c v1.5.0` in `c/third_party/VERSIONS.md`).

---

## Architecture: Descriptor Tables and Manual Ownership

```text
  .proto ──protoc --c_out──► struct Foo + static ProtobufCMessageDescriptor
                                             │
            struct* + descriptor ──get_packed_size() / pack()──► caller uint8_t[]
            bytes + descriptor   ──unpack()────────────────────► heap tree ──► free_unpacked()
```

Every generated struct embeds a `ProtobufCMessage base` header linking to its static `ProtobufCMessageDescriptor`. Each entry in `descriptor->fields[]` stores:

| Descriptor Field | Runtime Role |
|---|---|
| `id` | Wire field number used to build the key `(id << 3) \| wire_type` |
| `type` | Scalar/string/bytes/message type driving wire-type dispatch |
| `label` | `REQUIRED`, `OPTIONAL`, `NONE` (proto3), `REPEATED`, or `ONEOF` |
| `offset` | Byte offset inside the C struct (`(char *)msg + field->offset`) |
| `quantifier_offset` | Byte offset of `has_*` flag, `n_*` repeated count, or `oneof` case enum |
| `flags` | Packed repeated flag and optional metadata bits |

---

## Client Path

Compile `.proto` definitions via `protoc-gen-c`:

```bash
protoc --c_out=gen -I schemas schemas/v2/protobuf/benchmark_v2.proto
```

Standard encode/decode lifecycle (illustrative generated symbols):

```c
Suite__Message msg = SUITE__MESSAGE__INIT;
msg.f_string = "Ada";
msg.f_int32  = 36;

size_t sz = protobuf_c_message_get_packed_size((const ProtobufCMessage *)&msg);
uint8_t *buf = malloc(sz);
size_t n = protobuf_c_message_pack((const ProtobufCMessage *)&msg, buf);

Suite__Message *out = suite__message__unpack(NULL, n, buf);
if (out != NULL) {
    /* consume out */
    suite__message__free_unpacked(out, NULL);
}
free(buf);
```

For streaming output without precomputing total length, `protobuf_c_message_pack_to_buffer` emits chunks through a `ProtobufCBuffer` append callback.

---

## Internal Execution Trace

### Serialization: Two-Pass Descriptor Walk

`protobuf-c/protobuf-c.c` executes two symmetric loops over `0 .. descriptor->n_fields - 1`:

1. **`protobuf_c_message_get_packed_size`:** Computes `member = (const char *)msg + field->offset` and inspects the quantifier (`has_*`, `n_*`, or `oneof` case) according to `field->label`, accumulating exact wire bytes (`tag_len + payload_len`, recursing on nested submessages and including preserved `unknown_fields`).
2. **`protobuf_c_message_pack`:** Runs the identical loop, calling type-dispatched writers (`uint32_pack`, `string_pack`, nested `protobuf_c_message_pack`) directly into `out + written`.

Because C buffers are not self-growing, `protobuf_c_message_pack` **assumes `out` holds at least `get_packed_size` bytes**. Passing an undersized buffer causes buffer overflow (undefined behavior).

### Deserialization: Scan, Lookup, Merge, and Free

`protobuf_c_message_unpack(descriptor, allocator, len, data)` executes in three stages:

1. **Scan phase:** Walks `[0 .. len)` linearly, decoding each key varint, verifying bounds, and recording scanned field slices into a temporary stack/slab list. Separating scanning from allocation allows accurate sizing of repeated arrays.
2. **Descriptor lookup & struct population:** Maps each field number via binary search over `descriptor->field_ranges` to its `ProtobufCFieldDescriptor *`. Known scalars write directly at `offset`; strings and bytes are heap-allocated and copied via `allocator`; submessages recurse; unknown tags are preserved in `base.unknown_fields`.
3. **Merge semantics & cleanup:** If a field number appears multiple times on the wire, `protobuf-c` concatenates repeated elements and merges nested submessages cleanly without double-freeing earlier allocations. On any parse error (truncation, invalid wire type, allocation failure), `unpack` frees partial state and returns `NULL`.

---

## Descriptor Interpreter vs. Monomorphized Code (`prost`)

| Dimension | `protobuf-c` (C) | `prost` (Rust) |
|---|---|---|
| **Dispatch mechanism** | One shared runtime loop interpreting static descriptor tables | Per-type specialized `encode_raw` / `merge_field` machine code |
| **Binary size scaling** | Small code footprint + compact data tables | Larger code footprint (one function per message type) |
| **Unknown fields** | Preserved in `unknown_fields` for round-trip forwarding | Skipped and discarded by default |
| **Memory management** | Manual: caller allocates pack buffer and calls `*_free_unpacked` | RAII: `Vec<u8>` and owned structs drop automatically |

For memory-constrained embedded systems where heap allocation during `unpack` is unacceptable, see [4.6 C: `nanopb` vs. `protobuf-c`](protobuf-c-nanopb-compare.md).

---

## Suite Integration and Caveats

| Suite Artifact | Role |
|---|---|
| `c/src/serializers/ser_protobuf_c.c` | Registers log name `protobuf-c` (linked against v1.5.0) |
| Timed encode/decode note | Uses the shared suite proto3 wire helper (`fixture_pb_v2.h`, field tags matching `benchmark_v2.proto`) rather than full `protoc-gen-c` generated descriptors; see [C Overview](../../c/index.md) |
| Official C++ runtime row | Log name `protobuf` (`libprotobuf` with generated classes) |
| [C Protocol Buffers Dashboard slice](../../dashboard/index.html?lang=c&standard=protobuf&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protobuf-c&ser=protobuf-c#detailed-analytics) | Same-language comparison within C only |

---

## Exercises

1. **Buffer overflow hazard:** A developer skips `protobuf_c_message_get_packed_size` and allocates a fixed `uint8_t buf[256]` before calling `protobuf_c_message_pack`. What happens when a string grows to 300 bytes, and what are the two safe alternatives?

??? note "Solution"
    `protobuf_c_message_pack` takes no buffer-capacity parameter and writes past the end of `buf`, causing a stack/heap buffer overflow. Safe alternatives: (1) always call `protobuf_c_message_get_packed_size` first and verify `sz <= sizeof(buf)` (or allocate `sz` bytes dynamically), or (2) use `protobuf_c_message_pack_to_buffer` with a bounds-checked `ProtobufCBuffer` callback.

2. **Memory-leak audit:** Why is calling plain `free(out)` on a pointer returned by `suite__message__unpack` insufficient?

??? note "Solution"
    `unpack` allocates separate heap blocks for nested strings, `bytes` buffers, repeated arrays, submessages, and `unknown_fields`. Plain `free(out)` releases only the top-level struct, leaking every child allocation. Calling `suite__message__free_unpacked(out, allocator)` walks the descriptor recursively and frees the entire tree.

3. **Custom arena allocation:** How can a high-QPS C service eliminate per-field `malloc`/`free` contention during `protobuf_c_message_unpack` without switching libraries?

??? note "Solution"
    Pass a custom `ProtobufCAllocator` (implementing `alloc` and `free` function pointers) backed by a per-request bump/arena allocator. Unpack allocates all strings and submessages sequentially from the arena in $O(1)$, and the entire arena resets in a single operation after the request completes.

---

## References

[^1]: `protobuf-c` Contributors. *Protocol Buffers in C (`protobuf-c.c` and Packing Documentation)*. <https://github.com/protobuf-c/protobuf-c>
