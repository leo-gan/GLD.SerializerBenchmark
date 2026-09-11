# Protocol Buffers

Protocol Buffers (Protobuf) is not an RFC. Google documents the byte
layout at
[protobuf.dev encoding](https://protobuf.dev/programming-guides/encoding/).
A **message** is a sequence of tagged fields. Each field starts with a
key that names the field number and the wire type (varint, 64-bit,
length-delimited, or 32-bit).

This catalog does not run Google’s `conformance/` program. That
program is a live protocol between a test runner and a library, not a
static file of inputs. There is no MIT/BSD dump of those payloads we
can vendor the way we vendored JSONTestSuite. Cases here follow the
published encoding guide and the proto3 JSON mapping, with original
names (`kelp`, `harbor`).

## Versions

| Version | What changed for parsers |
|---------|--------------------------|
| proto2 | Same wire bytes as proto3 for these fields. A repeated number is stored as **one record per element** (unpacked). |
| proto3 | A repeated number is stored as **one length-delimited blob of concatenated numbers** (packed). Empty fields are omitted. |
| proto3 JSON | The official JSON mapping of the same message (`json_format`), not the binary wire. |

A **varint** is an integer that uses one byte when the value is small
and more bytes when it grows. A **packed** repeated field is a single
length-prefixed run of those varints.

## What the cases cover

- Empty message
- Varint field, length-delimited string, bool
- proto3 packed repeated integers
- proto2 unpacked repeated integers
- proto3 JSON object with the same fields
- Rejects: truncated varint, truncated string, reserved wire type 7

Catalog: `compliance/data/protobuf/`.

## Serializers

The catalog `Doc` message is four fields: `n` (int32), `s` (string),
`ok` (bool), `tags` (repeated int32). Official runtimes build that
descriptor at runtime (same trick as Python). Languages without a
dynamic descriptor API decode the same fields through the library’s
wire reader (`CodedInputStream`, `protowire`, `protobufjs.Reader`,
or the in-tree Mojo/C/C++/Zig/Swift wire helper).

| Language | Serializer | Binary | proto3 JSON |
|----------|------------|--------|-------------|
| Python | `protobuf` | `ParseFromString` | `json_format.Parse` |
| Go | `protobuf` | `proto.Unmarshal` + `dynamicpb` | `protojson` |
| Java / Kotlin | `protobuf` | `DynamicMessage.parseFrom` | `JsonFormat` |
| Rust | `prost` | `prost::Message::decode` | small proto3 JSON mapper |
| C# | `Google.Protobuf`, `protobuf-net` | `CodedInputStream` / protobuf-net | proto3 JSON mapper |
| JavaScript | `protobufjs` | `Reader` field decode | proto3 JSON mapper |
| PHP | `protobuf` | varint / length reader | proto3 JSON mapper |
| C / C++ / Swift / Zig | `protobuf-wire` | same encoding rules | proto3 JSON mapper |
| Mojo | `mojo-protobuf` | `WireReader` | EmberJson + int32 rules |

Typical catalog pattern (report-only): proto2 and proto3 binary cases
pass on official runtimes. The proto3 JSON column fails if the library
rejects a JSON form the mapping allows, or accepts one it forbids.
