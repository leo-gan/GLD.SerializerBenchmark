# Bit width is not bus width

## Problem

Two facts are easy to mix together.

Hardware moves many bytes at once. A cache line on a typical server processor is 64 bytes. An on-chip bus may move 4, 8, 16, 32, or 64 bytes in one transfer. A SIMD register is wide in the same sense. SIMD means single instruction, multiple data: one instruction operates on several values at once. Graphics processors also move memory in wide chunks. From that fact it is tempting to decide that a serializer should stop using bytes and should emit one field as wide as each bus transfer.

Some values need fewer than eight bits. A 12-bit sensor sample, a 4-bit weight, and an identifier that needs 17 bits each carry less information than the 8-bit, 32-bit, and 64-bit slots in the [memory layout](memory-layout.md) table. Storing each of them in a 16-bit or 64-bit integer spends bits the value does not need.

Both facts are about width. They answer different questions.

In this course a **byte** is eight bits. A few specialized processors use a wider character, so formal specifications say **octet** when they mean an eight-bit byte. This page says byte, and means eight bits.

---

## Short answer

Keep three widths separate.

| Width | What it measures | Examples |
|-------|------------------|----------|
| **Information width** | How many bits the value needs | A 12-bit sample, a 4-bit weight, a 17-bit identifier |
| **Addressable unit** | What a program can point at | The byte. Specifications call this an octet. |
| **Transfer width** | What hardware moves in one step | A cache line, an on-chip bus transfer, a SIMD register, a chunk of graphics-processor memory |

A contiguous, aligned buffer of bytes already fills a wide transfer. The memory controller moves whole cache lines. Direct memory access (DMA) does the same job in hardware: it copies a buffer without the processor touching every byte. Field boundaries inside that buffer do not create extra transfers.

Storing a value in fewer bits than a byte makes the buffer smaller. Before the program can add two such values, it has to pull them back out with a shift and a mask, or unpack a whole block.

The order of those narrow values is a separate decision. The [FastLanes](https://github.com/cwida/FastLanes) library packs integers in blocks of 1,024 and arranges each block for a SIMD register. One load fills the register. Each part of that register then unpacks its own values with shifts and masks, and those shifts do not mix one part with another. The result is still a buffer of bytes.

The coding a network link uses to send those bytes belongs to the link controller. The application still hands that controller a sequence of bytes.

Choose the encoding from how many bits each value needs, and from how the reader will use the values. The bus already moves the bytes in wide transfers.

---

## Mental model

```text
  Information width     how many bits this value needs
        │
        ▼
  Byte                  the unit a program indexes
        │
        ▼
  Transfer width        cache line, bus transfer, SIMD register
```

The serializer’s contract is the byte buffer, including any rule for how narrow values sit inside those bytes. The processor, the memory controller, and the link then move that buffer in wide transfers. A format that the documentation calls byte-oriented is still the payload of those transfers.

---

## How it works

### A wide transfer already carries bytes

A typical processor cache line is 64 bytes, which is 512 bits. When the processor copies a packed buffer, each store writes several bytes. It does not make a separate transfer for each narrow value. The memory controller then moves the cache line. An on-chip bus that is 32 or 64 bytes wide does the same for a DMA copy: one transfer carries many bytes from a contiguous range of addresses.

```text
  One cache line (64 bytes, one transfer)
  ┌────┬────┬────┬────┬─── … ───┬────┐
  │ 0  │ 1  │ 2  │ 3  │         │ 63 │
  └────┴────┴────┴────┴─── … ───┴────┘
  The serializer wrote bytes. The hardware moved the line.
```

Alignment still matters. A load is cheaper when the start address matches the width of the load. A DMA engine prefers a buffer aligned to the transfer or to the cache line. That is the same alignment idea as in [memory layout](memory-layout.md) and [zero-copy](zero-copy.md). It describes where the buffer starts. It does not replace the byte as the unit of the format.

### Values narrower than a byte

Eight 4-bit values fit in one 32-bit word. Stored one value per byte, the same eight values occupy eight bytes.

```text
  One 32-bit word
  ┌────┬────┬────┬────┬────┬────┬────┬────┐
  │ v0 │ v1 │ v2 │ v3 │ v4 │ v5 │ v6 │ v7 │
  └────┴────┴────┴────┴────┴────┴────┴────┘
   4b   4b   4b   4b   4b   4b   4b   4b
```

The same arithmetic applies to a long array. One million 12-bit samples occupy 1,500,000 bytes when packed tightly. Stored in 16-bit integers they occupy 2,000,000 bytes. The packed array is three quarters of the 16-bit array. These counts leave out headers, shared multipliers, and padding for alignment. They are teaching arithmetic, not a measurement from this benchmark. The [Dashboard](../../dashboard/) owns measured sizes for this suite.

The packed form is smaller on disk and on the wire. A program that wants to add two samples has to extract them first. Extracting one value is a shift and a mask. Extracting a block, as FastLanes does, handles many values in one pass. A smaller file and numbers the processor can use directly are two different costs.

**ASN.1 Unaligned PER** applies the same idea to fields with a known range. ASN.1 is a schema language used in telecommunications. PER means Packed Encoding Rules. Unaligned means a field may begin in the middle of a byte. An integer limited to the range 0 through 999 has 1,000 possible values. Nine bits distinguish only 512 values, so this field needs 10 bits. Unaligned PER can write those 10 bits without rounding the field up to 16. Headers around the field may still add bits. The message is still stored and sent as bytes. The reader counts bits from the start of the message.

The order of bits inside a byte is part of the contract. Writer and reader have to agree which end of the byte holds the first value.

### Aligned bytes and packed bits

An aligned layout and a packed layout serve different ways of reading.

An aligned layout places each multi-byte field on a boundary that matches its size, and sometimes pads a buffer out to a cache line. Cap’n Proto lays each message out as a sequence of 64-bit words, and aligns each field to that field’s own size. SBE (Simple Binary Encoding) gives each field a fixed offset and aligns it to the field’s size. Arrow’s format recommends aligning its buffers to 64 bytes. A reader that uses the same byte order can load such a field with an ordinary load. The cost is the unused padding. See [zero-copy](zero-copy.md).

A packed layout uses those bits for more values. Unaligned PER and integer bit-packing work this way. Reading one value in the middle of the array often means unpacking the block that contains it. Scanning a column of similar numbers in order is the case where arranging those values for a SIMD register earns back the unpacking work.

The same logical array can have a compact form for storage and an aligned form for calculation. Turning one into the other takes time and a temporary buffer. Count that conversion beside encode and decode when you measure.

### Low-precision number blocks

A low-precision tensor is a large example of values narrower than a byte. A tensor here is a multidimensional array of numbers, such as a matrix of model weights. Many elements share one **scale**: a multiplier that turns the small stored integers back into approximate real numbers. Each element may occupy 4 or 8 bits. The scale is a wider number. It may sit next to the elements, or in a separate array. Storing the elements in fewer bits and restoring an approximation with the scale is called quantization.

Two orders then matter.

- The **stored order** keeps the file small and easy to map into memory.
- The **calculation order** is the small block a matrix multiplication expects.

A description that another program can read records how many bits each element uses, how large each group is, where the scale sits, and which stored order was used. The time and the extra bytes spent rearranging stored order into calculation order are part of the cost of using the data.

The file is still a byte buffer plus a written layout rule. Information width and access pattern both matter here. The width of the bus does not, by itself, choose that rule.

### What the link controller already does

A high-speed link turns bytes into symbols on the wire so the receiver can recover a clock, keep the electrical signal balanced, and correct errors. Older links expand every eight data bits into ten bits on the wire (8b/10b). Newer links add a short frame marker instead: two extra bits beside 64 data bits (64b/66b), or two extra bits beside 128 data bits (128b/130b). PCI Express, and CXL (a link used to reach memory on another processor), also group bytes into fixed-size frames called **flits**. A flit carries the bytes being sent, a check, and sometimes symbols used to correct errors.

Those mechanisms add overhead and a small, predictable delay. They sit under the byte buffer. A checksum that the application stores beside those bytes does not change how many bytes the bus moves at once.

---

## Costs and constraints

| Axis | Aligned layout | Values packed narrower than a byte |
|------|----------------|-------------------------------------|
| Processor time | An ordinary load, when alignment and byte order match | A shift and a mask, or a SIMD unpack of a block |
| Size | Padding out to 2, 4, 8, or 64 bytes | Fewer bits per value. Headers and scales still count. |
| Random access | Arithmetic on a field offset | Often unpack a block to reach one element |
| Portability | Write down byte order and alignment | Also write down which end of the byte holds the first value |

Direct loads and tight packing pull in opposite directions. Cap’n Proto, SBE, and Arrow spend bytes so a reader can load a field directly. Unaligned PER and integer bit-packing spend instructions so the file can be smaller. Bit-packing is a decision about the format, in the sense of [Compression vs format](compression-is-not-a-format.md). A general compressor such as gzip does not know that eight values share one 32-bit word.

---

## Illustrative scenario

A recorder stores one million 12-bit sensor readings and later sends the file to another machine.

Storing each reading as a 64-bit floating-point value uses the host slot from [memory layout](memory-layout.md): 8 bytes each, so 8,000,000 bytes for the values. Storing each as a 16-bit integer uses 2 bytes each, so 2,000,000 bytes. Packing 12 bits per reading uses 1,500,000 bytes. On the wire, the 16-bit file and the packed file are both contiguous bytes. A 64-byte cache line carries 64 bytes of either file. What a program can measure is how many bytes were stored, and how many instructions it spent unpacking.

A matrix of 4-bit weights has the same split, one step further along. The stored block, including its scale, can be compact. The multiplication may want those values regrouped into a small block shaped for the processor that runs it. That regrouping has its own time and its own temporary buffer. Widening every value to the bus width spends bytes the value does not need, and the regrouping is still required.

---

## In this suite

The catalog primitives are `bool`, `int32`, `int64`, `float64`, `utf8_string`, and a datetime stored as an `int64` count of milliseconds since the epoch. The fixtures do not include a 12-bit sample, a 4-bit element, or a 17-bit identifier. Where a language registers Arrow IPC, Parquet, ORC, or SBE, those rows measure columns and fixed field offsets. They do not measure values narrower than a byte.

On the Dashboard, `mean_fidelity` is the average of the per-trial fidelity scores. It is 1.0 when every round trip reproduces the fixture. That check is the right one for these codecs. Quantization stores an approximation on purpose, so exact equality should not be the only score for it. The [Dashboard](../../dashboard/) does not answer questions about bit width. A missing row means the suite did not measure that case. It is not a ranking. Family labels are in [Serialization categories](../../analysis/serialization_categories.md).

---

## Common errors of reasoning

- Inventing a format whose fields are as wide as the bus, because the computer has a 64-bit or 512-bit bus. A contiguous buffer of bytes already fills that transfer.
- Treating the coding a link uses on the wire, or a flit, as a serialization format for application data.
- Treating bit-packing as free speed. The smaller array still has to be unpacked before arithmetic.
- Reading the host-width table in [memory layout](memory-layout.md) as a list of the only field sizes a format may use.
- Scoring a quantized block by whether a round trip matches every bit. The useful check is whether the values stay inside an agreed error.

---

## Key takeaways

- How many bits a value needs, the byte a program indexes, and the chunk of bytes hardware moves are three different sizes.
- A contiguous buffer of bytes already fills a wide hardware transfer.
- Packing several values into one byte saves space and adds an unpacking step.
- A SIMD-friendly order, as in FastLanes, is a way of arranging those bytes.
- Direct loads and tight packing are a trade-off. See [zero-copy](zero-copy.md) and [Compression vs format](compression-is-not-a-format.md).
- Low-precision tensors need a stored order and a calculation order. This suite does not measure that split.
- Link coding and flits belong to the link controller. Application data is the payload inside them.
