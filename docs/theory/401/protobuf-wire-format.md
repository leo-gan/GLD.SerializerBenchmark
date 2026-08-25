# Protobuf wire format step-by-step

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/401/wire_format_playground.ipynb)
**Lab notebook:** [wire format playground](../notebooks/401/wire_format_playground.ipynb) · full MiniUser lab: [lab_mini_protobuf_encoder.ipynb](../notebooks/401/lab_mini_protobuf_encoder.ipynb)

## Why this article exists

Imagine you open a network capture. You see a short sequence of bytes such as `08 01 12 03 41 64 61`. Someone tells you “that is Protocol Buffers.” The slogan “binary with field numbers” does not by itself teach you how to **read or write those bytes**. It does not teach you how to debug a hexadecimal dump. It does not teach you how to implement even a small subset codec.

Without the wire rules, language tutorials stay at the API surface. Serialization 201 taught that Protocol Buffers is **schema-dependent**. That means the reader needs a schema, not just the bytes. Until you learn the wire rules, that idea never becomes something you can operate on yourself.

In this article you will learn the binary layout that Protocol Buffers uses on the wire. After reading it, you should be able to encode and decode a small teaching message by hand. You should also understand why unknown fields can be skipped safely.

This article assumes the 201 ideas in [self-describing vs schema](../201/self-describing-vs-schema-dependent.md) and [schema evolution](../201/schema-evolution.md).

Official encoding reference: [Protocol Buffers encoding](https://protobuf.dev/programming-guides/encoding/).

## Short answer

Protocol Buffers (proto3 binary encoding) store a message as a **list of fields**, one after another. Each field starts with a small integer called a **tag** (also called a **key**). The tag combines two pieces of information: which field this is (the **field number**) and how the following bytes are shaped (the **wire type**). After the tag comes a **payload**. The shape of the payload depends on the wire type. The payload may be a **varint** (a variable-length integer), a fixed 32-bit or 64-bit value, or a **length-delimited** blob (often abbreviated **LEN**). Length-delimited fields are used for strings, raw bytes, nested messages, and packed repeated numbers.

Field **names never appear** on the wire. A reader needs the schema—or equivalent knowledge of field numbers and types—to turn those numbers back into meaningful fields. Unknown field numbers are usually **skipped**. The decoder looks at the wire type and consumes the right number of bytes. That skip rule is why additive schema evolution works, as long as field numbers are never reused for a different meaning.

## Prerequisites

- Comfort with hexadecimal notation and unsigned integers.
- 201 vocabulary: schema-dependent wire formats and additive field numbers.
- Optional: skim the suite schema `schemas/v2/protobuf/benchmark_v2.proto` for realistic field numbers. This page uses a **teaching mini-message**, not a full suite fixture.

## Mental model

A message is a sequence of **fields**. Each field looks like this on the wire:

```
[key varint] [payload...]
```

The key is computed as:

```text
key = (field_number << 3) | wire_type
```

In plain language: shift the field number three bits left, then put the wire-type code in the low three bits. That integer is itself written as a varint. Varints are explained below.

| Wire type | Value | Payload |
|-----------|------:|---------|
| VARINT | 0 | unsigned varint (variable-length integer) |
| I64    | 1 | exactly 8 bytes, little-endian |
| LEN    | 2 | a length (as a varint) `n`, then exactly `n` bytes |
| I32    | 5 | exactly 4 bytes, little-endian |

**Endianness** means the order of bytes in multi-byte fixed values. Protocol Buffers fixed types use **little-endian** order. The least significant byte comes first.

Example tag strip for `id = 1` (field 1, varint payload):

```
08 01
^^ ^^
|  value = 1
key = (1<<3) | 0
```

Nested message example (field 3 is a manager whose only content is `id = 2`):

![Annotated MiniUser nested wire strip](../assets/diagrams/401-miniuser-wire.svg#only-light)
![Annotated MiniUser nested wire strip](../assets/diagrams/401-miniuser-wire-dark.svg#only-dark)

```
1a       02       08       02
^^       ^^       ^^       ^^
|        |        |        value = 2 (varint)
|        |        inner key = (1<<3)|0 = 0x08 (field 1, VARINT)
|        length of inner message = 2 bytes
outer key = (3<<3)|2 = 0x1a (field 3, LEN)
```

Wire types 3 and 4 are legacy “group” markers. Avoid them in new designs.

**Teaching mini-message.** The following schema is not a full suite fixture. It is also not `schemas/v2/protobuf/benchmark_v2.proto`. We use it so hex dumps stay small enough to reason about by hand:

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

In this section we encode the tag that names each field on the wire.

```text
key = (field_number << 3) | wire_type
```

For example, field `1` with wire type VARINT (0) gives key = `(1 << 3) | 0` = `8` = `0x08`.

Field `2` with wire type LEN (2) gives key = `(2 << 3) | 2` = `18` = `0x12`.

The key is itself a **varint**. For field numbers **1–15**, a single-byte key is common. The low four bits of the field number fit beside the three-bit wire type. For field number **16 or higher**, the key needs more than one byte:

| Field | Wire type | key value | Hex (key only) |
|------:|----------:|----------:|----------------|
| 1 | VARINT (0) | 8 | `08` |
| 16 | VARINT (0) | 128 | `80 01` |
| 16 | LEN (2) | 130 | `82 01` |

This matters because large field numbers cost an extra byte on every occurrence of that field. Many schemas keep hot fields in the range 1–15 for that reason.

### 2. Encode a varint (unsigned base-128)

A **varint** (variable-length integer) stores an unsigned integer in base-128 groups. Each byte carries seven data bits. The high bit of a byte means “more bytes follow.” Small numbers use one byte. Large numbers use more. That is why Protocol Buffers is efficient for small integers. It does not fix every integer at four or eight bytes.

![Varint bit layout for decimal 300](../assets/diagrams/401-varint.svg#only-light)
![Varint bit layout for decimal 300](../assets/diagrams/401-varint-dark.svg#only-dark)

**Algorithm:**

1. While the value is at least 128: emit `(value & 0x7f) | 0x80`, then shift the value right by seven bits.
2. Finally emit the last seven-bit group with the high bit cleared.

| Decimal | Hex bytes (illustrative) |
|--------:|--------------------------|
| 1 | `01` |
| 127 | `7f` |
| 128 | `80 01` |
| 300 | `ac 02` |

Signed **int32** / **int64** in proto3 use ordinary varints of their two’s-complement bit pattern. Negative values therefore expand to many bytes. **sint32** / **sint64** use **zigzag** encoding so that small negatives become small varints. Zigzag is a mapping that interleaves non-negative and negative integers (0, −1, 1, −2, 2, …). Values near zero stay near zero on the wire. This course’s mini subset avoids `sint` unless you extend the lab yourself.

| Type | Logical −1 (illustrative) | Idea |
|------|---------------------------|------|
| `int32` / `int64` | many `ff` bytes as the unsigned varint of two’s complement | Expensive when negatives are common |
| `sint32` / `sint64` | zigzag maps −1 to a small varint (for example `01`) | Prefer when negatives are common |

**bool:** `false` is often omitted in proto3 because it is the default. `true` is a tag plus the varint `01`.  
**enum:** encoded as the varint of the numeric enum value.

#### Varint failure modes (codec concerns)

A correct decoder must not assume that “integers are small.” It must also not assume that “the buffer is well-formed.” Every read must check that enough input remains:

| Failure | What goes wrong |
|---------|-----------------|
| **Truncated mid-varint** | The high bit is set on the last available byte, so more input is required but the stream ended |
| **Overlong encoding** | A value that fits in fewer bytes is written with extra continuation bytes; reject it or define a clear policy |
| **Too many continuation bytes** | Cap the length (for example ten bytes for a 64-bit value); otherwise a hostile stream of `0x80` bytes can become a denial-of-service |
| **Truncated fixed or LEN** | Not enough bytes remain for 4/8 fixed bytes, or for `n` payload bytes after a length prefix |

Hostile payloads as an operational problem are covered in [301 untrusted input](../301/untrusted-input.md). Bounds checks still belong inside the decoder itself.

### 3. Length-delimited fields (wire type 2, often called LEN)

In this section we look at fields whose payload size is not fixed in advance. Strings, byte arrays, nested messages, and packed repeated numbers all use wire type 2.

**On the wire** a length-delimited field is always:

```text
  [ key ][ len ][ payload bytes… ]
```

**When encoding**, you usually stage the payload first so you know `len` before you write it:

1. Build the payload bytes (UTF-8 for a string, raw bytes, or a nested message encoding) in a temporary buffer.
2. Emit the key with wire type 2.
3. Emit the **length** of that payload as a varint.
4. Emit the payload bytes.

Do not emit the length *after* the payload on the wire. Staging the payload in memory first is fine. The on-wire order is always key, then length, then payload.

### 4. Nested message

A nested message is **just another length-delimited blob**. Its payload is itself a valid message encoding—the concatenation of that nested message’s fields. There is no special “nest” wire type. This matters because the same decode loop that handles strings also handles submessages. You read a length, then parse that slice as a message.

### 5. Repeated fields

A **repeated** field is a list of values of the same type. Protocol Buffers has two common ways to encode repeated numbers.

**Unpacked** (the lab default): for `repeated uint32 tags = 4`, emit **one complete field** (key plus varint value) **per element**. The same key may appear multiple times in one message.

Example for `tags = [1, 2]` only:

```
20 01 20 02
^^ ^^ ^^ ^^
|  |  |  value 2
|  |  key for field 4, VARINT, again
|  value 1
key (4<<3)|0 = 0x20
```

**Packed** (the proto3 default that many code generators use for primitive numeric repeated fields): a **single** length-delimited field whose payload is the concatenation of element encodings. There are no per-element tags inside the packed block.

Example for the same logical `tags = [1, 2]` as packed (field 4, LEN):

```
22       02       01 02
^^       ^^       ^^^^^
|        |        two varints: 1, 2
|        length of packed payload = 2
key (4<<3)|2 = 0x22
```

Decoders should accept **both** forms for the same field when the schema says `repeated` numeric. The [lab](lab-mini-protobuf-encoder.md) implements unpacked only. Packed is a stretch goal.

### 6. Decode loop

When you decode, you walk the buffer from left to right until nothing remains. For each field you read a key. You split it into field number and wire type. Then you consume the payload that matches that wire type.

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

Skipping unknown fields requires understanding the wire type so you consume the correct number of bytes. **Do not** assume every unknown field has a fixed size. Always check that the buffer has enough remaining bytes before you read.

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

Verify these with any official parser that loads an equivalent `.proto` (see the [lab](lab-mini-protobuf-encoder.md)).

## In this suite

| Asset | Role |
|-------|------|
| `schemas/v2/protobuf/benchmark_v2.proto` | Real multi-message suite schema—much larger than MiniUser |
| [Python](protobuf-python.md) / [Rust](protobuf-rust-prost.md) / [C](protobuf-c-protobuf-c.md) | Language runtime implementations of **this** wire format |
| [301 using this suite](../301/using-this-suite.md) | How not to misuse Dashboard numbers when comparing libraries |

Wire layout is language-agnostic. Buffer ownership (who allocates and who frees) is covered in each language-path article.

## Common mistakes

- Putting field **names** on the wire (classic Protocol Buffers binary does not do that).
- Reusing field numbers after deletion without marking them `reserved`.
- Forgetting the length prefix on strings.
- Emitting the length after the payload on the wire (confusing staging order with wire order).
- Treating message field order as semantically required (encoders may differ; decoders must accept any order).
- Decoding without a skip path for unknown tags.
- Reading a LEN length `n` or a fixed width without checking remaining buffer length.

## What this article is not

- A full proto3 language guide (maps, oneofs, extensions, editions, JSON mapping).
- gRPC framing (length-prefixed HTTP/2 messages **wrap** Protocol Buffers payloads; they are not the payload itself).
- Buffer ownership per language (see the language-path articles).
- A security playbook—see [301 untrusted input](../301/untrusted-input.md) for hostile operational controls. The varint and LEN bounds above are the codec-side half of that story.

## Key takeaways

- Protocol Buffers binary is a stream of **tagged fields**. The key is `(number << 3) | wire_type`, written as a varint. Large field numbers need more than one key byte.
- Payloads are varints, fixed 32/64-bit values, or length-delimited blobs (`key | len | payload` on the wire).
- Nested messages are length-delimited messages. Unpacked repeated fields repeat tags. Packed repeated fields use one LEN of concatenated elements.
- Unknown fields are skipped by wire type. That rule is the foundation of additive evolution.
- Language-path articles show how code-generated runtimes apply these bytes. The lab builds a small subset by hand.
