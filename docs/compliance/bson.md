# BSON

BSON is the binary document format used by MongoDB. A document is a
32-bit length, then typed elements, then a trailing `0x00`. The
public grammar is at [bsonspec.org](https://bsonspec.org/spec.html).

MongoDB also publishes a [bson-corpus](https://github.com/mongodb/specifications)
test suite. That corpus is **CC BY-NC-SA 3.0 US**. This repository is
MIT, so those files were **not copied** — including the copy that
lives inside Apache-licensed libbson. Cases here recreate every type
on [bsonspec.org](https://bsonspec.org/spec.html) with new names
(`harbor`, `kelp`, `berth`) and different values.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| 1.0 | Document framing plus `int32`, UTF-8 string, and bool. |
| 1.1 | Same framing, plus a `null` element (type `0x0A`). |
| 1.1 decimal128 | Type `0x13`: a 128-bit decimal number (IEEE 754-2008). |

**Document framing** means the first four bytes are the total size in
bytes, including themselves and the final NUL. If that size does not
match the buffer, the document is not well-formed.

## What the cases cover

- Empty document (`0500000000`)
- `int32` `n=7`, string `s=kelp`, bool `ok=true`, null `missing`
- decimal128 canonical zero
- Rejects: declared size longer than the buffer, missing trailing NUL,
  unknown element type

Catalog: `compliance/data/bson/`.

## Python serializer

`bson.decode` from **pymongo**. The Python speed bench does not always
install pymongo, so this Dashboard row is absent until that package
is present.

decimal128 may decode as a library-specific type. The catalog does
not require a particular host class for that one accept case; it
checks that the document parses.
