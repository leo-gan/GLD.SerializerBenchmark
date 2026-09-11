# Apache Avro

Avro is a schema-on-the-side binary format from the Apache project.
The writer and the reader both know a schema. The bytes are only the
values, not the field names. The encoding rules are in the
[Avro specification](https://avro.apache.org/docs/1.11.1/specification/)
(Apache-2.0). Cases are original.

A **schema** here is a small JSON description such as `"int"` or
`["null", "string"]`. The runner hands that schema to the decoder
together with the bytes.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| 1.8 | Primitive encodings: zigzag integers, length-prefixed strings and bytes. |
| 1.11 | Same primitives, plus a **union** of `null` and `string`. |
| 1.12 | Same encodings as 1.11 for these types. |

A **zigzag** integer stores the sign in the least-significant bit so
small negative numbers stay short. A **union** is a value that may be
one of several types. The bytes start with the branch index (which
arm), then the value of that arm.

## What the cases cover

- Integers `0` and `7`, string `kelp`, empty string, bytes
- Union `[null, string]` as a string and as null
- Rejects: truncated zigzag, union branch that does not exist

Catalog: `compliance/data/avro/`. The official Apache `test_io`
encodings are vendored (`avro-io-*`, Apache-2.0). That is the same
role JSONTestSuite plays for JSON: the project’s own binary-encoding
table, stored as catalog JSON so nothing is downloaded at run time.

## Python serializer

`fastavro.schemaless_reader` with the case’s `schema`.
**Schemaless** here means “one Avro value, no object-container file
header,” not “no schema.” The schema still comes from the catalog.

JavaScript `avsc` reads the same files. These primitives have been
stable since 1.8, so the three columns should all pass on a current
`fastavro` / `avsc`.
