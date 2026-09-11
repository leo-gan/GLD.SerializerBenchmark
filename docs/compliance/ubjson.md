# UBJSON

UBJSON (Universal Binary JSON) is a binary encoding of the JSON data
model. Every value starts with a one-byte **marker** — an ASCII
letter such as `Z` for null or `S` for string — then, when needed, a
length and a payload. The current document is
[Draft 12 on ubjson.org](https://ubjson.org/) (Apache-2.0 spec).

A community suite
([dmitry-ra/ubjson-test-suite](https://github.com/dmitry-ra/ubjson-test-suite))
has **no OSI license** in the tree. It was **not copied**. Cases here
are recreated (names `n`, `kelp`, `harbor`).

## Versions

| Version | Year (approx.) | Parser-visible difference |
|---------|----------------|---------------------------|
| Draft 8 | 2012 | Literals `Z` / `T` / `F`. Numbers and containers used markers that Draft 12 later retired (`B` byte, `s` string, `a` length-prefixed array). |
| Draft 9 | 2012–13 | Streaming containers `[` `]` and `{` `}`. An optional `#` count lets the writer omit the closer. |
| Draft 12 | 2016 (current) | New number markers (`U`, `i`, `I`, …), string `S`, char `C`, high-precision `H`, no-op `N`, and strongly typed containers (`$`). |

A **streaming** container writes `[`, then elements, then `]`. The
writer does not need to know the length in advance. A **count**
(`#`) says how many elements follow, so the closer can be skipped. A
**typed** container (`$`) says every element has the same marker, so
that marker is written once.

## What the cases cover

- Literals null / true / false; empty input; unknown marker `0x00`
- Draft 8-only markers `B`, `s`, `a` (accept on the Draft 8 column)
- Streaming empty array and object; `n=7`; array `[1, 2]`
- Count-optimized array and object
- Draft 12: `U`, `i`, `I`, `S`, `C`, `H`, `N` inside an array, typed
  uint8 array
- Rejects: unclosed array, truncated number, truncated string

Catalog: `compliance/data/ubjson/`.

## Python serializer

`py-ubjson` (`ubjson.loadb`) implements **Draft 12**. It will:

- **pass** Draft 9 and Draft 12
- **fail** the three Draft 8-only markers (`B`, `s`, `a`), because
  those letters are not type markers any more

That is expected and report-only. A Draft 12 library is not a Draft 8
library.
