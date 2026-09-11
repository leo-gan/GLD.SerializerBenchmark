# Protocol Buffers

Not an RFC. Encoding is documented at [protobuf.dev](https://protobuf.dev/programming-guides/encoding/).

## Versions in this catalog

| Version | What it covers |
|---------|----------------|
| proto2 | Wire grammar + unpacked repeated scalars |
| proto3 | Wire grammar + packed repeated scalars |
| proto3 JSON | Official JSON mapping |

Cases are **original** (field numbers and values such as `kelp`). They are not Google’s `conformance/` runner.

## Python serializer

`google.protobuf` (`ParseFromString` / `json_format.Parse`) on a tiny dynamic `Doc` message.

Catalog: `compliance/data/protobuf/`.
