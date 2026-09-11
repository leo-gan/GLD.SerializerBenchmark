# Reading compliance failures

A compliance line is a **claim about one input and one library**, tied
to one published section. It is not a score.

## Anatomy

```text
COMPLIANCE MUST NOT FAIL [json-8259-bare-nan] json
  Standard : RFC 8259 8259
  Section  : 6 — Numbers
  Spec     : https://www.rfc-editor.org/rfc/rfc8259#section-6
  Rule     : Numeric values are produced from the number grammar; NaN is not a number token.
  Expected : reject
  Observed : accepted as nan
  Case     : NaN is not a JSON number
```

| Field | Meaning |
|-------|---------|
| `MUST` / `MUST NOT` / `SHOULD` | How strong the cited rule is |
| `FAIL` | This adapter did not match `Expected` |
| `[id]` | Stable case id (search the JSON file) |
| last token (`json`) | Serializer name |
| `Spec` | Click-through to the paragraph |
| `Expected` | `accept` or `reject` from the rule |
| `Observed` | What the library did |

`PASS` lines (only in `--detailed`) still carry the same URL.

## Version mismatches are expected

The same bytes can be **required** under one version and **forbidden**
under another.

| Input | RFC 4627 | RFC 7159 / 8259 |
|-------|----------|-----------------|
| `"harbor"` as the whole document | reject (text must be object/array) | accept (any value) |
| UTF-16LE BOM + `{}` | not the 4627 story | 7159: allowed encodings; 8259: UTF-8 only |

| Input | YAML 1.1 | YAML 1.2 JSON/Core |
|-------|----------|--------------------|
| `flag: yes` | boolean `true` | string `"yes"` |

| Input | TOML 1.0 | TOML 1.1 |
|-------|----------|----------|
| `{ harbor = "kelp", }` | reject | accept |

A library that implements *today’s* JSON (8259) will “fail” the 4627
top-level-scalar cases. That is the catalog working, not a bug in
`orjson`.

## What to do with a FAIL

1. Open `Spec`.
2. Decide whether you care about **that version**. Most new services
   want RFC 8259 + I-JSON habits, not RFC 4627.
3. If you need the stricter profile, configure the library (or pick
   another). The catalog does not change library defaults.

## What never fails the command

Library FAILs are printed, written to
`logs/compliance/<timestamp>.json`, and shown on
[Dashboard · Compliance](../dashboard/#compliance).
The command stays exit 0 unless the **catalog or runner** is broken.

That is deliberate. Treating every historical MUST as a hard error
would fail this repo’s own Python stdlib (`json.loads("NaN")`) and
PyYAML’s YAML 1.1 bools on day one.
