# C: nanopb vs protobuf-c

## Problem

Both **protobuf-c** and **nanopb** claim “Protobuf for C,” but they optimize for different worlds: general services with heap messages versus **embedded** systems with static budgets. Treating them as interchangeable APIs produces the wrong memory model, the wrong failure modes, and unfair suite comparisons.

## Short answer

Use **protobuf-c** when you want classic generated structs, descriptor-driven pack/unpack, and heap-friendly services ([protobuf-c path](protobuf-c-protobuf-c.md)). Use **nanopb** when RAM/flash are tight, you can declare **maximum sizes** in options, and you accept stream/callback-oriented encode/decode instead of free-form heap trees. Wire format remains Protobuf binary ([wire format](protobuf-wire-format.md)); **engineering**—allocation, codegen, APIs—diverges.

## Prerequisites

- [C: protobuf-c path](protobuf-c-protobuf-c.md) (primary C path).  
- [Wire format](protobuf-wire-format.md).  
- Soft: [301 untrusted input](../301/untrusted-input.md) (bounds matter even more on embedded).

## Mental model

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
| **Primary goal** | General C interoperability | Embedded / constrained |
| **Schema at runtime** | `ProtobufCMessageDescriptor` tables | Field lists / generated bind info; options in `.proto` or `.options` |
| **Allocation** | `unpack` typically **heap**; free with `*_free_unpacked` | Prefer **static** structs; optional dynamic with care |
| **Size limits** | Practical heap limits | **Max count/size** often required for repeated/string/bytes |
| **API shape** | Fill struct → `get_packed_size` / `pack`; `unpack` | `pb_ostream_t` / `pb_istream_t`; `pb_encode` / `pb_decode` |
| **Callbacks** | Less central | Common for large/unknown-length fields |
| **Submessages** | Pointers + recursive unpack | Nested structs or callbacks depending on options |
| **Unknown fields** | Often retained for round-trip | Policy/options; not “always keep” like desktop stacks |
| **Typical failure** | OOM / leak if free skipped | Encode/decode fail if data exceeds static max |
| **Suite registration** | `protobuf-c` | `nanopb` (separate name—compare within C + schema family) |

**Ownership contrast (quick diagram)**

protobuf-c: struct → pack → your buffer → unpack → heap message → `free_unpacked()`

nanopb: static struct (with max sizes) → `pb_encode` (stream) → static buffer → `pb_decode` (into static struct) → usually nothing to free

## Step-by-step: how nanopb thinks about encode

(Logical model of [nanopb](https://jpa.kapsi.fi/nanopb/); always check your nanopb version docs.)

### N1 — Describe fields with size budgets

Codegen (from `.proto` + optional `.options`) produces a C struct where:

- Scalars are plain fields.  
- Strings/bytes often are **fixed arrays** or pointer+callback with a **maximum length**.  
- Repeated fields have a **max count** (or callback to stream elements).

If the logical Protobuf message can be unbounded, nanopb forces you to **cap** it at design time—the opposite of “malloc until it fits.”

### N2 — Output stream

```text
pb_ostream_t = buffer stream | callback stream
pb_encode(&stream, FieldList, &struct)
```

Encode walks the field list:

1. For each present field, emit **tag** (same wire key rule).  
2. Emit payload (varint, fixed, length-delimited).  
3. Nested messages encode into the stream (length-delimited).  
4. On buffer full or max exceeded → **false** / error (no silent realloc by default).

### N3 — No separate “get_packed_size then malloc” requirement

You can size a static buffer from worst-case maxima, or use a sizing stream. The mental model is **stream into a budget**, not “measure unlimited tree then allocate.”

## Step-by-step: how nanopb thinks about decode

### N4 — Input stream

```text
pb_istream_t from buffer or callback
pb_decode(&stream, FieldList, &struct)
```

### N5 — Tag loop with hard limits

1. Read tag → field number / wire type.  
2. Match against the field list.  
3. Decode into static storage; if repeated count would exceed max → **fail**.  
4. Unknown fields: skip by wire type (and optional callbacks).  
5. Nested: decode length-delimited into nested struct (or callback).

### N6 — Success means “fits the static contract”

A message that is valid Protobuf for protobuf-c can still be **rejected** by nanopb if it exceeds configured maxima—by design for embedded safety.

## Side-by-side with protobuf-c pack/unpack

| Stage | protobuf-c | nanopb |
|-------|------------|--------|
| Prepare | Fill struct (heap pointers OK) | Fill static struct / set counts |
| Size | `get_packed_size` unlimited logical | Worst-case from maxima or sizing encode |
| Encode | `pack` into caller buffer | `pb_encode` to `pb_ostream_t` |
| Decode | `unpack` → heap tree | `pb_decode` into preallocated struct |
| Teardown | `free_unpacked` | Usually nothing (stack/static) |
| Hostility | Need external size cap | Maxima + stream limits help; still validate |

## When to choose which

| Situation | Lean |
|-----------|------|
| Linux/service C, variable-length documents | **protobuf-c** |
| MCU, no heap or tiny heap | **nanopb** |
| Same process as desktop tools needing full unknown-field round-trip | Often **protobuf-c** |
| Sensor stream with fixed max samples | **nanopb** |
| Team already owns protobuf-c everywhere | Stay; don’t dual-stack without reason |

Product/polyglot choice of “Protobuf or not” is [301](../301/index.md); this page is **which C engine**.

## In this suite

| Entry | Role |
|-------|------|
| `protobuf-c` | Classic path; see [protobuf-c article](protobuf-c-protobuf-c.md) |
| `nanopb` | Registered separately (`ser_nanopb.c`); version pinned in registration |
| Shared helpers | Some C schema entries share fixture/wire helpers—**always read Overview notes** for what is timed and what fidelity means |
| [C Results](../../c/results.md) | Compare **within C** and schema-driven family ([301 using this suite](../301/using-this-suite.md)) |

Do not treat a faster `nanopb` row as “protobuf-c is wrong for servers,” or the reverse for MCUs.

## Common mistakes

- Using nanopb without setting max sizes, then “fixing” by enabling unbounded dynamic mode everywhere (loses the point).  
- Assuming nanopb decode allocates like protobuf-c.  
- Mixing generated headers from different generators in one translation unit.  
- Cross-ranking C Results against Python/Rust for engine choice.

## What this article is not

- Full nanopb options reference (see upstream nanopb docs).  
- upb-C or other C bindings.  
- Hand-rolled wire lab ([lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- **Same wire, different memory contracts.**  
- protobuf-c = descriptor + heap-friendly pack/unpack.  
- nanopb = static budgets + streams; fails closed when data exceeds caps.  
- Suite: two names, one language—compare fairly, choose by deployment constraints.
