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

By the end of the planned MVP you should be able to:

1. **Encode and decode** (on paper / with tables) core Protobuf wire structures.  
2. **Trace** encode/decode paths in Python (`google.protobuf`), Rust (`prost`), and C (`protobuf-c`).  
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

## Modules (planned)

Articles will ship under this hub. Until then, use [201](../201/index.md) for mechanisms and [301](../301/index.md) for shipping decisions.

| Module | Content | Status |
|--------|---------|--------|
| Shared wire | Protobuf wire format step-by-step | Planned |
| Python path | `google.protobuf` encode/decode | Planned |
| Rust path | `prost` + prost-build | Planned |
| C path | protobuf-c (nanopb comparison box) | Planned |
| Lab | Mini Protobuf subset encoder/decoder | Planned |

## Honesty rules

Program rules (no universal winners; implementation beats brand; suite Results own numbers).  
**401-specific:** subset labs label omissions; suite harnesses illustrate integration—they are not the reference design for Protobuf.

## Where to go next

- [Serialization 201](../201/index.md) if wire concepts are rusty.  
- [Serialization 301](../301/index.md) for multi-constraint product choices.  
- Shared schema anchor: repository `schemas/benchmark_data.proto` (when following language harnesses).
