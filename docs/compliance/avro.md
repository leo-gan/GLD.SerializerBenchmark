# Apache Avro

Binary encoding from the [Avro specification](https://avro.apache.org/docs/1.11.1/specification/). Apache-2.0 spec; cases are original.

## Versions

| Version | Note |
|---------|------|
| 1.8 | Primitive zigzag / string / bytes |
| 1.11 | Same primitives plus `[null, string]` unions |
| 1.12 | Same as 1.11 for these encodings |

## Python serializer

`fastavro.schemaless_reader` with the case `schema` (`int`, `string`, union list, …).

Catalog: `compliance/data/avro/`.
