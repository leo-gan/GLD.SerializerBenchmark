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

Tool pins: [`scripts/schemas/tool-versions.env`](../../scripts/schemas/tool-versions.env).

## Batch convention

```text
Batch_<Type> { repeated <Type> items = 1; }
```

For `data_type_instance_count == 1`, benchmark runners may use bare messages for optimal single-object APIs.
