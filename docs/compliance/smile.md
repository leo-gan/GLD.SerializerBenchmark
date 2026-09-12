# Smile

Smile is a binary encoding of the JSON data model, designed by the
Jackson project. A Smile document usually starts with a four-byte
header: the ASCII smiley `:)` , a newline, and a flags byte
(`3A 29 0A` plus flags). The living spec is
[smile-specification.md](https://github.com/FasterXML/smile-format-specification/blob/master/smile-specification.md)
(BSD-2-Clause).

There is no official OSI-licensed test corpus. Cases are original
(names `n`, `kelp`, `harbor`). Token byte values are facts from the
spec, not a copied example file.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| 1.0 | Header, literals (`null` / `true` / `false` / empty string), small integers, short ASCII strings, arrays (`0xF8`…`0xF9`) and objects (`0xFA`…`0xFB`). |
| 1.0 shared names | Flags bit 0 is set. After the decoder has seen a field name, a later object may repeat that name with a one-byte **back-reference** instead of writing the letters again. |
| 1.0.4 | Clarifications in the 2013 spec: 32-bit int token `0x24`, 32-bit float `0x28`, optional end marker `0xFF`, reserved `0xFE`, and a version nibble that must be `0`. |

A **back-reference** is a short token that means “the same string as
slot *k* in the table I have been building.” A **nibble** is four
bits. The high nibble of the flags byte is the format version; only
version `0` is defined.

## What the cases cover

- Literals, small integer `7`, string `kelp`, empty array and object
- Object `{n: 7}` and `{harbor: kelp}`
- Shared-name header and a two-object array that reuses key `n`
- 32-bit integer `31`, float `1.5`, `null` followed by `0xFF`
- Rejects: missing or truncated header, bad magic, unclosed array,
  reserved `0xFE`, unused token `0x00`, version nibble `1`

Catalog: `compliance/data/smile/`. Inputs are hex.

## Python serializer

`newsmile.SmileDecoder`. The older PyPI package `pysmile` 0.2 is
Python 2 and is not a dependency.

Typical catalog pattern (report-only):

- **pass** the 1.0 literals and containers
- **fail** the shared-name back-reference if the decoder never stored
  the first key
- **fail** the “version nibble must be 0” reject if the decoder
  ignores the nibble and still reads the value
