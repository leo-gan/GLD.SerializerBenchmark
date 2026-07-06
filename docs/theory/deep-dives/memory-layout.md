# Memory layout, alignment, and endianness

> After this page you can explain why a raw in-memory dump is not a portable interchange format—and what a wire format must fix up.

---

## Problem

You have a struct in C, a record in Go, or an object graph in a managed language. “Just write the bytes to disk” feels free: no schema, no library, maximum speed on *this* machine.

Then a second process—another language, another CPU architecture, or the same code rebuilt with different packing—reads those bytes and sees garbage, a crash, or silent wrong numbers. Serialization exists largely because **in-memory layout is not a contract between machines**.

---

## Short answer

Languages and ABIs place fields in memory for **the local CPU and runtime**: native integer widths, pointer sizes, alignment padding, and often **host byte order**. The network and long-lived storage only understand a **linear, agreed sequence of bytes**. A portable format must define field order, sizes (or length prefixes), padding (or lack of it), and endianness—or it must be self-describing enough that readers do not assume host layout. Raw dumps optimize for one process image; interchange formats optimize for a shared contract.

---

## Mental model

```text
  In-memory (one process)              On the wire (agreed contract)
  ┌─────────────────────┐              ┌──────────────────────────┐
  │ ptr │ pad │ int32   │   serialize  │ fixed or tagged fields   │
  │ ────────► heap obj  │  ────────►   │ canonical byte order     │
  │ … runtime headers … │              │ no host pointers         │
  └─────────────────────┘              └──────────────────────────┘
         ▲                                        │
         │              deserialize               │
         └────────────────────────────────────────┘
              rebuild local objects / views
```

Pointers, vtables, and allocator metadata are **meaningless** outside the process that produced them. Even “plain” integer fields disagree across machines without a byte-order rule.

---

## How it works

### Field order and padding

Compilers often insert **padding** so multi-byte fields sit on alignment boundaries the CPU prefers (e.g. 4- or 8-byte). Two structs with the “same” logical fields can have different sizes if field order or packing attributes differ. A naïve `fwrite(&s, sizeof s, 1, f)` records that padding and that order forever.

### Endianness

A multi-byte integer is a sequence of bytes. **Big-endian** stores the most significant byte first; **little-endian** stores the least significant first. The value `0x01020304` is `01 02 03 04` on the wire in big-endian and `04 03 02 01` in little-endian. Read with the wrong convention and you get a different integer—historically a hard lesson on heterogeneous networks (see network byte order in the [historical perspective](../historical_perspective.md)).

Many modern formats pick one order (often little-endian for speed on common CPUs, or big-endian for “network order” tradition) and document it. Some (e.g. parts of Unicode text encodings) avoid the issue by not treating host integers as the interchange unit.

### Alignment and zero-copy

Formats that want **in-place reads** (FlatBuffers-class designs—see [Zero-copy layouts](zero-copy.md)) carefully place fields so a little-endian host can load integers directly from a buffer offset. That is not “no format”; it is a **layout specification** that *mimics* a friendly memory image while still forbidding raw host pointers.

### Managed objects and graphs

In C#, Java, Python, or JS, “the object” is a web of references. Serializing “memory” would mean chasing pointers, handling cycles, and encoding type identity. Language-native serializers do that for one runtime; portable formats usually flatten to **trees or records** with explicit identity rules.

---

## Costs & constraints

| Axis | What changes | What usually does not |
|------|----------------|------------------------|
| CPU | Extra swaps/copies if host endian ≠ wire endian; padding scan vs dense pack | The need for *some* layout rule |
| Memory / allocations | Dense packed buffers vs pointer-rich graphs | “Zero cost” of ignoring the problem |
| Size / bandwidth | Padding can waste bytes; pointers become ids or nested payloads | Free portability of `sizeof` dumps |
| Operability | Hex dumps of packed formats need a decoder | Ad-hoc dumps looking “simple” in a debugger on one host |
| Security / trust | Accepting raw native images from others is a classic footgun | — |

---

## Real-world example

A game client on a little-endian laptop writes player state with `memcpy` of a packed C struct and uploads it to a backend. The backend runs on a different ABI or a language that reorders fields for GC. Inventory counts scramble; the failure looks like “logic bugs” until someone diffs bytes with an endian-aware viewer.

The durable fix is not “document our struct packing in a wiki and hope.” It is an explicit format (even a simple length-prefixed little-endian layout, or a schema-driven codec) shared by both ends.

---

## In this suite

The harness measures **codecs**, not raw struct dumps: each registered serializer implements a defined encode/decode path over the same logical fixtures. That is intentional—portable interchange is what multi-language comparison means.

When you read **Results**, you are seeing cost of *those* contracts (JSON text, MessagePack tags, Protobuf field encodings, etc.), not the mythic “just write memory” baseline. For family groupings, see [Serialization categories](../../analysis/serialization_categories.md).

---

## Common mistakes

- Treating `sizeof` + binary write as a multi-language API.
- Forgetting that **padding and field order** are part of the ABI, not part of your mental model of the domain object.
- Assuming “everyone is little-endian now” means endianness is irrelevant—**embedded, network gear, and file formats** still need a written rule.
- Confusing **host layout** with **zero-copy wire layout**; the latter is designed, versioned, and pointer-free.
- Shipping native serialization of object graphs across a trust boundary (see security notes in [Engineering](../engineer_perspective.md)).

---

## Key takeaways

- In-memory layout optimizes for one CPU/runtime; the wire optimizes for a shared contract.
- Padding, field order, pointer shape, and endianness all break naïve dumps.
- Portable formats replace host assumptions with explicit sizes, order, and byte order (or self-describing tags).
- Zero-copy formats still define a layout—they just make that layout readable in place.
- Multi-language systems need an agreed encoding, not a shared C header alone.
- Measure real codecs on real payloads; do not use “memcpy was fast in a microbench” as an interchange strategy.

---
