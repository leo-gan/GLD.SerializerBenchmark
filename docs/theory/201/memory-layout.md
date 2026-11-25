# 2.1 Memory Layout

## Problem Statement

Writing a process's in-memory `struct` or object buffer directly to a file or network socket appears attractive: it requires no schema compiler, no encoder library, and minimal local CPU work. Yet when a second process reads those raw bytes—especially on a different CPU architecture, compiler, or programming language—it routinely decodes wrong numbers, dereferences invalid addresses, or crashes.

Serialization exists because **in-memory layout is a local compiler and runtime optimization, not a portable contract between processes**. Compilers insert alignment padding, CPUs differ in multi-byte integer order (*endianness*), and managed runtimes store composite objects as graphs of process-local heap pointers rather than flat contiguous byte arrays.

---

## Addressable Host Values

Main memory is modeled as a linear array of addressable 8-bit **bytes** (octets), each holding a value in $[0, 255]$. Variables occupy either inline bytes at their address or a pointer/reference to heap storage elsewhere:

| Value Kind (typical 64-bit desktop/server) | Local Width | What Sits at the Variable's Address |
|---|---|---|
| Unsigned 8-bit integer (`uint8_t`) | 1 byte | The integer itself ($0\text{–}255$) |
| 32-bit / 64-bit integer (`int32_t`, `int64_t`) | 4 or 8 bytes | Binary integer bytes ordered by host endianness |
| 32-bit / 64-bit IEEE 754 float (`float`, `double`) | 4 or 8 bytes | Sign, exponent, and significand bit pattern—not ASCII decimal text |
| Fixed byte array (`uint8_t[3]`) | 3 bytes | Contiguous bytes (trailing padding may follow in a `struct`) |
| C string pointer (`char *`) | 8 bytes (pointer width) | A **virtual memory address** pointing to characters elsewhere in RAM |
| Managed string / record (Python, Java, C#, JS) | Reference width | A runtime handle to a heap object carrying type headers, length, and further references |

*(Values narrower than one byte and wide hardware transfer units such as 64-byte cache lines are separate concepts; see [2.2 Bit width is not bus width](bit-width-and-bus-width.md).)*

Copying a `char *` or managed object reference transmits an address valid only inside the sender's virtual address space. A portable encoding must emit the actual character bytes (with explicit length or delimiter rules) rather than a memory address.

---

## Field Ordering, Alignment, and Padding

!!! note "Definition: Alignment and Padding"
    A type has **alignment** $a$ if the CPU loads or stores it most efficiently (or strictly requires it) at addresses divisible by $a$. To satisfy field alignments inside a composite `struct`, compilers insert unused **padding** bytes between fields and at the end of the structure.

On common 64-bit ABIs (such as System V AMD64), 1-byte fields align to any address, 4-byte integers align to multiples of 4, and 8-byte integers or pointers align to multiples of 8.[^1] Consider a logical record with `flag` (1 byte), `id` (4 bytes), and `score` (8 bytes):

```c
struct PlayerA { uint8_t flag; int32_t id; int64_t score; }; // 1 + 3 pad + 4 + 8 = 16 bytes
struct PlayerB { int64_t score; int32_t id; uint8_t flag; }; // 8 + 4 + 1 + 3 tail pad = 16 bytes
```

![In-memory layout with padding: flag, pad, id, score](../assets/diagrams/201-memory-padding.svg#only-light)
![In-memory layout with padding: flag, pad, id, score](../assets/diagrams/201-memory-padding-dark.svg#only-dark)

Both structures occupy 16 bytes even though only 13 bytes carry domain data, and their field offsets differ completely. Even for identical declaration order, different compilers, target architectures, or `#pragma pack` directives alter padding. Uninitialized padding bytes can also leak unrelated stack or heap memory onto the wire.

### Byte-Level Example (Little-Endian Host)

For `PlayerA { flag = 1, id = 42, score = 7 }` on a little-endian host (`42` $= \text{0x2a}$, `7` $= \text{0x07}$):

```text
offset  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15
byte    01 00 00 00 2a 00 00 00 07 00 00 00 00 00 00 00
field   F  p  p  p  I  I  I  I  S  S  S  S  S  S  S  S
```

Here `F` is `flag` (offset 0), `p` denotes 3 padding bytes (offsets 1–3), `I` is little-endian `id` (`2a 00 00 00` at offsets 4–7), and `S` is little-endian `score` (`07 00 ... 00` at offsets 8–15). A compact portable binary contract would omit the 3 padding bytes and specify exact widths and byte order (13 bytes total), or use self-describing tags / schema field numbers.

---

## Endianness (Byte Order)

!!! note "Definition: Big-Endian vs. Little-Endian"
    For a multi-byte scalar occupying consecutive addresses:
    - **Big-endian (BE)** stores the *most significant byte* at the lowest address (conventional **network byte order** in IP/TCP headers and XDR).[^2][^3]
    - **Little-endian (LE)** stores the *least significant byte* at the lowest address (dominant on x86-64 and most modern ARM deployments, and used by Protocol Buffers fixed types and FlatBuffers).

For the 32-bit integer `0x12345678` ($305\,419\,896_{10}$):

![Endianness: big-endian vs little-endian byte order for 0x12345678](../assets/diagrams/201-endianness.svg#only-light)
![Endianness: big-endian vs little-endian byte order for 0x12345678](../assets/diagrams/201-endianness-dark.svg#only-dark)

If a little-endian writer emits `78 56 34 12` and a big-endian reader interprets those bytes without byte-swapping, it reads `0x78563412` ($2\,018\,915\,346_{10}$). IEEE 754 floating-point values are subject to the same byte-order contract. Every binary wire specification must declare byte order explicitly; text formats such as JSON sidestep host byte order by encoding numbers as decimal character strings.

**Zero-copy formats are still explicit contracts:** Layouts such as FlatBuffers and Cap'n Proto resemble memory images so fields can be read in place, yet they define strict portable alignment, explicit little-endian byte order, and **buffer-relative offsets**—never raw host pointers ([2.7 Zero-copy layouts](zero-copy.md)).

---

## Managed Objects, Shared References, and Cycles

In C, `struct PlayerA` stores scalar fields inline. In managed languages (Python, Java, C#, JavaScript), a logical record `{"id": 42, "name": "Ada"}` is a **heap graph** of references:

```text
  player ──ref──► Map object @ 0xA100
                    ├─ "id"   ──ref──► Int(42)       @ 0xB200
                    └─ "name" ──ref──► String("Ada") @ 0xC300
```

Serializing graphs exposes two structural cases that raw memory dumps cannot resolve:

1. **Shared references (DAGs):** Two records referencing the same string or node object in memory. Tree-oriented portable formats (JSON, Protocol Buffers) duplicate the value on the wire; graph-aware serializers (such as `pickle` or non-packed Dagr) record back-references or arena indices to preserve sharing.
2. **Reference cycles:** Object `a` references `b` and `b` references `a`. A naive recursive walk never terminates without cycle detection (visited-set tracking). Most portable message formats forbid cycles and require replacing cyclic pointers with explicit integer or string node identifiers.

| Representation | String / Reference Storage | Portable as Raw Dump? |
|---|---|---|
| Inline fixed C array (`char name[4]`) | Bytes inline inside `struct` | Only with identical compiler, ABI, width, and encoding |
| C pointer (`char *`) or managed heap object | Process-local virtual address / runtime handle | **No** — addresses are meaningless outside the process |
| Portable wire format (JSON, MessagePack, Protobuf) | Explicit length prefix or delimiter + UTF-8 bytes | **Yes**, under the standard's rules |
| Language-native graph serializer (`pickle`, Java) | Runtime type descriptors, opcodes, and back-references | Same runtime only; unsafe across trust boundaries |

---

## Connection to the Benchmark Suite

Every language benchmark runner in this suite times explicit portable or runtime codecs—never raw `memcpy` or `@bitCast` memory dumps—over shared logical data types ([Data sets](../../analysis/test_data_configuration.md)). Codecs that support shared nodes and reference cycles are evaluated separately on the `graph` data set ([Graph](../../analysis/graph.md)). Published timings live on the [Dashboard](../../dashboard/index.html).

---

## Exercises

1. **Struct padding calculation:** On a standard 64-bit little-endian ABI (1-byte, 2-byte, 4-byte, and 8-byte natural alignments), compute the byte offsets and total `sizeof` for:
   ```c
   struct Reading { uint8_t kind; double value; uint16_t flags; };
   ```
   How much memory is saved simply by reordering fields from largest to smallest alignment?

??? note "Solution"
    - Original order: `kind` at offset 0 (1 B), 7 bytes padding (offsets 1–7), `value` at offset 8 (8 B), `flags` at offset 16 (2 B), 6 bytes tail padding to round total size to a multiple of 8 → **`sizeof = 24` bytes** (13 bytes padding).
    - Largest-to-smallest (`double value; uint16_t flags; uint8_t kind;`): `value` at 0 (8 B), `flags` at 8 (2 B), `kind` at 10 (1 B), 5 bytes tail padding → **`sizeof = 16` bytes** (saves 8 bytes per instance, still 5 bytes larger than the 11-byte packed payload).

2. **Endianness decoding:** A big-endian protocol transmits the 4-byte unsigned integer `00 00 01 00`. What decimal value did the writer send? What decimal value would a buggy little-endian reader obtain if it loaded those four bytes without swapping?

??? note "Solution"
    - Writer's big-endian value: $0\times 2^{24} + 0\times 2^{16} + 1\times 2^8 + 0 = 256$.
    - Unswapped little-endian read: $0 + 0\times 2^8 + 1\times 2^{16} + 0\times 2^{24} = 65\,536$.

3. **Cycle handling:** Explain why `json.dumps(a)` raises `ValueError: Circular reference detected` when `a = {}; a["self"] = a`, and describe how you would represent a cyclic social graph cleanly in JSON or Protocol Buffers.

??? note "Solution"
    JSON encodes finite trees (JSON objects and arrays have no wire syntax for object references or back-pointers), so a cycle would produce an infinite string. To represent a cyclic graph in JSON or Protocol Buffers, flatten it into a table of nodes with unique IDs (`nodes: [{id, ...}]`) and represent edges as ID references (`edges: [{from_id, to_id}]`).

---

## References

[^1]: Bryant, R. E., & O'Hallaron, D. R. (2015). *Computer Systems: A Programmer's Perspective* (3rd ed.), Chapter 3 (§3.9 Alignment) and Chapter 2 (§2.1 Byte Ordering). Pearson.
[^2]: Cohen, D. (1980). "On Holy Wars and a Plea for Peace." *IEEE Computer*, 14(10), 48–54.
[^3]: Eisler, M. (Ed.). (2006). *XDR: External Data Representation Standard*. IETF RFC 4506. <https://www.rfc-editor.org/rfc/rfc4506>
