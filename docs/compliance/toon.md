# TOON

TOON (Token-Oriented Object Notation) is a line-oriented text encoding of the JSON data model. Arrays declare their length, and a uniform array of objects can declare its fields once. The current specification is **4.4** (8 October 2026).

The specification is [SPEC.md](https://github.com/toon-format/spec/blob/main/SPEC.md) in [toon-format/spec](https://github.com/toon-format/spec). The media type is `text/toon`.

## Bytes and tokens

The speed table's **Size** column is the UTF-8 byte length of the encoded document. A token count is a different number. It depends on a tokenizer, and it is not timed with encode or decode. The counts below use the `o200k_base` tokenizer and were taken outside the timer.

| Document | UTF-8 bytes | o200k_base tokens |
|----------|-------------|-------------------|
| TOON object with an inline array | 38 | 20 |
| the same value as compact JSON | 48 | 20 |
| TOON tabular array of two objects | 43 | 21 |
| the same value as compact JSON | 67 | 25 |

The first object is `harbor`, `n`, and `tags`. Its TOON spelling is:

```
harbor: kelp
n: 7
tags[2]: kelp,harbor
```

The tabular document is `boats[2]{name,draft}:` with the rows `kelp,7` and `harbor,1.5`. On the first object the byte lengths differ and the token counts match. On the table both numbers move, by different amounts. Read each column on its own.

## What the cases cover

- Root string, number, boolean, and null
- An exponent token (`1e2` is 100)
- An object, a nested object, and a quoted keyword
- An inline primitive array and a tabular array of objects
- A full-line comment
- An empty document, which the reference decoder reads as `{}`
- Rejects: an open quote, a duplicate key, a short array, a tab indent, and a short tabular row

Catalog: `compliance/data/toon/spec.json`. Names are original (`kelp`, `harbor`, `berth`).

## Serializers

| Language | Serializer | Decode |
|----------|------------|--------|
| Python | `toon-format` | `toon_format.decode` |
| Python | `toons` | `toons.loads` |
| Python | `ctoon` | `ctoon.loads` |
| JavaScript | `toon` | `@toon-format/toon` `decode` |
| Go | `toon-go` | `Decode` |
| Rust | `toon-format` | `decode_default` |
| Rust | `ctoon` | `ctoon::loads` |
| Rust | `tru` | `try_decode` |
| C# | `Toon.Format` | `ToonDecoder.Decode` |
| C# | `ToonNet` | `ToonSerializer.Deserialize` |
| C# | `Corvus.Toon` | `ToonDocument.ConvertToJsonString` |
| Java | `jtoon` | `JToon.decode` |
| Java | `json-io` | `fromToon` with `strictToon` |
| Kotlin | `ktoon` | `decodeToonToJson` |
| PHP | `toon` | `Toon::decode` with specification 4.4 |
| Swift | `ToonFormat` | `TOONDecoder` |

`helgesverre/toon` can decode 3.3, 4.1, and 4.4. Its package default is 3.3. This row passes 4.4. Swift `ToonFormat` 0.5 targets specification 4.1, so a 4.4-only rule can miss. `ktoon` is a community Kotlin port. There is no official Kotlin library in the registry.

`ctoon` is the same C99 core measured through its Python and Rust bindings. `tru` is the crates.io name of the Dicklesworthstone codec. `json-io` is the Java object-graph library's TOON reader and writer. `Corvus.Toon` converts between JSON text and TOON text.

Encoder-only libraries stay out of this column. That includes Cysharp `ToonEncoder`, Go `gotoon`, the published `Nizzola.ToonConvert.NET` 1.0.0 package, and Ruby `toon-fu`. `TOONc` parses TOON and can build a tree, and it has no function that writes TOON. `t3-toon` is a TYPO3 extension. The Go binding of `ctoon` uses cgo, and this Go tree does not. Languages this suite does not run stay unscored.

Pass/fail cells are on the [Dashboard → Compliance](../dashboard/index.html#compliance/python/toon-format/toon) view, standard **TOON**, column **TOON**.
