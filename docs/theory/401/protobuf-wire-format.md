# 4.1 Protocol Buffers Wire Format

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/401/wire_format_playground.ipynb)

## Problem Statement

Abstract descriptions such as *"binary encoding with integer field numbers"* explain why Protocol Buffers is compact (see [2.4 Self-describing vs. schema-dependent](../201/self-describing-vs-schema-dependent.md) and [2.5 Schema evolution](../201/schema-evolution.md)), but they do not enable an engineer to decode a raw network capture like `08 01 12 03 41 64 61`, diagnose wire-level corruption, or implement a compliant parser.

This lecture specifies the proto3 binary wire grammar[^1] down to individual bits, introduces the four-field teaching message `MiniUser`, and formalizes the unknown-field skip loop and codec-level bounds checks.

---

## Wire Grammar: Tagged Field Stream

!!! note "Definition: Protobuf Binary Message"
    A Protocol Buffers binary message is a concatenation of **tagged fields** `[key][payload]`, with no message header or field names on the wire. Each **key** (or **tag**) is an unsigned base-128 varint packing a field number $f \ge 1$ and a 3-bit wire type $w \in \{0, 1, 2, 5\}$:
    $$\text{key} = (f \ll 3) \mid w \qquad\Longleftrightarrow\qquad f = \text{key} \gg 3,\quad w = \text{key} \mathbin{\&} 7$$

Because the wire type $w$ occupies 3 bits, a reader that has never seen field number $f$ still knows exactly how many bytes to consume to skip it:

| Wire Type ($w$) | Name | Payload Layout | Schema Types |
|---:|---|---|---|
| `0` | `VARINT` | Unsigned base-128 variable-length integer (1–10 bytes) | `int32`, `int64`, `uint32`, `uint64`, `sint32`, `sint64`, `bool`, `enum` |
| `1` | `I64` | Exactly 8 bytes, little-endian | `fixed64`, `sfixed64`, `double` |
| `2` | `LEN` | Unsigned varint byte length $n$, followed by exactly $n$ bytes | `string`, `bytes`, embedded messages, packed repeated scalars |
| `5` | `I32` | Exactly 4 bytes, little-endian | `fixed32`, `sfixed32`, `float` |

*(Wire types `3` and `4` are deprecated proto2 start/end group delimiters and should not be used in new schemas.)*

### Tag Byte Cost and Field Numbering

Because the key is itself encoded as a base-128 varint (7 payload bits per byte), field numbers $1 \le f \le 15$ fit into 4 bits alongside the 3-bit wire type and encode in **1 byte**. Field numbers $16 \le f \le 2047$ require **2 bytes**:

| Field ($f$) | Wire Type ($w$) | Key Value $(f \ll 3) \mid w$ | Wire Hex |
|---:|---|---:|---|
| `1` | `VARINT` (`0`) | `8` | `08` |
| `2` | `LEN` (`2`) | `18` | `12` |
| `16` | `VARINT` (`0`) | `128` | `80 01` |
| `16` | `LEN` (`2`) | `130` | `82 01` |

For this reason, production `.proto` schemas reserve field numbers `1`–`15` for frequently populated fields.

### Teaching Schema: `MiniUser`

Throughout Part IV, byte-level walkthroughs use the four-field schema `MiniUser` (distinct from the suite's full `schemas/v2/protobuf/benchmark_v2.proto`):

```protobuf
syntax = "proto3";
message MiniUser {
  uint32 id = 1;            // VARINT (wire type 0)
  string name = 2;          // LEN UTF-8 (wire type 2)
  MiniUser manager = 3;     // LEN nested message (wire type 2)
  repeated uint32 tags = 4; // repeated VARINT (unpacked in Lab 4.2)
}
```

---

## Base-128 Varints and Signed Integers

An unsigned base-128 **varint** splits an integer into 7-bit groups, emitted **least-significant group first**. Bit 7 (`0x80`, the continuation bit) is `1` on every byte except the final byte, where it is `0`.

![Varint bit layout for decimal 300](../assets/diagrams/401-varint.svg#only-light)
![Varint bit layout for decimal 300](../assets/diagrams/401-varint-dark.svg#only-dark)

| Decimal | Binary (7-bit groups, LSB first) | Wire Hex |
|---:|---|---|
| `1` | `0000001` | `01` |
| `127` | `1111111` | `7f` |
| `128` | `0000000` (cont), `0000001` | `80 01` |
| `300` | `0101100` (cont), `0000010` | `ac 02` |

### Two's Complement vs. ZigZag Signed Encoding

- **`int32` / `int64`:** Encoded as standard unsigned varints of their 64-bit two's-complement representation. Consequently, `-1` sets all 64 bits and occupies **10 bytes** (`ff ff ff ff ff ff ff ff ff 01`).
- **`sint32` / `sint64`:** Apply **ZigZag encoding** before varint serialization, mapping signed integers bijectively onto unsigned integers ($0 \mapsto 0,\ -1 \mapsto 1,\ 1 \mapsto 2,\ -2 \mapsto 3,\ \dots$):
  $$\text{zz}_{32}(n) = (n \ll 1) \oplus (n \gg 31), \qquad \text{zz}_{64}(n) = (n \ll 1) \oplus (n \gg 63)$$
  (with arithmetic right shift). Small negative values then encode in 1 byte.
- **`bool` / `enum`:** Encoded as unsigned varints (`false` = `0`, `true` = `1`; enums use their numeric tag). In proto3, singular scalars holding their default value (`0`, `false`, `""`) are omitted on the wire.

### Codec-Level Bounds Invariants

While deployment-level parser defense belongs to [3.2 Untrusted input](../301/untrusted-input.md), every wire decoder must enforce four structural invariants locally:

1. **Truncated varint:** Reject EOF encountered while the continuation bit `0x80` is still set.
2. **Maximum varint length:** Cap varints at **10 bytes** (sufficient for 64-bit integers: $\lceil 64/7 \rceil = 10$); unbounded continuation bytes allow CPU DoS loops.
3. **Truncated fixed or `LEN` payload:** Verify `remaining >= 4` (`I32`), `remaining >= 8` (`I64`), and `remaining >= n` (`LEN`) before slicing—checking for integer overflow on `offset + n`.
4. **Recursion depth cap:** Bound nested `LEN` message recursion to prevent stack exhaustion on hostile input.

---

## Length-Delimited Frames, Nesting, and Repeated Fields

Every `LEN` field (`wire_type = 2`) appears on the wire strictly in the order `[key][length_varint][payload_bytes]`. Because the length precedes the payload, encoders either compute the byte size in a dry-run pass (as in `prost` and `protobuf-c`) or stage the payload in a temporary buffer before emitting the frame.

### Embedded Messages

A nested message uses no special wire type: it is a `LEN` field whose payload is itself a valid serialized message.

![Annotated MiniUser nested wire strip](../assets/diagrams/401-miniuser-wire.svg#only-light)
![Annotated MiniUser nested wire strip](../assets/diagrams/401-miniuser-wire-dark.svg#only-dark)

For `MiniUser { manager = { id = 2 } }`:

```text
1a       02       08       02
^^       ^^       ^^       ^^
│        │        │        └─ inner value = 2 (varint)
│        │        └─ inner key = (1 << 3) | 0 = 0x08 (field 1, VARINT)
│        └─ inner message byte length = 2
└─ outer key = (3 << 3) | 2 = 0x1a (field 3, LEN)
```

### Unpacked vs. Packed Repeated Fields

Repeated numeric fields support two encodings (compliant proto3 decoders accept **both**):

- **Unpacked** (used in Lab 4.2): One full `[key][value]` per element. For `tags = [1, 2]` (field 4, `VARINT`, key `(4 << 3) | 0 = 0x20`):
  `20 01 20 02` (4 bytes).
- **Packed** (default for modern proto3 emitters): One `LEN` frame (field 4, `LEN`, key `(4 << 3) | 2 = 0x22`) containing concatenated element varints without per-element tags:
  `22 02 01 02` (4 bytes here; saves $(k - 1)$ tag bytes for $k$ elements).

---

## Generic Decode Loop and Worked Traces

```text
while offset < len(buf):
    key, offset = read_varint(buf, offset)      # enforces 10-byte cap & EOF check
    field_number = key >> 3
    wire_type    = key & 0x07
    match wire_type:
        0: val, offset   = read_varint(buf, offset)
        1: bytes, offset = require_bytes(buf, offset, 8)
        2: n, offset     = read_varint(buf, offset)
           bytes, offset = require_bytes(buf, offset, n)
        5: bytes, offset = require_bytes(buf, offset, 4)
        _: return DecodeError("invalid wire type")
    if field_number is known in schema:
        assign_or_merge(msg, field_number, value)
    # else: unknown field safely skipped
```

### Worked Example: Golden Vector G1

Encode `MiniUser { id = 1, name = "Ada" }`:

| Field | Computation | Wire Hex |
|---|---|---|
| `id = 1` | Key `(1 << 3) \| 0 = 8` (`0x08`); varint `1` (`0x01`) | `08 01` |
| `name = "Ada"` | Key `(2 << 3) \| 2 = 18` (`0x12`); length `3` (`0x03`); UTF-8 `"Ada"` (`41 64 61`) | `12 03 41 64 61` |
| **Concatenated wire message** | | **`08 01 12 03 41 64 61`** (7 bytes) |

Note that Protocol Buffers does **not** require a canonical field order on the wire: `12 03 41 64 61 08 01` decodes to the identical `MiniUser`.

---

## Exercises

1. **Hand-encode a message:** Encode `MiniUser { id = 300, name = "Hi", tags = [150] }` using **unpacked** repeated tags. Express the exact hexadecimal byte sequence and total length.

??? note "Solution"
    - Field 1 (`id = 300`): key `(1 << 3) | 0 = 0x08`; $300 = 0\text{b}10\_0101100 \to$ low 7 bits `0101100` with cont bit = `0xac`, high 7 bits `0000010` = `0x02` $\to$ `08 ac 02` (3 bytes).
    - Field 2 (`name = "Hi"`): key `(2 << 3) | 2 = 0x12`; length `0x02`; ASCII `'H'=0x48, 'i'=0x69` $\to$ `12 02 48 69` (4 bytes).
    - Field 4 (`tags = [150]`, unpacked): key `(4 << 3) | 0 = 0x20`; $150 = 128 + 22 \to$ low 7 bits `0x16 | 0x80 = 0x96`, high `0x01` $\to$ `20 96 01` (3 bytes).
    - **Total:** `08 ac 02 12 02 48 69 20 96 01` (**10 bytes**).

2. **Hand-decode with an unknown field:** Decode the hexadecimal stream `08 05 2d 01 00 00 00 12 01 58` against `MiniUser`. Identify the unknown field number, its wire type, and the resulting `MiniUser` fields.

??? note "Solution"
    - `08 05`: field 1, `VARINT` $\to$ `id = 5`.
    - `2d`: `0x2d = 45 = (5 << 3) | 5` $\to$ **unknown field 5**, wire type `5` (`I32`, 4 fixed bytes). Skip the next 4 bytes (`01 00 00 00`).
    - `12 01 58`: field 2, `LEN`, length 1, UTF-8 `0x58 = 'X'` $\to$ `name = "X"`.
    - **Result:** `MiniUser { id = 5, name = "X", manager = None, tags = [] }`.

3. **ZigZag vs. `int32`:** Compute the encoded varint byte lengths of `-2` as a proto3 `int32` versus `sint32`.

??? note "Solution"
    - **`int32`:** Two's-complement 64-bit `-2` is `0xfffffffffffffffe`, which requires **10 bytes** (`fe ff ff ff ff ff ff ff ff 01`).
    - **`sint32`:** ZigZag maps `-2` via `(-2 << 1) ^ (-2 >> 31) = (-4) ^ (-1) = 3`, which encodes in **1 byte** (`03`).

---

## References

[^1]: Google Protocol Buffers Documentation. *Encoding (Binary Wire Format Specification)*. <https://protobuf.dev/programming-guides/encoding/>
