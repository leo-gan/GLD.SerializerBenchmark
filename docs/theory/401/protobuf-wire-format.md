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
- Optional: skim shared suite schema `schemas/benchmark_data.proto` for real field numbers (this page uses a **teaching mini-message**).

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

**Teaching mini-message** (not the full suite `Person`):

```protobuf
syntax = "proto3";
message MiniUser {
  uint32 id = 1;           // varint
  string name = 2;         // length-delimited UTF-8
  MiniUser manager = 3;    // length-delimited nested message (optional)
  repeated uint32 tags = 4; // repeated varint (unpacked)
}
```

## Step-by-step

### 1. Encode the key (tag)

```text
key = (field_number << 3) | wire_type
```

Example: field `1`, wire type VARINT (0) → key = `(1 << 3) | 0` = `8` = `0x08`.

Field `2`, LEN (2) → key = `(2 << 3) | 2` = `18` = `0x12`.

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

**bool:** `false` → often omitted in proto3 (default); `true` → tag + varint `01`.  
**enum:** encoded as varint of the numeric value.

### 3. Length-delimited (wire type 2)

1. Emit key with wire type 2.  
2. Encode payload bytes (UTF-8 string, raw bytes, or nested message encoding).  
3. Emit varint **length** of that payload, then the payload.

```text
  [ key ][ len ][ payload bytes… ]
```

### 4. Nested message

A nested message is **just another length-delimited blob** whose payload is itself a valid message encoding (concatenation of its fields). There is no special “nest” wire type.

### 5. Repeated fields (unpacked)

For `repeated uint32 tags = 4` (unpacked): emit **one complete field** (key + varint) **per element**. Same key may appear multiple times.

**Packed** repeated (proto3 default for primitive numeric repeated in many generators) uses a **single** length-delimited field whose payload is the concatenation of element encodings—out of mini-lab MVP unless you take the stretch goal.

### 6. Decode loop

```text
while bytes remain:
  key = read_varint()
  field_number = key >> 3
  wire_type    = key & 7
  switch wire_type:
    0: read_varint()
    1: read 8 bytes
    2: n = read_varint(); read n bytes
    5: read 4 bytes
    else: error or skip policy
  if field_number unknown: discard payload (skip)
  else: assign to schema field
```

Skipping unknown fields requires understanding the wire type so you consume the correct number of bytes—**do not** assume fixed sizes.

### 7. Worked example

Encode `MiniUser { id = 1, name = "Ada" }` (no manager, no tags).

| Step | Meaning | Bytes (hex) |
|------|---------|-------------|
| Field 1 | key `(1<<3)\|0` = 8 | `08` |
| | varint 1 | `01` |
| Field 2 | key `(2<<3)\|2` = 18 | `12` |
| | len = 3 | `03` |
| | UTF-8 `Ada` | `41 64 61` |

**Full message:** `08 01 12 03 41 64 61`

Verify with any official parser that loads an equivalent `.proto` (see [lab](lab-mini-protobuf-encoder.md)).

Nested example sketch: if `manager` is present with only `id = 2`, field 3 is key `0x1a`, length of inner message, then inner `08 02`.

## Buffers & ownership

Wire rules are **language-agnostic** — the encoding spec says nothing about who allocates or frees buffers. Ownership appears only when a runtime materializes the result: Python creates an immutable `bytes`, Rust fills a `Vec<u8>`, C writes into a caller-allocated `uint8_t[]`. Each language path article covers its ownership model; the wire format itself is pure data layout.

## In this suite

| Asset | Role |
|-------|------|
| `schemas/benchmark_data.proto` | Real multi-message schema (Person, Telemetry, …)—larger than MiniUser |
| [Python](protobuf-python.md) / [Rust](protobuf-rust-prost.md) / [C](protobuf-c-protobuf-c.md) | Language runtime implementations of **this** wire format |
| [301 using this suite](../301/using-this-suite.md) | How not to misuse Results when comparing libs |

## Common mistakes

- Putting field **names** on the wire (that is not classic Protobuf binary).  
- Reusing field numbers after deletion without `reserved`.  
- Forgetting length prefix on strings.  
- Treating message field order as semantically required (encoders may differ; decoders must accept any order).  
- Decoding without a skip path for unknown tags.

## What this article is not

- A full proto3 language guide (maps, oneofs, extensions, editions, JSON mapping).  
- gRPC framing (length-prefixed HTTP/2 messages **wrap** Protobuf payloads).  
- A security manual—see [301 untrusted input](../301/untrusted-input.md) for hostile payloads.

## Key takeaways

- Protobuf binary = **tagged fields**; key = `(number << 3) | wire_type`.  
- Payloads are varint, fixed 32/64, or length-delimited.  
- Nested messages are length-delimited messages; repeated unpacked = repeated tags.  
- Unknown fields are skipped by wire type—foundation of evolution.  
- Next: language paths apply these bytes via codegen runtimes; the lab builds a subset by hand.
