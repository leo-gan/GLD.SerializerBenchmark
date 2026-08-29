# Generated schema types

| Path | Source schema | Tool |
|------|---------------|------|
| `benchmark/v2.pb.zig` | `schemas/v2/protobuf/benchmark_v2.proto` | `./zig/scripts/generate-protobuf.sh` |
| `flatbuffers/benchmark.zig` + `.zon` | `cpp/schemas/benchmark.fbs` | `./zig/scripts/generate-flatbuffers.sh` |
| `capnp/benchmark.capnp.{h,cpp}` | `cpp/schemas/benchmark.capnp` | `./zig/scripts/generate-capnp.sh` |

Do not edit generated files by hand.
