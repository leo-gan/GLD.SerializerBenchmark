# Schemas v2 (Data Model v2)

Canonical **wire** definitions for schema-driven serializers. Logical field meaning is in [`docs/analysis/data_model_v2.md`](../../docs/analysis/data_model_v2.md).

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

For `data_type_instance_count == 1`, harnesses may use bare messages for optimal single-object APIs.
