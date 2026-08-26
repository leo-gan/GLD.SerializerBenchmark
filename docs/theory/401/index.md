# Serialization 401: Implementing Contemporary Serializers

This course teaches how Protocol Buffers works at the byte level. You will also learn how three language libraries turn those bytes into ordinary values and back again. A later set of articles then opens the **timed call sites** of the libraries that lead on this suite’s **document** fixture, one language at a time, and follows those calls into the library source.

| Jump | |
|------|--|
| **Prereqs** | [101](../101/index.md) · [201](../201/index.md) (schema / wire ideas) |
| **Sibling** | [301 production judgment](../301/index.md) — *whether / which*, not *how bytes* |
| **Suite** | [Add a serializer](../../analysis/ADDING_A_SERIALIZER.md) · [Dashboard](../../dashboard/) |

**Protocol Buffers** is a popular schema-driven binary format. You describe message shapes in a `.proto` file. Tools then generate code that can encode and decode those messages. This elective walks through that wire format first. It then follows the paths taken by Python, Rust, and C libraries. A small hands-on lab connects the theory to code you write yourself. After that, nine language articles compare the libraries that lead on this suite’s document fixture by reading their timed functions, not by repeating the 201 format essays.

The course is for people who want to implement, debug, or deeply integrate codecs. It is not only for people who choose a format from a list of options. You do not need to have written a serializer from scratch already. You do need intermediate reading comfort in at least one of the languages used in this suite. You also need a working memory of schema-dependent binary ideas from Serialization 201.

## Who this is for

Take this elective if you need to **implement, debug, or deeply integrate** serializers. It comes after [Serialization 201](../201/index.md). It is deliberately more hands-on than the production-judgment track. It does **not** replace [Serialization 301](../301/index.md).

Course 301 is about multi-constraint product choices under real pressure. Course 401 is about wire rules and runtime paths. You will learn what each byte means. You will also learn how a library walks from a language value to those bytes and back.

In short, 401 teaches the *how* of encoding and decoding. 301 teaches the *whether* and *which* of production decisions.

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [101](../101/index.md) and [201](../201/index.md) (schema identity, encode cost, evolution, dynamic vs IDL binary) |
| **Soft** | [301](../301/index.md) is recommended (trust boundaries, multi-language systems, honest measurement) |
| **Skills** | Intermediate reading level in at least one of Python, Rust, or C |

## Learning outcomes

By the end of this course you should be able to:

1. **Encode and decode** core Protocol Buffers wire structures on paper and with tables. That includes **tags** (small keys that name which field is next), **varints** (variable-length integers), length-delimited fields, nested messages, simple repeated fields, and the rule for skipping unknown fields.
2. **Trace** encode and decode paths in Python (`google.protobuf`), Rust (`prost`), and C (`protobuf-c`). You should also explain **buffer ownership**: who allocates the bytes, who frees them, and how long a buffer must stay valid.
3. **Contrast** the classic C runtime (protobuf-c) with the embedded-oriented design of **nanopb**. Nanopb is a C library that prefers static size budgets over free-form heap trees.
4. **Build** a mini subset encoder/decoder. **Validate** it against golden byte sequences and at least one official parser.
5. **State** deliberate omissions honestly. This lab is a teaching subset. It is not a full production Protocol Buffers implementation.
6. **Read two library call paths in one language** and explain, from the source, why one finishes more encode-and-decode cycles per second (or writes fewer bytes) on this suite’s **document** fixture.

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../101/index.md) | Foundations |
| [201](../201/index.md) | Mechanisms |
| [301](../301/index.md) | Production judgment (core advanced track) |
| **401 (this course)** | Implementer elective — wire format, language paths, and a thin subset lab |

This course teaches **wire encoding, runtime paths, and a thin subset lab**. It is not a full reimplementation of Protocol Buffers. It is also not a multi-constraint product-choice guide. That role belongs to 301.

## Modules

The table below lists every article in this course. For each article, it states what you should be able to do after reading it.

| Article | You should be able to… |
|---------|------------------------|
| [Protobuf wire format step-by-step](protobuf-wire-format.md) | Read and emit tags, varints, length-delimited (LEN) fields, nested messages, unpacked and packed repeated fields; skip unknowns safely |
| [Lab: mini encoder/decoder](lab-mini-protobuf-encoder.md) | Build a MiniUser subset codec; pass goldens G1–G5, bounds tests, and an official-parser check |
| [Python: google.protobuf path](protobuf-python.md) | Trace codegen → backend → `SerializeToString` / `ParseFromString` and who owns the bytes |
| [Rust: prost path](protobuf-rust-prost.md) | Trace `encoded_len` / `encode_raw` / `merge_field` and monomorphized (per-type specialized) codegen |
| [C: protobuf-c path](protobuf-c-protobuf-c.md) | Trace descriptor-driven pack/unpack and heap free discipline |
| [C: nanopb vs protobuf-c](protobuf-c-nanopb-compare.md) | Choose a heap-friendly C library versus a static-budget C library for a deployment |
| [Same bytes, three runtimes](protobuf-cross-language-fidelity.md) | Design interop matrix tests; separate bit-identical encodings from logical fidelity |

### Language comparisons in code

These articles do not repeat the 201 “text versus binary” essays. Each one opens two **timed call sites** in this repository, then follows those calls into the library. The fixture is **document**, one instance, unless the article says otherwise. Measured numbers live on the [Dashboard](../../dashboard/). Both call sites in a pair must follow the same [timing contract](../../analysis/TIMING_HONESTY.md).

The first nine pages take the speed or size leader in each language and ask why it leads. The later pages hold one variable still: same library and two encodings, same JSON and two libraries, same Protocol Buffers bytes and three JavaScript libraries, an in-place crate used as a classical decoder, and a Dashboard row that does not time the library named in the row.

| Article | You should be able to… |
|---------|------------------------|
| [Python: msgspec-msgpack vs orjson](python-msgspec-vs-orjson.md) | Show why a positional MessagePack Struct decodes faster than Rust JSON over dictionaries |
| [Python: msgspec JSON vs MessagePack](python-msgspec-json-vs-msgpack.md) | Hold the library still and isolate JSON tokens from MessagePack type codes |
| [Python: orjson vs json](python-orjson-vs-json.md) | Show why the same 448-byte JSON can differ by a factor of five |
| [Rust: Speedy vs Bincode](rust-speedy-vs-bincode.md) | Show why generated `write_to` plus fixed-width integers is faster than Serde plus variable-length integers |
| [Rust: Speedy vs Postcard](rust-speedy-vs-postcard.md) | Show compactness as a width choice that can stay on Serde |
| [Rust: rkyv vs Speedy](rust-rkyv-vs-speedy.md) | Show that in-place access only helps if the timed path uses it |
| [C: custom-binary vs ubj](c-custom-binary-vs-ubj.md) | Show that ubj is the same packed record plus a 37-byte envelope and a second copy |
| [C++: Bitsery vs YAS](cpp-bitsery-vs-yas.md) | Show why one-byte lengths and a reused buffer beat eight-byte lengths and a 20 KiB stream |
| [C++: the simdjson row](cpp-simdjson-wrapper.md) | Read a Dashboard row whose encode is nlohmann `dump` and whose decode parses twice |
| [C#: BinaryPack vs Bond Fast](csharp-binarypack-vs-bond.md) | Show positional IL stores versus a type-and-identifier prefix on every field |
| [Go: kelindar/binary vs hamba/avro](go-kelindar-vs-avro.md) | Show two cached positional plans, and why the Avro schema walk costs a little more |
| [Java: Protostuff vs protobuf-java](java-protostuff-vs-protobuf.md) | Show why equal 155-byte messages still differ: POJO merge versus generated `parseFrom` |
| [JavaScript: JSON vs google-protobuf](javascript-json-vs-protobuf.md) | Show that V8’s native JSON path is faster than a real JavaScript Protocol Buffers encode and decode, even though JSON is larger |
| [JavaScript: three Protocol Buffers libraries](javascript-three-protobufs.md) | Compare google-protobuf, protobufjs, and protobuf-es on the same 155 bytes |
| [Swift: FlatBuffers vs SwiftProtobuf](swift-flatbuffers-vs-protobuf.md) | Show why vtable loads can beat a smaller Protocol Buffers stream |

**Suggested path.** This order matches the self-check below. The side navigation lists the same pages.

1. [Wire format](protobuf-wire-format.md)
2. [Lab](lab-mini-protobuf-encoder.md) *(start as soon as the wire article is readable)*
3. [Python](protobuf-python.md) → [Rust](protobuf-rust-prost.md) → [C protobuf-c](protobuf-c-protobuf-c.md)
4. [nanopb compare](protobuf-c-nanopb-compare.md)
5. [Cross-language fidelity](protobuf-cross-language-fidelity.md)
6. One language-comparison article in a language you read fluently (table above)

The flagship schema in this benchmark suite is `schemas/v2/protobuf/benchmark_v2.proto`. Teaching pages intentionally use a much smaller message called **MiniUser**. MiniUser is not the suite schema. It exists so you can study hex dumps without drowning in fields.

## Lab notebooks (Python / Colab)

| Notebook | Use with |
|----------|----------|
| [Wire format playground](../notebooks/401/wire_format_playground.ipynb) | [Wire format](protobuf-wire-format.md) |
| [MiniUser encoder lab](../notebooks/401/lab_mini_protobuf_encoder.ipynb) | [Lab article](lab-mini-protobuf-encoder.md) |

Index and install notes live in the [notebooks README](../notebooks/README.md).  
If you want the same golden hex sequences G1–G5 in another language, see the multi-language homework companions: [companions/go](../notebooks/companions/go/) · [companions/rust](../notebooks/companions/rust/).

## Four Protocol Buffers libraries at a glance

In this section we compare how four libraries relate to the same binary layout.

The **wire format** is the layout of field numbers, wire types, and payloads on the byte stream. That layout is shared. Python, Rust, and C can all encode and decode the same Protocol Buffers bytes. What differs is **codec engineering**. Each library walks the schema in its own way. Each library allocates buffers differently. Each library reports errors differently.

| | **Python** (`google.protobuf`) | **Rust** (`prost`) | **C** (`protobuf-c`) | **C** (nanopb) |
|--|--------------------------------|--------------------|----------------------|----------------|
| Schema at encode time | Runtime descriptors plus a backend (upb or pure Python) | Monomorphized per-type code (specialized at compile time for each message type) | Runtime descriptor tables | Field list plus static maximum sizes |
| Output ownership | New immutable `bytes` object | Caller-owned `Vec<u8>` | Caller-allocated buffer | Static buffer or stream budget |
| Decode ownership | Garbage-collected Message object | Owned Rust struct | Heap message that you must free with `free_unpacked` | Preallocated static struct |
| Typical failure | Parse error raised as a Python exception | `DecodeError` | `NULL` return, or a leak if you skip free | Encode/decode fails when data exceeds a configured max |

Details appear in the language-path articles and in [nanopb compare](protobuf-c-nanopb-compare.md).

## Honesty rules

The program-wide rules still apply. There are no universal winners. Implementation quality beats brand name. The **Dashboard** owns measured numbers.

**401-specific honesty:**

1. **Wire truth is shared; runtimes differ.** Python, Rust, and C can all encode and decode the same binary layout. They can still own buffers differently.
2. **The subset lab labels its omissions.** Packed repeated fields, zigzag signed integers, maps, oneofs, and full production hardening are out of scope on purpose.
3. **Suite benchmark runners illustrate integration.** They are not the reference design for how you should structure production Protocol Buffers.
4. **Dashboard numbers are optional cost context.** Speed tables are not the focus of the Protocol Buffers sequence. The language-comparison articles quote one L1 slice so you can attach a number to a line of code. They do not name a universal library.
5. **Hostile input is a 301 topic.** For operational controls on untrusted payloads, see [301 untrusted input](../301/untrusted-input.md). Codec-side bounds still belong in every decoder. Examples include truncated varints and overlong lengths.
6. **Language tours are parallel, not ranked.** This course does not crown “Rust wins.”

## Assessment (self-check)

Use the following checklist to test yourself after you finish the modules.

1. Complete the lab golden vectors **G1–G5** (including the empty G2). Also complete unknown-field skip, bounds failures, and at least one official-parser cross-check.
2. Explain pack/unpack **ownership** in one of Python, Rust, or C. Who allocates? Who frees? What must stay valid during the call?
3. State when **nanopb** is preferable to **protobuf-c**, and when the reverse is true. See [nanopb compare](protobuf-c-nanopb-compare.md).
4. Design a three-language encode/decode **matrix test**. Say when bit-identity (`memcmp` of encodings) is required. Say when logical equality is enough. See [cross-language fidelity](protobuf-cross-language-fidelity.md).
5. Open one language-comparison article. Quote the two timed functions. State whether the speed gap is an **encoding** difference (the bytes on the wire), an **implementation** difference (how the library writes those bytes), or a **runner** difference (work moved into untimed `prepare`).

## Where to go next

- [Serialization 201](../201/index.md) if schema-dependent concepts feel rusty.
- [Serialization 301](../301/index.md) for multi-constraint product choices.
- Shared suite schema in this repository: `schemas/v2/protobuf/benchmark_v2.proto`.
