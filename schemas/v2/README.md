# Wire schemas

Canonical **wire** definitions for schema-driven serializers. Logical field meaning is in [`docs/analysis/test_data_configuration.md`](../../docs/analysis/test_data_configuration.md).

## Layout

| Path | Family |
|------|--------|
| `protobuf/benchmark_v2.proto` | Protocol Buffers (five types + batch wrappers) |

## Regenerate language artifacts

```bash
./scripts/schemas/generate-all.sh
./scripts/schemas/check-generated.sh   # CI drift check (when outputs committed)
```

Per-language scripts also exist (same `.proto`): `go/scripts/generate-protobuf.sh`, `php/scripts/generate-protobuf.sh`, `zig/scripts/generate-protobuf.sh`, Rust `build.rs` (prost). FlatBuffers / Cap’n Proto for Zig: `zig/scripts/generate-flatbuffers.sh` and `zig/scripts/generate-capnp.sh` (from `cpp/schemas/`).

Tool pins: [`scripts/schemas/tool-versions.env`](../../scripts/schemas/tool-versions.env).

## Batch convention

```text
Batch_<Type> { repeated <Type> items = 1; }
```

For `data_type_instance_count == 1`, benchmark runners may use bare messages for optimal single-object APIs.
