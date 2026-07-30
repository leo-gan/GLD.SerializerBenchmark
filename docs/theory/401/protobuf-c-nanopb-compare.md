# C: nanopb vs protobuf-c

## Why this article exists

Both **protobuf-c** and **nanopb** claim “Protocol Buffers for C,” but they optimize for different worlds. **protobuf-c** targets general services with heap-allocated messages. **nanopb** targets **embedded** systems with static memory budgets. Treating them as interchangeable APIs produces the wrong memory model, the wrong failure modes, and unfair suite comparisons.

In this article you will compare the two engines along allocation, size limits, APIs, and typical failure modes. After reading it, you should be able to choose which C engine fits a deployment and explain why a valid Protocol Buffers message can still be rejected by nanopb.

## Short answer

Use **protobuf-c** when you want classic generated structs, descriptor-driven pack/unpack, and heap-friendly services ([protobuf-c path](protobuf-c-protobuf-c.md)). Use **nanopb** when RAM or flash is tight, you can declare **maximum sizes** in options, and you accept stream- and callback-oriented encode/decode instead of free-form heap trees. The **wire format** remains Protocol Buffers binary ([wire format](protobuf-wire-format.md)). What diverges is the **engineering**: allocation, code generation, and APIs.

**Suite pins (this monorepo):** protobuf-c **v1.5.0**; nanopb **0.4.9** (`c/third_party/VERSIONS.md`, registration in `ser_nanopb.c`).

## Prerequisites

- [C: protobuf-c path](protobuf-c-protobuf-c.md).
- [Wire format](protobuf-wire-format.md).
- Soft: [301 untrusted input](../301/untrusted-input.md) (bounds matter even more on embedded targets).

## Mental model

Picture two libraries speaking the same byte language but living under different memory contracts. The tags, varints, and length-delimited fields are the same. The way each library stores values in C memory is not.

```text
  Same wire (tags, varints, LEN fields)
           │
     ┌─────┴──────┐
     ▼            ▼
 protobuf-c      nanopb
 descriptor      static layout /
 heap unpack     streams + max sizes
```

## Design axes (comparison)

| Axis | **protobuf-c** | **nanopb** |
|------|----------------|------------|
| **Primary goal** | General C interoperability | Embedded / constrained devices |
| **Schema at runtime** | `ProtobufCMessageDescriptor` tables | Field lists / generated bind info; options in `.proto` or `.options` |
| **Allocation** | `unpack` typically uses the **heap**; free with `*_free_unpacked` | Prefer **static** structs; optional dynamic allocation only with care |
| **Size limits** | Practical heap limits | **Max count/size** often required for repeated fields, strings, and bytes |
| **API shape** | Fill a struct → `get_packed_size` / `pack`; then `unpack` | `pb_ostream_t` / `pb_istream_t`; `pb_encode` / `pb_decode` |
| **Callbacks** | Less central | Common for large or unknown-length fields |
| **Submessages** | Pointers plus recursive unpack | Nested structs or callbacks, depending on options |
| **Unknown fields** | Often retained for round-trip | Policy and options; not “always keep” the way desktop stacks often do |
| **Typical failure** | Out of memory, or a leak if free is skipped | Encode/decode fails if data exceeds a static max |
| **Suite registration** | `protobuf-c` | `nanopb` (a separate log name—compare within C and the schema-driven family) |

**Ownership contrast.** Ownership means who allocates memory and who must free it. protobuf-c leans on the heap for unpack. nanopb prefers pre-sized static storage so that, in the common case, nothing needs to be freed at all.

```text
protobuf-c
  struct (stack/heap)
       │
       ▼  get_packed_size + pack
  caller buffer (you allocated)
       │
       ▼  unpack
  heap message  ──►  free_unpacked()

nanopb
  static struct (max sizes baked in)
       │
       ▼  pb_encode → pb_ostream_t
  static buffer (pre-sized from worst case)
       │
       ▼  pb_decode → pb_istream_t
  static struct  ──►  usually nothing to free
```

## Minimal nanopb sketch

Illustrative only—field names and generated symbols depend on your `.proto` / `.options` and nanopb version ([upstream docs](https://jpa.kapsi.fi/nanopb/)).

```c
/* After nanopb codegen: MiniUser has e.g. name[32], tags_count, tags[8] */
MiniUser user = MiniUser_init_zero;
user.id = 1;
strncpy(user.name, "Ada", sizeof(user.name) - 1);
user.has_name = true;   /* if your options use has_ flags */

uint8_t buffer[64];
pb_ostream_t ostream = pb_ostream_from_buffer(buffer, sizeof(buffer));
if (!pb_encode(&ostream, MiniUser_fields, &user)) {
    /* buffer full or encode error */
}

MiniUser out = MiniUser_init_zero;
pb_istream_t istream = pb_istream_from_buffer(buffer, ostream.bytes_written);
if (!pb_decode(&istream, MiniUser_fields, &out)) {
    /* truncated, bad wire, or exceeds max sizes */
}
```

### When valid Protocol Buffers still fails nanopb

Suppose `name` is generated as an 8-byte array (`max_size:8`, including a null terminator in some setups) and the peer sends a longer string that is still **valid** length-delimited Protocol Buffers:

1. protobuf-c `unpack` → a heap string of full length (until you run out of memory).
2. nanopb `pb_decode` → **false** / error: the value does not fit the static contract.

That is intentional for embedded safety, not a wire-format bug. The same pattern applies when a `repeated` field’s count exceeds `max_count`. This matters because teams sometimes mislabel a max-size reject as “our encodings are incompatible,” when the real issue is a deployment contract about size.

## Step-by-step: how nanopb thinks about encode

Logical model of [nanopb](https://jpa.kapsi.fi/nanopb/). Always check your nanopb version’s documentation for details.

### N1 — Describe fields with size budgets

Code generation (from `.proto` plus optional `.options`) produces a C struct where:

- Scalars are plain fields.
- Strings and bytes are often **fixed arrays**, or a pointer-plus-callback pair with a **maximum length**.
- Repeated fields have a **max count** (or a callback that streams elements).

If the logical Protocol Buffers message can be unbounded, nanopb forces you to **cap** it at design time. That is the opposite of “malloc until it fits.”

### N2 — Output stream

```text
pb_ostream_t = buffer stream | callback stream
pb_encode(&stream, FieldList, &struct)
```

Encode walks the field list:

1. For each present field, emit a **tag** (same wire key rule as everywhere else).
2. Emit the payload (varint, fixed, or length-delimited).
3. Nested messages encode into the stream as length-delimited blobs.
4. On buffer full or max exceeded → **false** / error (no silent realloc by default).

### N3 — No separate “get_packed_size then malloc” requirement

You can size a static buffer from worst-case maxima, or use a sizing stream. The mental model is **stream into a budget**, not “measure an unlimited tree and then allocate.”

## Step-by-step: how nanopb thinks about decode

### N4 — Input stream

```text
pb_istream_t from buffer or callback
pb_decode(&stream, FieldList, &struct)
```

### N5 — Tag loop with hard limits

1. Read a tag → field number and wire type.
2. Match against the field list.
3. Decode into static storage; if a repeated count would exceed its max → **fail**.
4. Unknown fields: skip by wire type (and optional callbacks).
5. Nested messages: decode a length-delimited blob into a nested struct (or a callback).

### N6 — Success means “fits the static contract”

A message that is valid Protocol Buffers for protobuf-c can still be **rejected** by nanopb if it exceeds configured maxima. That is by design for embedded safety.

## Side-by-side with protobuf-c pack/unpack

| Stage | protobuf-c | nanopb |
|-------|------------|--------|
| Prepare | Fill a struct (heap pointers are fine) | Fill a static struct / set counts |
| Size | `get_packed_size` over an unlimited logical tree | Worst-case size from maxima, or a sizing encode |
| Encode | `pack` into a caller buffer | `pb_encode` to a `pb_ostream_t` |
| Decode | `unpack` → heap tree | `pb_decode` into a preallocated struct |
| Teardown | `free_unpacked` | Usually nothing (stack or static) |
| Hostility | Need an external size cap | Maxima and stream limits help; you still validate |

## When to choose which

| Situation | Lean |
|-----------|------|
| Linux or service C with variable-length documents | **protobuf-c** |
| MCU with no heap or a tiny heap | **nanopb** |
| Same process as desktop tools that need full unknown-field round-trip | Often **protobuf-c** |
| Sensor stream with a fixed maximum number of samples | **nanopb** |
| Team already owns protobuf-c everywhere | Stay with it; do not dual-stack without a reason |

Whether to use Protocol Buffers at all is a [301](../301/index.md) product and polyglot question. This page is about **which C engine** once that choice is made.

## In this suite

| Entry | Role |
|-------|------|
| `protobuf` | Official **Google libprotobuf** on C (sysroot); full generated messages from `benchmark_v2.proto` |
| `protobuf-c` | Separate log name; linked **v1.5.0**; timed path is currently the shared `fixture_pb_v2` wire helper (see [C Overview](../../c/index.md)) |
| `nanopb` | Separate log name; linked **0.4.9** (`ser_nanopb.c`); timed path is currently the **same** shared wire helper—not a full nanopb `pb_encode` / options-codegen benchmark |
| `protobuf-wire` | In-tree proto3 tags only (not Google upb) |
| [C Results](../../c/results.md) | Compare **within C** and the schema-driven family ([301 using this suite](../301/using-this-suite.md)); regenerate after benchmark runner changes |

Do **not** treat suite `nanopb` vs `protobuf-c` rows as a head-to-head of full library stacks until each times its native generated path. The article above still describes the real engines for product choices outside the suite.

## Common mistakes

- Using nanopb without setting max sizes, then “fixing” by enabling unbounded dynamic mode everywhere (that loses the point of nanopb).
- Assuming nanopb decode allocates like protobuf-c.
- Mixing generated headers from different generators in one translation unit.
- Cross-ranking C Results against Python or Rust when choosing an engine ([cross-language fidelity](protobuf-cross-language-fidelity.md)).
- Calling a max-size reject a “wire bug” when the peer used protobuf-c with no caps.

## What this article is not

- A full nanopb options reference (see upstream nanopb docs).
- upb-C or other C bindings.
- A hand-rolled wire lab (see the [lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- **Same wire format, different memory contracts.**
- protobuf-c = descriptor tables plus heap-friendly pack/unpack.
- nanopb = static budgets plus streams; fails closed when data exceeds caps.
- In this suite there are two names under one language—compare fairly, and choose by deployment constraints.
