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

RAM is a long street of **bytes** (numbers from 0–255), each with an address: 0, 1, 2, …. Your program’s “variables” and “objects” are just **groups of those bytes** interpreted with a rule (“these 4 bytes are an integer,” “these 8 bytes are an address of more bytes,” …).

```text
  In-memory (one process)              On the wire (agreed contract)
  ┌─────────────────────┐              ┌──────────────────────────┐
  │ numbers, pads,      │   serialize  │ fixed or tagged fields   │
  │ pointers into heap  │  ────────►   │ agreed sizes & order     │
  │ runtime bookkeeping │              │ no host-only pointers    │
  └─────────────────────┘              └──────────────────────────┘
         ▲                                        │
         │              deserialize               │
         └────────────────────────────────────────┘
              rebuild local objects / views
```

A dump of “whatever my process has in RAM” includes padding, pointer addresses, and host-specific byte order. Another machine cannot treat that blob as the same values unless you **define a contract** (a serialization format).

---

## How it works

### What a few common values look like as bytes

You do not need CPU microarchitecture here—only “how wide is this value, and is it the value itself or a *reference* to more bytes?”

| Kind of value (typical modern desktop/server) | How many bytes? | What is stored at the variable’s address? |
|-----------------------------------------------|-----------------|-------------------------------------------|
| Small integer, e.g. 8-bit “byte” / `uint8` | 1 | The number itself (0–255) |
| 32-bit integer, e.g. C `int32_t`, many “int” APIs | 4 | The number, split across 4 bytes (order = endianness) |
| 64-bit integer | 8 | Same idea, 8 bytes |
| 32-bit float (`float`) | 4 | A fixed bit pattern meaning a real number (IEEE 754)—still “just 4 bytes,” not decimal text |
| 64-bit float (`double`) | 8 | Same idea, 8 bytes |
| Fixed-size array of 3 bytes | 3 (plus possible padding after it in a struct) | The three bytes in order |
| Text string in C (`char *`) | **Pointer width** (often 8 on 64-bit machines) | **Not the letters**—an **address** (pointer) of where the characters live elsewhere |
| Text string in Python / Java / C# / JS | A **reference** (pointer-like) to a heap object | The object has length, character data, type info—scattered, not one simple “string blob” at your variable |

**Integer example (the idea, before endianness):** the number **305 419 896** is often written in hex as `0x12345678`. That single logical value needs **four** bytes when stored as a 32-bit int. Which of the four address slots gets `0x12` vs `0x78` is **endianness** (next subsection). The important beginner point: **the number is not stored as the characters `"305419896"`** unless you deliberately use a text format like JSON.

**Float example:** `1.5` as a 32-bit float is a specific 32-bit pattern defined by a standard—not the three characters `1`, `.`, `5`. Print it as text for humans; CPUs work on the binary pattern.

**String example (why “dump the variable” fails):**

```text
  Your variable `name` (8 bytes on a 64-bit process):
  ┌──────────────────────────┐
  │  address 0x7ff…abc0      │  ──pointer──►  heap: 'A' 'd' 'a' '\0'  (or a richer object)
  └──────────────────────────┘
```

If you copy only the 8 bytes of `name`, you copied an **address that is meaningless in another process**. A serialization format must copy the **characters** (and length or terminator rules), not the pointer.

### Field order and padding

A **struct** / **record** is several fields one after another in memory. Two separate facts matter for dumps:

1. **Order** — which field comes first in address order (often declaration order in C-like languages, but not a law of nature for every language).
2. **Padding** — empty bytes the compiler inserts so the *next* field starts at an address the CPU likes.

#### Why padding exists (alignment, in plain language)

Many CPUs load a 4-byte integer fastest when its starting address is a **multiple of 4** (and an 8-byte value on a multiple of 8). Compilers **align** fields to those boundaries by inserting unused **padding** bytes. You do not write those bytes in source code; they still appear in RAM and in a naïve memory dump.

Rule of thumb used by many C ABIs (simplified):

- 1-byte field → can start at any address  
- 4-byte field → start address divisible by 4  
- 8-byte field / pointer on 64-bit → start address divisible by 8  

(Exact rules are ABI-specific; the lesson is that **holes appear**.)

#### Example A — same fields, different order, different size

Imagine three logical fields:

- `flag` — 1 byte (e.g. 0 or 1)  
- `id` — 4-byte integer  
- `score` — 8-byte integer (or a pointer-sized field)

**Layout 1 — poor order for packing** (`flag`, then `id`, then `score`), typical 64-bit C-like padding:

```text
  offset  0:  flag          [1 byte]
  offset  1:  pad pad pad   [3 bytes]   ← so id starts at multiple of 4
  offset  4:  id            [4 bytes]
  offset  8:  score         [8 bytes]
  ---------------------------------
  total size often 16 bytes for 1+4+8 = 13 “real” bytes of data
```

**Layout 2 — better order** (`score`, `id`, `flag`):

```text
  offset  0:  score         [8 bytes]
  offset  8:  id            [4 bytes]
  offset 12:  flag          [1 byte]
  offset 13:  pad pad pad   [3 bytes]   ← struct size often rounded to 16
  ---------------------------------
  still often 16 bytes total, but the *positions* of each field differ
```

Even when both end up 16 bytes, a reader that assumes Layout 1 and receives Layout 2 will interpret the wrong bytes as `id` and `score`. If sizes differ between compilers or `#pragma pack` settings, offsets drift further.

**Takeaway:** “We both have flag, id, and score” is **not** enough for a binary dump. You need agreed **order, sizes, and padding** (or a format that encodes fields without host padding).

#### Example B — what a naïve dump actually writes

Suppose Layout 1 in memory for `flag=1`, `id=42`, `score=7` (little-endian machine; see next section for byte order of multi-byte fields):

```text
  offsets:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
  bytes:   01 00 00 00 2a 00 00 00 07 00 00 00 00 00 00 00
           └flag┘└─pad──┘└── id=42 ──┘└────── score=7 ──────┘
```

A portable format might instead send only the meaningful data with an explicit rule, e.g. “1 byte flag, then 4-byte little-endian id, then 8-byte little-endian score” **without** the three padding zeros—or it might use JSON / MessagePack / Protobuf so field identity does not depend on host offsets at all.

#### Example C — “same struct” in two languages

```c
// C (illustrative)
struct Player { char flag; int32_t id; int64_t score; };
```

```python
# Python — not a C layout at all
player = {"flag": 1, "id": 42, "score": 7}
```

The Python dict is pointers and hash-table machinery in the interpreter heap. There is **no** single 16-byte image that means the same as the C struct. “Binary dump of my object” is only defined **inside one language’s ABI** (and sometimes not even then, for managed objects).

### Endianness

A multi-byte integer is stored as **several bytes in some order**. Two common conventions:

- **Big-endian (BE):** most significant byte first (the “big end” at the lowest address)—like writing `1234` left-to-right.  
- **Little-endian (LE):** least significant byte first—common on x86/x86-64 and many ARM hosts.

**Example:** 32-bit value `0x12345678` (decimal 305 419 896):

```text
  Address order →

  Big-endian:     12  34  56  78
  Little-endian:  78  56  34  12
```

If a LE writer dumps those four bytes and a BE reader loads them as a native int **without converting**, the reader sees a completely different number. This is why network protocols historically picked a **network byte order** (classic IP stacks: big-endian) and why every serialization format must **document** endianness—or avoid host integers as the interchange unit (e.g. decimal text in JSON). See also the [historical perspective](../historical_perspective.md).

Floats have the same issue: their multi-byte patterns also follow an endianness when stored in RAM.

### Alignment and zero-copy

Formats that want **in-place reads** (FlatBuffers-class designs—see [Zero-copy layouts](zero-copy.md)) carefully place fields so a host can load integers from a buffer offset with little extra work (often assuming a known endianness). That is not “no format”; it is a **layout specification** that *mimics* a friendly memory image while still forbidding raw host pointers into another process’s heap.

### Managed objects and graphs

In C#, Java, Python, or JS, a “record” is often a **graph**: your variable holds a reference; fields may be more references to other objects (strings, lists, nested records). Serializing “memory” would mean:

1. Following every reference  
2. Deciding what to do about **shared** objects and **cycles**  
3. Recording **type** information so the other side can rebuild objects  

Language-native serializers (e.g. Python `pickle`) do that for **one** runtime. Portable formats usually flatten to **trees or tables of values** (numbers, strings as character data, nested records) with explicit rules—never “here is a heap address from my VM.”

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
