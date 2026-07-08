# Memory layout

## Problem

A structure in C, a record in Go, or an object graph in a managed language occupies a region of the process’s address space. Writing that region to disk or to a network socket appears inexpensive: no schema file, no serialization library, and high throughput on *this* machine.

A second process—implemented in another language, running on another processor architecture, or built with different structure-packing rules—may then read those bytes and obtain incorrect values, fail abruptly, or interpret numbers silently wrong. Serialization exists largely because **in-memory layout is not a contract between machines**.

---

## Short answer

Compilers and language runtimes place fields in memory for **the local processor and operating environment**: native integer widths, pointer sizes, alignment padding, and often **host byte order**. Those placement rules are part of how a given platform expects machine code and data to look in RAM; they are chosen for local efficiency, not for exchange with other machines. Networks and durable storage exchange only a **linear sequence of bytes under an agreed interpretation**. A portable format must define field order, sizes (or length prefixes), padding (or its absence), and endianness—or it must be self-describing enough that readers need not assume the writer’s in-memory layout. Raw memory dumps optimise for one process image; interchange formats optimise for a shared contract.

---

## Mental model

Main memory may be viewed as a linear array of **bytes** (integer values from 0 through 255), each identified by an address 0, 1, 2, …. Program variables and objects are **contiguous or linked groups of those bytes**, interpreted under a rule (“these four bytes constitute a 32-bit integer,” “these eight bytes constitute an address of further bytes,” and so on).

```text
  In-memory (one process)              On the wire (agreed contract)
  ┌─────────────────────┐              ┌──────────────────────────┐
  │ numbers, padding,   │   serialize  │ fixed or tagged fields   │
  │ pointers into heap  │  ────────►   │ agreed sizes and order   │
  │ runtime metadata    │              │ no host-only pointers    │
  └─────────────────────┘              └──────────────────────────┘
         ▲                                        │
         │              deserialize               │
         └────────────────────────────────────────┘
              rebuild local objects or views
```

A dump of process-local memory includes padding, pointer addresses, and host-specific byte order. Another machine cannot treat that sequence as the same values unless the parties **define a contract** (a serialization format).

---

## How it works

### Representations of common values as bytes

Detailed processor microarchitecture is unnecessary here. The essential questions are: **how many bytes does this value occupy**, and **does the variable store the value itself or a reference to bytes stored elsewhere?**

| Kind of value (typical modern desktop or server) | Width | Contents at the variable’s address |
|--------------------------------------------------|-------|-------------------------------------|
| Small integer (8-bit unsigned) | 1 byte | The integer itself (0–255) |
| 32-bit integer (e.g. C `int32_t`) | 4 bytes | The integer, split across four bytes (order determined by endianness) |
| 64-bit integer | 8 bytes | As above, eight bytes |
| 32-bit binary floating-point (`float`) | 4 bytes | An IEEE 754 bit pattern—not the decimal characters of a printed number |
| 64-bit binary floating-point (`double`) | 8 bytes | As above, eight bytes |
| Fixed array of three bytes | 3 bytes (padding may follow inside a structure) | Those three bytes in order |
| Text string in C (`char *`) | Pointer width (often 8 bytes on 64-bit processes) | An **address** of character data elsewhere—not the characters themselves |
| Text string in Python, Java, C#, or JavaScript | A **reference** to a heap object | Length, character data, and type metadata live in that object, not as a single trivial blob at the variable |

**Integer example (before endianness).** The integer 305 419 896 is commonly written in hexadecimal as `0x12345678`. As a 32-bit integer it occupies **four** bytes. Which address receives `0x12` versus `0x78` is a matter of **endianness** (below). The pedagogical point: **the value is not stored as the decimal characters** `3` `0` `5` … unless a text format such as JSON is used deliberately.

**Floating-point example.** The value `1.5` as a 32-bit binary float is a specific 32-bit pattern defined by IEEE 754—not the three characters `1`, `.`, and `5`. Text is appropriate for human display; processors perform arithmetic on the binary pattern.

**String example (why copying the variable fails as interchange):**

```text
  Variable `name` (eight bytes on a typical 64-bit process):
  ┌──────────────────────────┐
  │  address 0x7ff…abc0      │  ──pointer──►  heap: 'A' 'd' 'a' '\0'
  └──────────────────────────┘                 (or a richer string object)
```

Copying only those eight bytes copies an **address that is meaningless in another process**. A serialization format must transmit the **character data** (with length or terminator rules), not the pointer.

### Field order and padding

A **structure** or **record** comprises several fields placed at successive addresses. Two facts matter for binary dumps:

1. **Order** — which field occupies the lower addresses (often declaration order in C-like languages, though not a universal law).  
2. **Padding** — unused bytes inserted so that the *next* field begins at an address the processor can load efficiently (for example, a multiple of four or eight).

#### Why padding exists

Many processors load a four-byte integer most efficiently when its starting address is a **multiple of four** (and an eight-byte quantity when the address is a multiple of eight). Compilers **align** fields to such boundaries by inserting unused **padding** bytes. Those bytes do not appear in source code; they still appear in memory and in an uninterpreted memory dump.

Simplified rules used by many C compilers on common desktop and server platforms (exact rules depend on the compiler, operating system, and CPU):

- a one-byte field may begin at any address;  
- a four-byte field begins at an address divisible by four;  
- an eight-byte field or pointer on a typical 64-bit platform begins at an address divisible by eight.

The instructional conclusion is that **unused gaps appear** between fields.

#### Identical fields, different layouts

Consider three logical fields:

- `flag` — one byte (for example 0 or 1);  
- `id` — four-byte integer;  
- `score` — eight-byte integer (or a pointer-sized field).

**Layout 1 — order `flag`, `id`, `score` (typical 64-bit C-like padding):**

```text
  offset  0:  flag          [1 byte]
  offset  1:  pad pad pad   [3 bytes]   ← so that id begins at a multiple of 4
  offset  4:  id            [4 bytes]
  offset  8:  score         [8 bytes]
  ---------------------------------
  total size often 16 bytes, although only 13 bytes carry domain data
```

**Layout 2 — order `score`, `id`, `flag`:**

```text
  offset  0:  score         [8 bytes]
  offset  8:  id            [4 bytes]
  offset 12:  flag          [1 byte]
  offset 13:  pad pad pad   [3 bytes]   ← structure size often rounded to 16
  ---------------------------------
  total size often still 16 bytes, but field positions differ
```

Even when both layouts occupy 16 bytes, a reader that assumes Layout 1 and receives Layout 2 misinterprets `id` and `score`. If sizes differ across compilers or packing attributes (for example `#pragma pack`), offsets diverge further.

**Conclusion:** agreement that both parties “have flag, id, and score” is **insufficient** for an uninterpreted binary dump. The parties need agreed **order, sizes, and padding**—or a format that encodes fields without host padding.

#### Uninterpreted memory dump

For Layout 1 with `flag = 1`, `id = 42`, `score = 7` on a **little-endian** host (least significant byte at the **lowest** address—the usual rule on x86 and many ARM systems). Hexadecimal byte values use two digits per byte (for example `2a` means decimal 42).

Byte-by-byte map (each row is one address; field borders cannot drift):

| Offset | Byte (hex) | Belongs to | Role in the value |
|-------:|:----------:|------------|-------------------|
| 0 | `01` | **flag** | entire value → **1** |
| 1 | `00` | pad | unused |
| 2 | `00` | pad | unused |
| 3 | `00` | pad | unused |
| 4 | `2a` | **id** | least significant byte (`2a`₁₆ = 42₁₀) |
| 5 | `00` | **id** | |
| 6 | `00` | **id** | |
| 7 | `00` | **id** | most significant byte → together **id = 42** |
| 8 | `07` | **score** | least significant byte (`07`₁₆ = 7₁₀) |
| 9 | `00` | **score** | |
| 10 | `00` | **score** | |
| 11 | `00` | **score** | |
| 12 | `00` | **score** | |
| 13 | `00` | **score** | |
| 14 | `00` | **score** | |
| 15 | `00` | **score** | most significant byte → together **score = 7** |

Compact one-line view. Each column is exactly three characters (`NN` plus a space), so the `field` markers line up under the same offsets as `byte`:

```text
offset  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 
byte    01 00 00 00 2a 00 00 00 07 00 00 00 00 00 00 00 
field   F  p  p  p  I  I  I  I  S  S  S  S  S  S  S  S  
```

Legend: **F** = `flag` (value **1** at offset 00 only) · **p** = padding · **I** = `id` little-endian (**42** from `2a 00 00 00` at 04–07) · **S** = `score` little-endian (**7** from `07` then seven `00` at 08–15). Trailing zeros on multi-byte fields are high-order bits of a small number; they do **not** mean the value is zero.

**Same layout with `id = 43`** (still `flag = 1`, `score = 7`): only the byte under the first **I** changes (`2a` → `2b`, because 43₁₀ = `2b`₁₆).

```text
offset  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 
byte    01 00 00 00 2b 00 00 00 07 00 00 00 00 00 00 00 
field   F  p  p  p  I  I  I  I  S  S  S  S  S  S  S  S  
```

| Decimal | Hex | Little-endian 4-byte pattern (`id`) |
|--------:|-----|--------------------------------------|
| 42 | `2a` | `2a 00 00 00` |
| 43 | `2b` | `2b 00 00 00` |
| 256 | `100` | `00 01 00 00` (second byte becomes non-zero) |
| 7 as 64-bit `score` | `7` | `07 00 00 00 00 00 00 00` |

On a **big-endian** host the multi-byte fields would reverse byte order within each field (for example `id = 42` as `00 00 00 2a`). That is why uninterpreted dumps are not portable across endianness. Endianness is developed further in the next section.

A portable format might transmit only domain data under an explicit rule—for example “one-byte flag, then four-byte little-endian `id`, then eight-byte little-endian `score`,” **without** the three padding zeros—or employ JSON, MessagePack, or Protocol Buffers so that field identity does not depend on host offsets.

#### Same record in two languages

```c
/* C (illustrative) */
struct Player { char flag; int32_t id; int64_t score; };
```

```python
# Python — not a C memory layout
player = {"flag": 1, "id": 42, "score": 7}
```

The Python dictionary comprises references and hash-table machinery in the interpreter heap. There is **no** single 16-byte image equivalent to the C structure. “Binary dump of my object” is meaningful, if at all, **only inside one language and one compiler/runtime on one platform**—and often not even then for managed objects.

### Endianness

A multi-byte integer is stored as **several bytes in a defined order**. Two common conventions are:

- **Big-endian (BE):** most significant byte at the lowest address (analogous to writing the decimal numeral 1234 from left to right).  
- **Little-endian (LE):** least significant byte at the lowest address—common on x86/x86-64 and many ARM hosts.

**Example:** 32-bit value `0x12345678` (decimal 305 419 896):

```text
  Increasing addresses →

  Big-endian:     12  34  56  78
  Little-endian:  78  56  34  12
```

If a little-endian writer emits those four bytes and a big-endian reader loads them as a native integer **without conversion**, the reader obtains a different numeric value. Network protocols historically adopted a **network byte order** (classical Internet Protocol stacks: big-endian). Every serialization format must **document** endianness—or avoid host integers as the interchange unit (for example decimal text in JSON). See also the [historical perspective](../101/historical_perspective.md).

Binary floating-point values are subject to the same byte-order considerations when stored in memory.

### Alignment and zero-copy formats

Formats designed for **in-place reads** (FlatBuffers-class designs—see [Zero-copy](zero-copy.md)) place fields so that a host can load integers from buffer offsets with limited extra work (typically assuming a documented endianness). That arrangement is not the absence of a format; it is a **layout specification** that resembles a convenient memory image while still forbidding raw host pointers into another process’s heap.

### Managed objects and graphs

In C, a small structure may store integers **inline** (the bytes of `id` sit inside the structure itself). In managed languages (Python, Java, C#, JavaScript, and similar environments), a “record” or “object” is often a **graph**: the variable holds a **reference** (an address-like handle into a heap managed by the runtime), and fields may be further references to strings, lists, or nested objects. Those addresses are meaningful only inside **this process** and **this runtime**; they must not be treated as portable data.

Serializing such a structure “as memory” would require:

1. following every reference to the objects it points to;  
2. defining behaviour for **shared** objects (one object reachable by two paths) and **cycles** (A refers to B and B refers to A);  
3. recording **type** information so that the receiver can reconstruct objects of the correct kinds.

#### Nested object with a string field

Logical value in Python (the same idea applies in Java, C#, or JavaScript):

```python
player = {"id": 42, "name": "Ada"}
```

Illustrative layout in the heap (addresses are fictional):

```text
  Variable `player` ──ref──►  Map object @ 0xA100
                                │
                                ├─ key "id"   ──ref──►  Int object (value 42) @ 0xB200
                                │
                                └─ key "name" ──ref──►  String object @ 0xC300
                                                         characters: 'A' 'd' 'a'
                                                         length / type metadata …
```

What a naïve “dump of `player`” would capture depends on the language, but it is **not** the twelve bytes of a packed C `struct { int32_t id; char name[4]; }`. More often one would obtain only the **reference** to the map (a machine word), or a runtime-specific object header—neither of which another process can interpret as “id 42 and name Ada.”

A portable encoding must emit the **logical content**, for example:

```json
{"id": 42, "name": "Ada"}
```

or an equivalent binary form that stores the integer 42 and the character data of `"Ada"`, not the heap addresses `0xA100`, `0xB200`, or `0xC300`.

#### Shared reference (one object, two paths)

```python
label = "urgent"
task_a = {"title": label}
task_b = {"title": label}   # same string object, not a second copy
```

```text
  task_a ──► { title ──┐ }
                       ├──► String "urgent" @ 0xD400
  task_b ──► { title ──┘ }
```

In memory there is **one** string object and **two** references to it. A graph-aware native serializer may record that sharing (write the string once, then two back-references). A simple tree encoding (typical JSON) writes the characters twice:

```json
{"title": "urgent"}
{"title": "urgent"}
```

Both approaches can be correct for a given product; they are **different contracts**. An uninterpreted memory dump does not choose either contract—it only freezes process-local addresses that are useless elsewhere.

#### Cycle

```python
a = {}
b = {"peer": a}
a["peer"] = b
```

```text
  a @ 0xE100 ──peer──► b @ 0xE200
       ▲                    │
       └──────peer──────────┘
```

A depth-first “copy every field” walk never terminates unless the serializer **detects** objects it has already visited. Language-native tools (for example Python `pickle`) implement such detection for **one** runtime. Portable message formats often **forbid** cycles, or require the application to replace them with explicit identifiers (for example integer keys into a table of nodes).

#### Contrast with an inline C structure

```c
struct Player {
    int32_t id;
    char name[4];   /* fixed inline storage: 'A','d','a','\0' — still not a general string model */
};
```

Here `id` and the four `name` bytes can sit **inside** one contiguous block (plus padding rules from earlier sections). Even so, as soon as `name` becomes a `char *` pointer to a heap buffer, the C picture becomes a small graph as well: the structure holds an address, and the characters live elsewhere.

| Approach | What is stored for a string field | Portable as a raw dump? |
|----------|-----------------------------------|-------------------------|
| Inline fixed array in C | Character bytes inside the structure | Only with agreed size, order, and encoding |
| Managed object / `char *` | Reference (address or handle) to data elsewhere | **No** — addresses are process-local |
| JSON / MessagePack / schema codec | Length or delimiters plus character bytes (or field numbers plus values) | **Yes**, under that format’s rules |
| Language-native graph serializer (`pickle`, Java serialization, …) | Runtime type tags, handles, and payload for **that** VM | Only to the **same** language/runtime family; unsafe on untrusted input |

Language-native serializers perform graph walking for **one** runtime. Portable formats ordinarily flatten data to **trees or tables of values** (numbers, character data for strings, nested records) under explicit rules—never “here is a heap address from this virtual machine.”

---

## Costs and constraints

| Axis | What changes | What usually does not |
|------|----------------|------------------------|
| Processor time | Byte swaps or copies when host endianness differs from the wire; scanning padding versus dense packing | The need for *some* layout rule |
| Memory / allocations | Dense packed buffers versus pointer-rich graphs | A costless solution that ignores portability |
| Size / bandwidth | Padding wastes bytes; pointers become identifiers or nested payloads | Free portability of raw `sizeof` dumps |
| Operability | Hexadecimal dumps of packed formats require a decoder | Informal dumps that appear simple in a single-host debugger |
| Security / trust | Accepting raw native images from untrusted parties is hazardous | — |

---

## Illustrative scenario

A game client on a little-endian laptop writes player state with an uninterpreted copy of a packed C structure and uploads it to a backend. The backend may use a different compiler or CPU convention for field layout, or a managed language that stores fields in an entirely different way for garbage collection. Inventory counts become incorrect; the defect appears to be application logic until the byte sequences are compared with an endian-aware viewer.

A durable remedy is not an informal document describing structure packing. It is an explicit format (even a simple length-prefixed little-endian layout, or a schema-driven codec) shared by both ends.

---

## In this suite

The harness measures **codecs**, not raw structure dumps: each registered serializer implements a defined encode and decode path over the same logical fixtures. That choice is deliberate—portable interchange is the subject of multi-language comparison.

**Results** therefore reflect the cost of *those* contracts (JSON text, MessagePack tags, Protocol Buffers field encodings, and so on), not an uninterpreted memory-copy baseline. For family groupings, see [Serialization categories](../../analysis/serialization_categories.md).

---

## Common errors of practice

- Treating `sizeof` together with an uninterpreted binary write as a multi-language interface.  
- Forgetting that **padding and field order** are decisions of the compiler and platform, not merely part of a mental model of the domain object.  
- Assuming that the prevalence of little-endian hosts makes endianness irrelevant—**embedded systems, network equipment, and file formats** still require a written rule.  
- Confusing **host layout** with **zero-copy wire layout**; the latter is designed, versioned, and free of host pointers.  
- Transmitting language-native serializations of object graphs across a trust boundary (see security notes in the [engineering perspective](../101/engineer_perspective.md)).

---

## Key takeaways

- In-memory layout optimises for one processor and runtime; the wire optimises for a shared contract.  
- Padding, field order, pointer representation, and endianness all invalidate uninterpreted dumps as interchange.  
- Portable formats replace host assumptions with explicit sizes, order, and byte order (or self-describing tags).  
- Zero-copy formats still define a layout; they make that layout readable in place.  
- Multi-language systems require an agreed encoding, not merely a shared C header.  
- Measure real codecs on representative payloads; do not treat a local memory-copy microbenchmark as an interchange strategy.

---
