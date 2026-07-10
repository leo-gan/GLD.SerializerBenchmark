# Protobuf wire format step-by-step

## Problem

Schema-driven formats are often described as “binary with field numbers.” That slogan does not teach you how to **read or emit bytes**, debug a hex dump, or implement a subset codec. Without the wire rules, language tutorials stay API-deep and 201’s “schema-dependent” concept never becomes operational.

## Short answer

Protocol Buffers (proto3 binary encoding) write a sequence of **keyed fields**. Each field is a **tag** (field number + wire type) followed by a **payload** whose shape depends on the wire type: varint, fixed 32/64-bit, or length-delimited (strings, bytes, embedded messages, packed repeated). Field **names do not appear** on the wire; readers need the schema (or equivalent) to interpret numbers. Unknown fields are typically **skipped** by field number, which is why additive evolution works when numbers are never reused.

Assumes 201: [self-describing vs schema](../201/self-describing-vs-schema-dependent.md), [schema evolution](../201/schema-evolution.md).

Official encoding reference: [Protocol Buffers encoding](https://protobuf.dev/programming-guides/encoding/).

## Prerequisites

- Comfort with hex and unsigned integers.  
- 201 vocabulary: schema-dependent wire, additive field numbers.  
- Optional: skim shared suite schema `schemas/v2/protobuf/benchmark_v2.proto` for real field numbers (this page uses a **teaching mini-message**, not a full suite fixture).

## Mental model

A message is a sequence of **fields**. Each field is:

```
[key varint] [payload...]
```

Where `key = (field_number << 3) | wire_type`.

| Wire type | Value | Payload |
|-----------|------:|---------|
| VARINT | 0 | unsigned varint |
| I64    | 1 | exactly 8 bytes, little-endian |
| LEN    | 2 | varint length `n` + `n` bytes |
| I32    | 5 | exactly 4 bytes, little-endian |

Example tag strip for `id = 1` (field 1, varint):

```
08 01
^^ ^^
|  value = 1
key = (1<<3) | 0
```

Nested message example (field 3 = manager with `id=2`):

```
1a       02       08       02
^^       ^^       ^^       ^^
|        |        |        value = 2 (varint)
|        |        inner key = (1<<3)|0 = 0x08 (field 1, VARINT)
|        length of inner message = 2 bytes
outer key = (3<<3)|2 = 0x1a (field 3, LEN)
```

(Wire types 3/4 are legacy group markers — avoid.)

**Teaching mini-message** (not a full suite fixture / `benchmark_data.proto`):

```protobuf
syntax = "proto3";
message MiniUser {
  uint32 id = 1;           // varint
  string name = 2;         // length-delimited UTF-8
  MiniUser manager = 3;    // length-delimited nested message (optional)
  repeated uint32 tags = 4; // repeated varint (unpacked in the lab)
}
```

## Step-by-step

### 1. Encode the key (tag)

```text
key = (field_number << 3) | wire_type
```

Example: field `1`, wire type VARINT (0) → key = `(1 << 3) | 0` = `8` = `0x08`.

Field `2`, LEN (2) → key = `(2 << 3) | 2` = `18` = `0x12`.

The key is itself a **varint**. For field numbers **1–15**, a single-byte key is common (the low 4 bits of the field number fit with the 3-bit wire type). For field number **≥ 16**, the key needs more than one byte:

| Field | Wire type | key value | Hex (key only) |
|------:|----------:|----------:|----------------|
| 1 | VARINT (0) | 8 | `08` |
| 16 | VARINT (0) | 128 | `80 01` |
| 16 | LEN (2) | 130 | `82 01` |

### 2. Encode a varint (unsigned base-128)

While value ≥ 128: emit `(value & 0x7f) | 0x80`, then `value >>= 7`.  
Finally emit the last 7-bit group with high bit clear.

| Decimal | Hex bytes (illustrative) |
|--------:|--------------------------|
| 1 | `01` |
| 127 | `7f` |
| 128 | `80 01` |
| 300 | `ac 02` |

Signed **int32/int64** in proto3 use ordinary varints of their two’s-complement bit pattern (large magnitudes for negatives). **sint32/sint64** use zigzag; this course’s mini subset avoids sint unless you extend the lab.

| Type | Logical −1 (illustrative) | Idea |
|------|---------------------------|------|
| `int32` / `int64` | many `ff` bytes as unsigned varint of two’s complement | Expensive for negatives |
| `sint32` / `sint64` | zigzag → small varint (e.g. `01` for −1) | Prefer when negatives are common |

**bool:** `false` → often omitted in proto3 (default); `true` → tag + varint `01`.  
**enum:** encoded as varint of the numeric value.

#### Varint failure modes (codec concerns)

A correct decoder must not assume “integers are small” or “the buffer is well-formed”:

| Failure | What goes wrong |
|---------|-----------------|
| **Truncated mid-varint** | High bit set on last available byte; need more input |
| **Overlong encoding** | Value that fits in fewer bytes encoded with extra continuation bytes; reject or define policy |
| **Too many continuation bytes** | Cap (e.g. 10 bytes for 64-bit); otherwise DoS via endless `0x80` stream |
| **Truncated fixed / LEN** | Not enough bytes for 4/8 or for `n` payload bytes after length |

Hostile payloads are an operational topic in [301 untrusted input](../301/untrusted-input.md); bounds belong in the decoder itself.

### 3. Length-delimited (wire type 2)

**On the wire** the field is always:

```text
  [ key ][ len ][ payload bytes… ]
```

**When encoding**, you usually stage the payload first so you know `len`:

1. Build payload bytes (UTF-8 string, raw bytes, or nested message encoding) in a temporary buffer.  
2. Emit key with wire type 2.  
3. Emit varint **length** of that payload.  
4. Emit the payload bytes.

Do not emit length *after* the payload on the wire—only after you have computed it.

### 4. Nested message

A nested message is **just another length-delimited blob** whose payload is itself a valid message encoding (concatenation of its fields). There is no special “nest” wire type.

### 5. Repeated fields

**Unpacked** (lab default): for `repeated uint32 tags = 4`, emit **one complete field** (key + varint) **per element**. Same key may appear multiple times.

Example `tags = [1, 2]` only:

```
20 01 20 02
^^ ^^ ^^ ^^
|  |  |  value 2
|  |  key field 4 VARINT again
|  value 1
key (4<<3)|0 = 0x20
```

**Packed** (proto3 default for many generators on primitive numeric repeated): a **single** length-delimited field whose payload is the concatenation of element encodings—no per-element tags inside.

Example same logical `tags = [1, 2]` as packed (field 4, LEN):

```
22       02       01 02
^^       ^^       ^^^^^
|        |        two varints: 1, 2
|        length of packed payload = 2
key (4<<3)|2 = 0x22
```

Decoders should accept **both** forms for the same field when the schema says `repeated` numeric. The [lab](lab-mini-protobuf-encoder.md) implements unpacked only; packed is a stretch goal.

### 6. Decode loop

```text
while bytes remain:
  key = read_varint()
  field_number = key >> 3
  wire_type    = key & 7
  switch wire_type:
    0: read_varint()
    1: read 8 bytes   # error if fewer remain
    2: n = read_varint(); read n bytes  # error if fewer remain
    5: read 4 bytes
    else: error or skip policy
  if field_number unknown: discard payload (skip)
  else: assign to schema field
```

Skipping unknown fields requires understanding the wire type so you consume the correct number of bytes—**do not** assume fixed sizes. Always check that the buffer has enough remaining bytes before reading.

### 7. Worked examples

#### G1 — `MiniUser { id = 1, name = "Ada" }` (no manager, no tags)

| Step | Meaning | Bytes (hex) |
|------|---------|-------------|
| Field 1 | key `(1<<3)\|0` = 8 | `08` |
| | varint 1 | `01` |
| Field 2 | key `(2<<3)\|2` = 18 | `12` |
| | len = 3 | `03` |
| | UTF-8 `Ada` | `41 64 61` |

**Full message:** `08 01 12 03 41 64 61`

#### G5 — nested `manager = { id = 2 }` only

| Step | Meaning | Bytes (hex) |
|------|---------|-------------|
| Outer field 3 | key `(3<<3)\|2` = 26 | `1a` |
| | length of inner message | `02` |
| Inner field 1 | key `(1<<3)\|0` = 8 | `08` |
| | varint 2 | `02` |

**Full message:** `1a 02 08 02`

Verify with any official parser that loads an equivalent `.proto` (see [lab](lab-mini-protobuf-encoder.md)).

## In this suite

| Asset | Role |
|-------|------|
| `schemas/v2/protobuf/benchmark_v2.proto` | Real multi-message suite schema—larger than MiniUser |
| [Python](protobuf-python.md) / [Rust](protobuf-rust-prost.md) / [C](protobuf-c-protobuf-c.md) | Language runtime implementations of **this** wire format |
| [301 using this suite](../301/using-this-suite.md) | How not to misuse Results when comparing libs |

Wire layout is language-agnostic; buffer ownership is covered in each language path article.

## Common mistakes

- Putting field **names** on the wire (that is not classic Protobuf binary).  
- Reusing field numbers after deletion without `reserved`.  
- Forgetting length prefix on strings.  
- Emitting length after payload on the wire (staging vs wire order).  
- Treating message field order as semantically required (encoders may differ; decoders must accept any order).  
- Decoding without a skip path for unknown tags.  
- Reading LEN/`n` or fixed widths without checking remaining buffer length.

## What this article is not

- A full proto3 language guide (maps, oneofs, extensions, editions, JSON mapping).  
- gRPC framing (length-prefixed HTTP/2 messages **wrap** Protobuf payloads).  
- Buffer ownership per language (see language path articles).  
- A security playbook—see [301 untrusted input](../301/untrusted-input.md) for hostile operational controls; varint/LEN bounds above are the codec side.

## Key takeaways

- Protobuf binary = **tagged fields**; key = `(number << 3) | wire_type` (key is a varint; large field numbers multi-byte).  
- Payloads are varint, fixed 32/64, or length-delimited (`key | len | payload` on the wire).  
- Nested messages are length-delimited messages; repeated unpacked = repeated tags; packed = one LEN of concatenated elements.  
- Unknown fields are skipped by wire type—foundation of evolution.  
- Language paths apply these bytes via codegen runtimes; the lab builds a subset by hand.
