# CBOR

CBOR is IETF **STD 94**.

## Versions

| Version | Year | Parser-visible difference |
|---------|------|---------------------------|
| [RFC 7049](https://www.rfc-editor.org/rfc/rfc7049) | 2013 | Original major types, indefinite lengths, Appendix A examples. |
| [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949) | 2020 | Same format family. Tightens **well-formedness** (simple values 24–31 are not well-formed; clearer “break” rules). Preferred / deterministic encoding is specified but not required of every decoder. |

There is no “CBOR 2.” RFC 8949 says it does not create a new version of
the format; it replaces 7049 in place.

## What the cases cover

- Appendix A integers, `true` / `false` / `null`, empty text / bytes /
  array / map (IETF Code Components — see
  [`THIRD_PARTY_NOTICES.md`](../../compliance/THIRD_PARTY_NOTICES.md))
- Indefinite-length array and byte string
- Rejects: truncated `ai=24`, lone `0xff` break, odd-length map,
  two-byte simple `0xf800` (8949 §3.3)

Catalog: `compliance/data/cbor/`. Inputs are hex.

## Python adapter

`cbor2`. Some implementations decode a lone break as an internal
sentinel instead of raising; that shows up as a FAIL on the
`break-alone` cases.

## Legal note

Appendix A encodings are IETF Code Components (Revised BSD). All
reject cases and case titles are original. Details:
[legal provenance](legal.md).
