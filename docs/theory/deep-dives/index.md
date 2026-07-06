# Deep dives

Short, problem-driven essays on **how serialization mechanisms work** and **how to choose under constraints**. 

Theory alone does not decide production choices. Use these pages to build mechanism-level judgment, then validate with measured libraries.


## Modules

### Representation

- [Memory layout, alignment, and endianness](memory-layout.md)
- [Where encode/decode time actually goes](encode-decode-cost.md)

### Contracts & change

- [Self-describing vs schema-dependent](self-describing-vs-schema-dependent.md)
- [Schema evolution that doesn’t break readers](schema-evolution.md)

### Families in practice

- [Dynamic binary vs IDL binary](dynamic-vs-idl-binary.md)
- [Zero-copy layouts](zero-copy.md)

### Systems concerns

- [Compression is not a format](compression-is-not-a-format.md)
