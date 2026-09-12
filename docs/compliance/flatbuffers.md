# FlatBuffers

FlatBuffers is a binary format from Google. A program normally
describes its records in a `.fbs` schema file. A code generator then
writes a reader and writer for that schema in the target language.
The encoding rules are at
[flatbuffers.dev internals](https://flatbuffers.dev/internals/).

The same project also defines **FlexBuffers**. FlexBuffers is a
self-describing cousin: each value carries its own type, so a decoder
does not need a `.fbs` file. That is closer to JSON or CBOR.
Specification: [flexbuffers.html](https://flatbuffers.dev/flexbuffers.html).

XML is not in this catalog.

## Versions

| Column on the Dashboard | What it is | What we can check |
|-------------------------|------------|-------------------|
| FlexBuffers | Schemaless sibling of FlatBuffers | Full decode: the library must return the Python value (`7`, `"kelp"`, `{harbor: kelp}`). |
| FlatBuffers internals (tables) | Ordinary FlatBuffers **table** — a record whose field layout is defined by a schema | Only **well-formedness rejects**. An empty or two-byte buffer cannot be a table. |
| File identifier | Optional four-byte tag that can sit after the root offset | Only a reject: the buffer claims an identifier but is too short to hold one. |

A **table** is the usual FlatBuffers record. Walking its fields needs
the generated reader for that schema. This corpus does not compile a
`.fbs` file, so we cannot ask “did field `harbor` decode as `kelp`?”
for tables. We can only ask “is this even a complete table buffer?”
That is why the table and file-id columns are reject-only.

FlexBuffers does not have that limit. The bytes name the type of each
value, so the Python `flexbuffers` decoder can return a host value and
we compare it.

## What the cases cover

- FlexBuffers integer, string, and map roots
- FlexBuffers rejects: empty buffer, truncated root
- Table rejects: empty buffer, shorter than a 32-bit offset
- File-identifier reject: four-byte offset with no room for the tag

Catalog: `compliance/data/flatbuffers/`. The official
`gold_flexbuffer_example.bin` from google/flatbuffers (Apache-2.0) is
vendored as `fb-flex-gold`. The rest of the FlexBuffers column is a
generated type matrix (`kelp` / `harbor`).

## Python serializer

`flatbuffers.flexbuffers.GetRoot`. It implements FlexBuffers, not
generated tables. It will:

- **pass** the FlexBuffers accept and reject cases
- **pass** the table rejects (the buffer is too short to look like a
  FlexBuffers root either)
- **fail** the file-id reject if it accepts a four-byte stub as a root

That last FAIL is report-only.
