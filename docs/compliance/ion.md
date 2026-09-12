# Amazon Ion

Ion is Amazon’s self-describing format. One data model has two
writings: a text form that looks like a JSON superset, and a compact
binary form. The rules are at
[ion-docs](https://amazon-ion.github.io/ion-docs/docs/spec.html)
(text) and
[binary.html](https://amazon-ion.github.io/ion-docs/docs/binary.html)
(binary).

The official [amazon-ion/ion-tests](https://github.com/amazon-ion/ion-tests)
tree is **Apache-2.0**. We vendor the `iontestdata` files
(`ion-good-*`, `ion-bad-*`). License:
`compliance/vendor/ion-tests.Apache-2.0.txt`.

## Versions

| Version | What the files are | Parser-visible difference |
|---------|--------------------|---------------------------|
| 1.0 text | Official `*.ion` | A text document is zero or more values. Comments are whitespace. |
| 1.0 binary | Official `*.10n` | A binary stream must start with the **version marker** `E0 01 00 EA`. |
| 1.1 | Original cases (no official testdata folder in that repo) | The 1.1 marker is `$ion_1_1` in text and `E0 01 01 EA` in binary. A 1.1 reader must still accept 1.0. |

A **version marker** (IVM) is the first token that names the Ion
language version. `amazon.ion` 0.x is a **1.0** reader, so the two
“must accept the 1.1 marker” cases FAIL. That is report-only.

The official `good/equivs` and `good/non-equivs` folders are still
valid documents. This catalog only asks “did it parse?” It does not
ask whether two Ion values are equal in the Ion data model.

## What the cases cover

- Official good files → `expect: accept`
- Official bad files → `expect: reject`
- 1.1: text and binary version markers, plus “1.0 still reads”
- 1.1 reject: an unknown major version in the binary marker

Catalog: `compliance/data/ion/`. UTF-16 and UTF-32 official “good”
files are valid Ion; `amazon.ion` does not implement those encodings
and will FAIL them.

## Python serializer

`amazon.ion.simpleion.loads(..., single_value=False)`.
**Single value** would mean “the file must hold exactly one value.”
Ion documents may be empty or hold several values in a row, so the
adapter asks for a list of top-level values.
