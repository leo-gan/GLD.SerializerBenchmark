# Memory layout

## Problem

Imagine you have a structure in C, a record in Go, or an object graph in a language such as Python or Java. That data sits somewhere in the process’s **address space**. The address space is the region of memory that process is allowed to use. Writing that region straight to disk or to a network socket can look very cheap. You need no schema file and no serialization library. On *this* machine you can often get high throughput.

A second process may then try to read those same bytes. That second process might be written in another language. It might run on another processor architecture. It might use different structure-packing rules. It can then obtain incorrect values, crash, or silently misread numbers. Serialization exists largely because **in-memory layout is not a contract between machines**.

In other words: what is efficient for one process on one machine is not, by itself, a portable way to share data.

---

## Short answer

Compilers and language runtimes place fields in memory for **the local processor and operating environment**. That placement includes native integer widths, pointer sizes, and **alignment padding**. Alignment padding is unused bytes inserted so fields sit on convenient addresses. Placement also often includes **host byte order**. Host byte order is the order in which multi-byte numbers are stored. Those rules exist so *this* machine can run efficiently. They are not designed so that another machine can understand the same bytes.

Networks and durable storage only exchange a **linear sequence of bytes under an agreed interpretation**. A portable format must define field order, sizes (or length prefixes), padding (or its absence), and **endianness**. Endianness is the byte order for multi-byte values. Alternatively, the format must be self-describing enough that readers do not need to assume the writer’s in-memory layout. Raw memory dumps optimize for one process image. Interchange formats optimize for a shared contract.

---

## Mental model

Think of main memory as a linear array of **bytes**. A byte is an integer value from 0 through 255. Each byte has an address: 0, 1, 2, and so on. Program variables and objects are **contiguous or linked groups of those bytes**. They are interpreted under a rule such as “these four bytes constitute a 32-bit integer” or “these eight bytes constitute an address of further bytes.”

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

A dump of process-local memory includes padding, pointer addresses, and host-specific byte order. Another machine cannot treat that sequence as the same values unless both sides **define a contract**. In other words, both sides need a serialization format.

---

## How it works

### Representations of common values as bytes

You do not need detailed processor microarchitecture for this course. The essential questions are simpler. **How many bytes does this value occupy?** **Does the variable store the value itself or a reference to bytes stored elsewhere?**

| Kind of value (typical modern desktop or server) | Width | What sits at the variable’s address |
|--------------------------------------------------|-------|-------------------------------------|
| Small integer (8-bit unsigned) | 1 byte | The integer itself (0–255) |
| 32-bit integer (for example C `int32_t`) | 4 bytes | The integer, split across four bytes; the order depends on endianness |
| 64-bit integer | 8 bytes | The same idea as above, using eight bytes |
| 32-bit binary floating-point (`float`) | 4 bytes | An IEEE 754 bit pattern—not the decimal characters of a printed number |
| 64-bit binary floating-point (`double`) | 8 bytes | The same idea as above, using eight bytes |
| Fixed array of three bytes | 3 bytes (padding may follow inside a structure) | Those three bytes in order |
| Text string in C (`char *`) | Pointer width (often 8 bytes on 64-bit processes) | An **address** of character data elsewhere—not the characters themselves |
| Text string in Python, Java, C#, or JavaScript | A **reference** to a heap object | Length, character data, and type metadata live in that object, not as one simple blob at the variable |

**Integer example (before endianness).** The integer 305 419 896 is commonly written in hexadecimal as `0x12345678`. As a 32-bit integer it occupies **four** bytes. Which address receives `0x12` versus `0x78` is a matter of **endianness**, discussed below. The teaching point is simple: **the value is not stored as the decimal characters** `3` `0` `5` … unless you deliberately use a text format such as JSON.

**Floating-point example.** The value `1.5` as a 32-bit binary float is a specific 32-bit pattern defined by IEEE 754. It is not the three characters `1`, `.`, and `5`. Text is appropriate for human display. Processors perform arithmetic on the binary pattern.

**String example (why copying the variable fails as interchange).** Consider a string variable on a typical 64-bit process:

```text
  Variable `name` (eight bytes on a typical 64-bit process):
  ┌──────────────────────────┐
  │  address 0x7ff…abc0      │  ──pointer──►  heap: 'A' 'd' 'a' '\0'
  └──────────────────────────┘                 (or a richer string object)
```

If you copy only those eight bytes, you copy an **address that is meaningless in another process**. A serialization format must transmit the **character data** with length or terminator rules. It must not transmit the pointer.

### Field order and padding

A **structure** or **record** is several fields placed at successive addresses. Two facts matter for binary dumps:

1. **Order** — which field occupies the lower addresses. In C-like languages this is often declaration order, though that is not a universal law.
2. **Padding** — unused bytes inserted so that the *next* field begins at an address the processor can load efficiently. Multiples of four or eight are common examples.

#### Why padding exists

Many processors load a four-byte integer most efficiently when its starting address is a **multiple of four**. They load an eight-byte quantity most efficiently when the address is a multiple of eight. Compilers **align** fields to such boundaries by inserting unused **padding** bytes. Those bytes do not appear in your source code. They still appear in memory. They still appear in an uninterpreted memory dump.

Here are simplified rules used by many C compilers on common desktop and server platforms. Exact rules depend on the compiler, operating system, and CPU:

- a one-byte field may begin at any address;
- a four-byte field begins at an address divisible by four;
- an eight-byte field or pointer on a typical 64-bit platform begins at an address divisible by eight.

The instructional conclusion is that **unused gaps appear** between fields, even when you never wrote them.

#### Identical fields, different layouts

Consider three logical fields:

- `flag` — one byte (for example 0 or 1);
- `id` — four-byte integer;
- `score` — eight-byte integer (or a pointer-sized field).

**Layout 1 — order `flag`, `id`, `score` (typical 64-bit C-like padding):**

![In-memory layout with padding: flag, pad, id, score](../assets/diagrams/201-memory-padding.svg#only-light)
![In-memory layout with padding: flag, pad, id, score](../assets/diagrams/201-memory-padding-dark.svg#only-dark)

```text
  offset  0:  flag          [1 byte]
  offset  1:  pad pad pad   [3 bytes]   ← so that id begins at a multiple of 4
  offset  4:  id            [4 bytes]
  offset  8:  score         [8 bytes]
  ---------------------------------
  total size often 16 bytes, although only 13 bytes carry domain data
```

In this diagram, an **offset** is the distance in bytes from the start of the structure. Offset 0 is the first byte. Offset 4 is four bytes later.

**Layout 2 — order `score`, `id`, `flag`:**

```text
  offset  0:  score         [8 bytes]
  offset  8:  id            [4 bytes]
  offset 12:  flag          [1 byte]
  offset 13:  pad pad pad   [3 bytes]   ← structure size often rounded to 16
  ---------------------------------
  total size often still 16 bytes, but field positions differ
```

Even when both layouts occupy 16 bytes, a reader that assumes Layout 1 and receives Layout 2 misinterprets `id` and `score`. If sizes differ across compilers or packing attributes (for example `#pragma pack`), the offsets diverge even further.

**Conclusion:** agreeing that both parties “have flag, id, and score” is **not enough** for an uninterpreted binary dump. The parties need agreed **order, sizes, and padding**. Alternatively, they need a format that encodes fields without host padding.

#### Uninterpreted memory dump

Consider Layout 1 with `flag = 1`, `id = 42`, and `score = 7` on a **little-endian** host. Little-endian means the least significant byte sits at the **lowest** address. That is the usual rule on x86 and many ARM systems. Hexadecimal byte values use two digits per byte. For example, `2a` means decimal 42.

Here is a byte-by-byte map. Each row is one address, and the field borders cannot drift:

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

Here is a compact one-line view. Each column is exactly three characters (`NN` plus a space), so the `field` markers line up under the same offsets as `byte`:

```text
offset  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 
byte    01 00 00 00 2a 00 00 00 07 00 00 00 00 00 00 00 
field   F  p  p  p  I  I  I  I  S  S  S  S  S  S  S  S  
```

Legend: **F** is `flag` (value **1** at offset 00 only). **p** is padding. **I** is `id` in little-endian form (**42** from `2a 00 00 00` at offsets 04–07). **S** is `score` in little-endian form (**7** from `07` followed by seven `00` bytes at offsets 08–15). Trailing zeros on multi-byte fields are high-order bits of a small number. They do **not** mean the whole value is zero.

**Same layout with `id = 43`** (still `flag = 1`, `score = 7`): only the byte under the first **I** changes (`2a` → `2b`, because 43₁₀ = `2b`₁₆).

```text
offset  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 
byte    01 00 00 00 2b 00 00 00 07 00 00 00 00 00 00 00 
field   F  p  p  p  I  I  I  I  S  S  S  S  S  S  S  S  
```

| Decimal | Hex | Little-endian 4-byte pattern for `id` |
|--------:|-----|--------------------------------------|
| 42 | `2a` | `2a 00 00 00` |
| 43 | `2b` | `2b 00 00 00` |
| 256 | `100` | `00 01 00 00` (the second byte becomes non-zero) |
| 7 as 64-bit `score` | `7` | `07 00 00 00 00 00 00 00` |

On a **big-endian** host the multi-byte fields would reverse byte order within each field. For example, `id = 42` would appear as `00 00 00 2a`. That is why uninterpreted dumps are not portable across endianness. The next section develops endianness more carefully.

A portable format might transmit only domain data under an explicit rule. For example: “one-byte flag, then four-byte little-endian `id`, then eight-byte little-endian `score`,” **without** the three padding zeros. Or it might use JSON, MessagePack, or Protocol Buffers so that field identity does not depend on host offsets.

#### Same record in two languages

```c
/* C (illustrative) */
struct Player { char flag; int32_t id; int64_t score; };
```

```python
# Python — not a C memory layout
player = {"flag": 1, "id": 42, "score": 7}
```

The Python dictionary is built from references and hash-table machinery in the interpreter heap. There is **no** single 16-byte image equivalent to the C structure. “Binary dump of my object” is meaningful, if at all, **only inside one language and one compiler/runtime on one platform**. Even then, it often fails for managed objects.

### Endianness

A multi-byte integer is stored as **several bytes in a defined order**. Two common conventions are:

- **Big-endian (BE):** the most significant byte sits at the lowest address. This is similar to writing the decimal numeral 1234 from left to right.
- **Little-endian (LE):** the least significant byte sits at the lowest address. This is common on x86/x86-64 and many ARM hosts.

**Example:** 32-bit value `0x12345678` (decimal 305 419 896):

![Endianness: big-endian vs little-endian byte order for 0x12345678](../assets/diagrams/201-endianness.svg#only-light)
![Endianness: big-endian vs little-endian byte order for 0x12345678](../assets/diagrams/201-endianness-dark.svg#only-dark)

If a little-endian writer emits those four bytes and a big-endian reader loads them as a native integer **without conversion**, the reader obtains a different numeric value. Network protocols historically adopted a **network byte order**. Classical Internet Protocol stacks used big-endian. Every serialization format must **document** endianness. Alternatively, it can avoid host integers as the interchange unit. Decimal text in JSON is one example of that alternative. See also the [historical perspective](../101/historical_perspective.md).

Binary floating-point values face the same byte-order considerations when stored in memory.

### Alignment and zero-copy formats

Formats designed for **in-place reads** place fields so that a host can load integers from buffer offsets with limited extra work. FlatBuffers-class designs are an example. See [Zero-copy](zero-copy.md). They typically assume a documented endianness. That arrangement is not the absence of a format. It is a **layout specification** that resembles a convenient memory image while still forbidding raw host pointers into another process’s heap.

This matters because zero-copy designs can *look* like “just memory.” They are still carefully defined contracts, not accidental dumps of process state.

### Managed objects and graphs

In C, a small structure may store integers **inline**. The bytes of `id` sit inside the structure itself. In managed languages such as Python, Java, C#, and JavaScript, a “record” or “object” is often a **graph**. The variable holds a **reference**. A reference is an address-like handle into a heap managed by the runtime. Fields may be further references to strings, lists, or nested objects. Those addresses are meaningful only inside **this process** and **this runtime**. They must not be treated as portable data.

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

What a naïve “dump of `player`” would capture depends on the language. It is **not** the twelve bytes of a packed C `struct { int32_t id; char name[4]; }`. More often you would obtain only the **reference** to the map (a machine word), or a runtime-specific object header. Neither of those can be interpreted by another process as “id 42 and name Ada.”

A portable encoding must emit the **logical content**, for example:

```json
{"id": 42, "name": "Ada"}
```

or an equivalent binary form that stores the integer 42 and the character data of `"Ada"`. It must not store the heap addresses `0xA100`, `0xB200`, or `0xC300`.

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

In memory there is **one** string object and **two** references to it. A graph-aware native serializer may record that sharing. It writes the string once, then two back-references. A simple tree encoding (typical JSON) writes the characters twice:

```json
{"title": "urgent"}
{"title": "urgent"}
```

Both approaches can be correct for a given product. They are simply **different contracts**. An uninterpreted memory dump does not choose either contract. It only freezes process-local addresses that are useless elsewhere.

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

A depth-first “copy every field” walk never terminates unless the serializer **detects** objects it has already visited. Language-native tools such as Python `pickle` implement such detection for **one** runtime. Portable message formats often **forbid** cycles. Alternatively, they require the application to replace cycles with explicit identifiers, for example integer keys into a table of nodes.

#### Contrast with an inline C structure

```c
struct Player {
    int32_t id;
    char name[4];   /* fixed inline storage: 'A','d','a','\0' — still not a general string model */
};
```

Here `id` and the four `name` bytes can sit **inside** one contiguous block, plus the padding rules from earlier sections. Even so, as soon as `name` becomes a `char *` pointer to a heap buffer, the C picture becomes a small graph as well. The structure holds an address, and the characters live elsewhere.

| Approach | What is stored for a string field | Portable as a raw dump? |
|----------|-----------------------------------|-------------------------|
| Inline fixed array in C | Character bytes inside the structure | Only if size, order, and character encoding are agreed |
| Managed object / `char *` | Reference (address or handle) to data elsewhere | **No** — addresses are process-local |
| JSON / MessagePack / schema codec | Length or delimiters plus character bytes (or field numbers plus values) | **Yes**, under that format’s rules |
| Language-native graph serializer (`pickle`, Java serialization, and similar) | Runtime type tags, handles, and payload for **that** virtual machine | Only within the **same** language/runtime family; unsafe on untrusted input |

Language-native serializers walk graphs for **one** runtime. Portable formats ordinarily flatten data to **trees or tables of values**. Numbers, character data for strings, and nested records are examples. They never mean “here is a heap address from this virtual machine.”

---

## Costs and constraints

The table below summarizes how layout and format choices affect different design axes. “What usually stays true” is the constraint you cannot wish away.

| Axis | What changes with layout and format choices | What usually stays true |
|------|---------------------------------------------|-------------------------|
| Processor time | Byte swaps or copies when host endianness differs from the wire; scanning padding versus dense packing | You still need *some* layout rule |
| Memory / allocations | Dense packed buffers versus pointer-rich graphs | There is no free solution that ignores portability |
| Size / bandwidth | Padding wastes bytes; pointers become identifiers or nested payloads | Raw `sizeof` dumps are not free portability |
| Operability | Hexadecimal dumps of packed formats need a decoder to understand | Informal dumps can look simple in a single-host debugger |
| Security / trust | Accepting raw native images from untrusted parties is hazardous | — |

---

## Illustrative scenario

A game client on a little-endian laptop writes player state with an uninterpreted copy of a packed C structure and uploads it to a backend. The backend may use a different compiler or CPU convention for field layout. It may use a managed language that stores fields in an entirely different way for **garbage collection**. Garbage collection (GC) is automatic reclamation of unused memory. Inventory counts become incorrect. The defect looks like application logic until someone compares the byte sequences with an endian-aware viewer.

A durable remedy is not an informal document describing structure packing. It is an explicit format shared by both ends. Even a simple length-prefixed little-endian layout can work. A schema-driven codec can work as well.

---

## In this suite

The benchmark runner measures **codecs**, not raw structure dumps. Each registered serializer implements a defined encode and decode path over the same logical fixtures. That choice is deliberate. Portable interchange is the subject of multi-language comparison.

**Results** therefore reflect the cost of *those* contracts. JSON text, MessagePack tags, Protocol Buffers field encodings, and similar mechanisms are what you measure. An uninterpreted memory-copy baseline is not. For family groupings, see [Serialization categories](../../analysis/serialization_categories.md).

---

## Common errors of practice

- Treating `sizeof` together with an uninterpreted binary write as if that combination were a multi-language interface.
- Forgetting that **padding and field order** are decisions of the compiler and platform. They are not merely part of how you picture the domain object in your head.
- Assuming that because little-endian hosts are common, endianness no longer matters. **Embedded systems, network equipment, and file formats** still need a written rule.
- Confusing **host layout** with **zero-copy wire layout**. The latter is designed, versioned, and free of host pointers into another process’s heap.
- Transmitting language-native serializations of object graphs across a trust boundary. See security notes in the [engineering perspective](../101/engineer_perspective.md).

---

## Key takeaways

- In-memory layout optimizes for one processor and runtime. The wire optimizes for a shared contract.
- Padding, field order, pointer representation, and endianness all prevent uninterpreted dumps from working as interchange.
- Portable formats replace host assumptions with explicit sizes, order, and byte order. Alternatively, they use self-describing tags.
- Zero-copy formats still define a layout. They make that layout readable in place instead of rebuilding a full object graph.
- Multi-language systems need an agreed encoding, not merely a shared C header file.
- Measure real codecs on representative payloads. A local memory-copy microbenchmark is not an interchange strategy.

---
