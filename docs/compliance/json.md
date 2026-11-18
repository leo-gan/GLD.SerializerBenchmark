# JSON

JSON is specified twice in industry: **IETF RFCs** and **ECMA-404**.
RFC 8259 and ECMA-404 2nd edition describe the same grammar. This
corpus follows the IETF line because the RFCs are versioned and
section-linkable.

## Versions

| Version | Year | What changed for parsers |
|---------|------|--------------------------|
| [RFC 4627](https://www.rfc-editor.org/rfc/rfc4627) | 2006 | A JSON text is a serialized **object or array**. |
| [RFC 7159](https://www.rfc-editor.org/rfc/rfc7159) | 2014 | A JSON text is any value. Encoding: UTF-8, UTF-16, or UTF-32. |
| [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) (STD 90) | 2017 | Interchange **MUST be UTF-8**. Current document. |
| [RFC 7493](https://www.rfc-editor.org/rfc/rfc7493) I-JSON | 2015 | Profile of 7159/8259: UTF-8, no unpaired surrogates, unique keys, binary64 numbers. Not a fourth grammar. |

RFC 7158 existed for a few days and was replaced by 7159. We do not
ship a 7158 file.

## What the cases cover

- Grammar: objects, arrays, strings, numbers, `true` / `false` / `null`
- Insignificant whitespace
- Escapes (`\n`, `\u00e9`, surrogate pairs)
- Rejects: trailing commas, comments, single quotes, unquoted keys,
  leading zeros, unescaped controls, empty input, `True`, extra values
- **`\u` escapes:** four ASCII hex digits. A non-ASCII digit, a code point
  whose low byte looks like a hex digit, and a short `\u` are reject
- **4627 vs 7159/8259:** top-level string / number / `true`
- **7159 vs 8259:** UTF-16 text, including the JSONTestSuite `i_` files
- **I-JSON:** no lone surrogate, unique keys, no NaN

## When accept and reject both conform

`expect` is `any` when the cited sentence allows both outcomes. The score
does not prefer one. `requirement` is that sentence's keyword
(`SHOULD` for unique names, `MAY` for a limit or a BOM). It is not a
hint to reject.

The `paragraph` names the latitude:

- **Limits.** A huge number, or a 500-deep array. The parser may refuse it.
- **Unpredictable receivers.** Duplicate member names, and an unpaired
  `\u` surrogate. RFC 8259 says receivers do not agree. I-JSON still
  rejects both, on its own cases.
- **Optional BOM.** RFC 7159 and RFC 8259 allow a parser to ignore a
  leading U+FEFF. RFC 4627 does not, so that case is `reject` there.

A harness that wants a house rule (always reject duplicate names, always
accept a big integer) keeps that rule outside this corpus. These cases
exist so a report can show what the library did.

Ill-formed UTF-8 is `reject` on every JSON RFC. UTF-16 text is `accept`
for RFC 4627 and RFC 7159, and `reject` for RFC 8259.

Catalog: `compliance/data/json/`. Official parse corpus is
[JSONTestSuite](https://github.com/nst/JSONTestSuite) (318 `y_`/`n_`/`i_`
files, MIT) plus original extras. RFC 8259 has 352 cases.

## Python adapters

`json` (stdlib), `orjson`, `msgspec.json`, `python-rapidjson`.

Typical catalog pattern (report-only):

- Modern libraries **accept** a top-level string → they **fail** the
  4627-only cases and **pass** 7159/8259.
- stdlib `json` **accepts** `NaN` and `Infinity` → fails the “not a
  number token” MUST NOT cases. `orjson` / `msgspec` reject them.
- Almost nobody implements UTF-16 for 7159 §8.1.

## Official suite

[nst/JSONTestSuite](https://github.com/nst/JSONTestSuite) is MIT and
is vendored (`jts-*` ids). Each file is mapped onto the section of the
RFC under test, so a failure still names a paragraph. An `i_` file is
not automatically unscored. Original extras (`harbor` / `kelp`) sit
beside those files. Details: [legal provenance](legal.md).
