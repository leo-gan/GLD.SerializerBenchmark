# 4.6 C: `nanopb` vs. `protobuf-c`

## Problem Statement

Both **`protobuf-c`** and **`nanopb`** implement Protocol Buffers for C and produce wire-compatible bytes, yet they enforce incompatible **memory contracts**. `protobuf-c` targets general POSIX/server processes with heap-allocated message trees, whereas `nanopb` targets microcontrollers and real-time embedded firmware with strict static RAM and flash budgets.[^1] Choosing the wrong runtime—or misunderstanding why `nanopb` rejects a valid Protocol Buffers message—leads directly to memory exhaustion or spurious interoperability incidents.

---

## Same Wire Format, Divergent Memory Contracts

```text
           Shared Protocol Buffers binary wire format
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
          protobuf-c                      nanopb
   descriptor-driven heap          static max_size / max_count
   malloc tree + free_unpacked     pb_ostream_t / pb_istream_t
```

| Architectural Axis | `protobuf-c` (Server / General C) | `nanopb` (Embedded / Constrained C) |
|---|---|---|
| **Allocation model** | `unpack` allocates strings, arrays, and submessages on the heap | Static/stack structs by default; optional `PB_ENABLE_MALLOC` discouraged unless required |
| **Size bounds** | Unbounded up to available heap (caller must cap input `len`) | Declared at codegen time via `.options` (`max_size`, `max_count`) |
| **Encode API** | Two-pass: `get_packed_size` $\to$ allocate $\to$ `pack` | Single-pass streaming into `pb_ostream_t` (fixed buffer or callback) |
| **Decode API** | `unpack` $\to$ heap tree $\to$ mandatory `*_free_unpacked` | `pb_decode(&istream, Fields, &out)` into caller-owned struct; nothing to free |
| **Variable-length data** | Dynamic pointers (`char *`, `T **`) | Fixed arrays (`char name[32]`) or streaming `pb_callback_t` hooks |
| **Unknown fields** | Retained on message for re-serialization | Skipped by wire type (not buffered by default) |
| **Primary failure mode** | OOM or memory leak if `free_unpacked` is omitted | `pb_decode` returns `false` if input exceeds configured `max_size` / `max_count` |

---

## Minimal `nanopb` Lifecycle

With `.options` declaring `MiniUser.name max_size:32` and `MiniUser.tags max_count:8`, `nanopb` generates fixed-capacity struct fields (`char name[32]`, `pb_size_t tags_count`, `uint32_t tags[8]`):

```c
MiniUser user = MiniUser_init_zero;
user.id = 1;
snprintf(user.name, sizeof(user.name), "%s", "Ada");

uint8_t buffer[MiniUser_size];   /* compile-time worst-case byte bound */
pb_ostream_t ostream = pb_ostream_from_buffer(buffer, sizeof(buffer));
if (!pb_encode(&ostream, MiniUser_fields, &user)) {
    /* handle encode failure (e.g., buffer overflow) */
}

MiniUser out = MiniUser_init_zero;
pb_istream_t istream = pb_istream_from_buffer(buffer, ostream.bytes_written);
if (!pb_decode(&istream, MiniUser_fields, &out)) {
    /* handle truncated wire, invalid tag, or max_size/max_count overflow */
}
/* zero heap teardown required */
```

Notice `MiniUser_size`: when every field has a static bound, `nanopb` computes the **exact worst-case encoded wire size at compile time**, eliminating both `malloc` and the `get_packed_size` dry-run pass.

### Why Valid Protocol Buffers Can Fail `nanopb` Decode

Suppose a cloud backend using `google.protobuf` or `protobuf-c` emits a valid message with a 40-byte `name` string, while an MCU running `nanopb` compiled `MiniUser.name` with `max_size:32`. `pb_decode` fails closed and returns `false`.

This is **not** a wire-format incompatibility; it is a **static capacity contract** enforced deliberately to prevent heap fragmentation and buffer overruns on devices with kilobytes of SRAM. Teams spanning cloud and embedded targets must publish `max_size` / `max_count` constraints as part of the shared schema contract (or handle unbounded fields via `pb_callback_t` streaming callbacks).

---

## Selection Matrix and Suite Caveats

| Deployment Constraint | Recommended C Runtime |
|---|---|
| Linux server / daemon handling variable-length documents | **`protobuf-c`** (or C++ `libprotobuf`) |
| Bare-metal / RTOS microcontroller with no heap or strict worst-case RAM budget | **`nanopb`** |
| Intermediary proxy that must preserve unknown fields verbatim | **`protobuf-c`** |
| High-frequency sensor telemetry with fixed sample windows | **`nanopb`** |

**Suite benchmark caveat:** Both `protobuf-c` (v1.5.0) and `nanopb` (0.4.9) are linked in `c/` (`c/third_party/VERSIONS.md`), but in the current suite runners (`ser_protobuf_c.c` and `ser_nanopb.c`) both rows time the shared in-tree proto3 wire helper (`fixture_pb_v2.h`) rather than native `protoc-gen-c` vs. `nanopb_generator` codegen (see [C Overview](../../c/index.md) and the [C Protocol Buffers Dashboard slice](../../dashboard/index.html?lang=c&standard=protobuf&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protobuf-c&ser=nanopb&ser=protobuf-c#compare)). Do not interpret those two suite rows as a head-to-head benchmark of full native `protobuf-c` vs. `nanopb` runtimes.

---

## Exercises

1. **Static worst-case buffer sizing:** A `nanopb` sensor message has two `uint32` fields (field numbers 1 and 2) and one `bytes` field (field number 3, `max_size:16`). Compute the worst-case encoded wire size in bytes.

??? note "Solution"
    - Field 1 (`uint32`, 1-byte tag): max varint for 32-bit unsigned is $\lceil 32/7 \rceil = 5$ bytes $\to 1 + 5 = 6$ bytes.
    - Field 2 (`uint32`, 1-byte tag): $1 + 5 = 6$ bytes.
    - Field 3 (`bytes`, 1-byte tag, length $\le 16$ fits in 1-byte varint): $1 + 1 + 16 = 18$ bytes.
    - **Total worst-case buffer:** $6 + 6 + 18 = \mathbf{30\text{ bytes}}$.

2. **Streaming unbounded fields on an MCU:** An embedded device with 32 KB of RAM must decode a firmware-manifest message containing a 128 KB binary signature/payload field without enabling `malloc`. How does `nanopb` support this?

??? note "Solution"
    Leave `max_size` unset on the large `bytes` field so `nanopb` generates a `pb_callback_t` field. During `pb_decode`, `nanopb` invokes the user's callback with a bounded sub-stream `pb_istream_t`, allowing the firmware to read the 128 KB payload in small fixed chunks (e.g., 256 bytes at a time) directly into flash or an incremental SHA-256 hasher.

3. **Diagnosing a false "wire bug":** A firmware update rejects messages from a Go backend after the backend starts populating 12 entries in `repeated uint32 tags`, whereas `tags` previously had 4 entries. Both sides compiled the same `.proto` file. What caused the failure?

??? note "Solution"
    The firmware's `nanopb` `.options` file likely pinned `tags max_count:8` (or similar `< 12`). Because `.proto` alone does not express `nanopb` static bounds, the Go producer exceeded the MCU's static array capacity and `pb_decode` correctly failed closed.

---

## References

[^1]: Aimonen, P. *nanopb: Protocol Buffers with Small Code Size (Concepts and Options Reference)*. <https://jpa.kapsi.fi/nanopb/docs/concepts.html>
