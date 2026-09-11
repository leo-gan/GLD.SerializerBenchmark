# TOML

TOML is specified at [toml.io](https://toml.io). It is not an RFC.

## Versions

| Version | Year | Parser-visible difference |
|---------|------|---------------------------|
| [0.5.0](https://toml.io/en/v0.5.0) | 2018 | Dotted keys. Last widely deployed pre-1.0. |
| [1.0.0](https://toml.io/en/v1.0.0) | 2021 | First stable. Trailing commas in **arrays**. No trailing comma in **inline tables**. |
| [1.1.0](https://toml.io/en/v1.1.0) | 2024+ | Trailing commas and newlines in inline tables; `\xHH` string escapes. |

## What the cases cover

- Bare / dotted keys, tables, inline tables, arrays of tables
- Strings (basic and multiline), integers with `_`, floats, bools
- Comments
- 1.0 trailing comma in arrays vs forbidden trailing comma in inline tables
- 1.1 inline-table comma / newline / `\xHH`
- Rejects: missing value, redefined table, duplicate key, `True`, unclosed string

Catalog: `compliance/data/toml/`.

## Python adapter

`tomllib` (stdlib 3.11+) implements **TOML 1.0**. It will:

- pass the 1.0 file
- **accept** a trailing comma in an array even when the 0.5 file says reject
- **reject** 1.1-only inline-table syntax

That is expected and report-only.

## Official suite

[toml-lang/toml-test](https://github.com/toml-lang/toml-test) is MIT
and is vendored for 1.0 and 1.1 (`toml-1.0.0-*`, `toml-1.1.0-*`).
TOML 0.5.0 has no official file list; those cases stay original.
See [legal provenance](legal.md).
