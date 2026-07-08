# Serialization 401: Implementing Contemporary Serializers

> Protobuf wire encoding and language runtime paths (Python, Rust, C), plus a thin subset lab—for serializer developers and deep integrators.

## Who this is for

People who **build or deeply integrate** codecs—not only choose formats. This is a **senior elective** after [Serialization 201](../201/index.md). It does **not** replace [Serialization 301](../301/index.md) (production judgment).

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [101](../101/index.md) + [201](../201/index.md) (schema identity, encode cost, evolution, dynamic vs IDL) |
| **Soft** | [301](../301/index.md) recommended (trust, polyglot, honest measurement) |
| **Skills** | Intermediate reading level in at least one of Python, Rust, C |

## Learning outcomes

By the end of this course you should be able to:

1. **Encode and decode** (on paper / with tables) core Protobuf wire structures: tags, varints, length-delimited, nested, simple repeated, skip unknowns.  
2. **Trace** encode/decode paths in Python (`google.protobuf`), Rust (`prost`), and C (`protobuf-c`), including buffer ownership.  
3. **Contrast** briefly classic C runtime vs embedded nanopb design axes.  
4. **Construct** a mini subset codec and **validate** against golden bytes or an official parser.  
5. **State** deliberate omissions (subset honesty).

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../101/index.md) | Foundations |
| [201](../201/index.md) | Mechanisms |
| [301](../301/index.md) | Production judgment (core advanced) |
| **401 (this course)** | Implementer elective — wire + paths + lab |

## Depth model

| Decision | Choice |
|----------|--------|
| **Depth** | **B + thin lab**: wire + library paths; mini subset lab—not full Protobuf |
| **C stack** | **Primary: protobuf-c**; nanopb comparison box only |
| **Flagship format** | Protocol Buffers + shared `schemas/benchmark_data.proto` |

## Modules

| Module | Article | Role |
|--------|---------|------|
| Shared wire | [Protobuf wire format step-by-step](protobuf-wire-format.md) | Byte-level rules + worked MiniUser |
| Python path | [google.protobuf path](protobuf-python.md) | Codegen → SerializeToString / ParseFromString |
| Rust path | [prost path](protobuf-rust-prost.md) | prost-build → `Message` encode/decode |
| C path | [protobuf-c path](protobuf-c-protobuf-c.md) | pack/unpack + ownership; nanopb box |
| Lab | [Mini Protobuf subset encoder/decoder](lab-mini-protobuf-encoder.md) | Build + golden + official validate |

**Suggested order:** wire → lab (can start after wire) → language paths in any order (Python → Rust → C recommended).

## Honesty rules

Program rules (no universal winners; implementation beats brand; suite Results own numbers).  
**401-specific:**

1. Wire truth is shared; runtimes differ.  
2. Subset lab labels omissions.  
3. Suite harnesses illustrate integration—they are not the reference design for Protobuf.  
4. Results are optional cost context—not the focus of this course.  
5. Hostile input: [301 untrusted input](../301/untrusted-input.md).  
6. Parallel language tours—not “Rust wins.”

## Assessment (self-check)

Complete the lab golden vectors G1–G5 and at least one official-parser cross-check. Explain pack/unpack ownership in one of Python, Rust, or C without reading the article.

## Where to go next

- [Serialization 201](../201/index.md) if schema-dependent concepts are rusty.  
- [Serialization 301](../301/index.md) for multi-constraint product choices.  
- Shared schema: repository `schemas/benchmark_data.proto`.
