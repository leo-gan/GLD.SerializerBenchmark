# C#: `BinaryPack` vs. `MS Bond Fast`

This note examines the C# `BinaryPack` and `MS Bond Fast` adapters on the `document` ($n = 1$, `bytes` mode) payload. Both compile specialized delegates ahead of time rather than using per-call reflection; the structural difference is positional storage versus per-field type-and-identifier tagging.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=csharp&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=BinaryPack&ser=BinaryPack&ser=MS%20Bond%20Fast#compare) · [C# overview](../../c-sharp/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `BinaryPack` | `MS Bond Fast` |
|---|---|---|
| Standard | `custom` (positional .NET binary) | `bond` (Fast Binary protocol) |
| Encoded size (`document`, $n = 1$, `bytes`) | **224 B** | **282 B** (+58 B) |
| Per-field framing | None (declaration order only) | 1-byte `BondDataType` + 2-byte `ushort` field ID (3 B/field) |
| Specialization | Dynamic IL (`ObjectProcessor<T>`) once per `T` | Compiled expression-tree `Action<object, W>` once per `T` |
| Buffer allocation in wrapper | Pooled writer via `BinaryConverter.Serialize<T>` | Fresh `new OutputBuffer(2 * 1024)` + `ToArray()` per encode |
| Schema evolution | Breaks on field reorder or insertion | Reader skips unknown field IDs using wire type tags |

## Timed Call Sites

**`BinaryPack`** (`c-sharp/src/Serializers/BinaryPackSerializerSer.cs`) binds a closed generic delegate to `BinaryConverter.Serialize<T>` once during initialization:

```csharp
public override byte[] SerializeBytes(object serializable)
    => _serBytes(serializable);
```

**`MS Bond Fast`** (`c-sharp/src/Serializers/BondFastSerializer.cs`) caches `Serializer<FastBinaryWriter<OutputBuffer>>` during initialization (`BondSkipCodegen=true` uses Bond's compiled expression trees), then allocates a 2 KiB output buffer on each timed encode:

```csharp
public override byte[] SerializeBytes(object serializable)
{
    var output = new OutputBuffer(2 * 1024);
    _serializer.Serialize(serializable, new FastBinaryWriter<OutputBuffer>(output));
    return output.Data.ToArray();
}
```

## Mechanistic Analysis and Scope Limits

1. **Tagging overhead (+58 B):** `FastBinaryWriter.WriteFieldBegin` writes 3 bytes (`uint8` type + `uint16` field ID) ahead of every scalar, nested struct, and list element field, plus struct-end markers. Across the `Document` header, `Meta`, and eight 3-field `DocumentItem` records, per-field framing accounts for the entire 58-byte expansion and additional write/dispatch operations.
2. **Buffer reuse asymmetry:** Unlike `BinaryPack`'s pooled writer, the `MS Bond Fast` adapter allocates a 2 KiB `OutputBuffer` on every timed encode, adding GC pressure alongside tag dispatch.
3. **Scope limits:** Historical C# snapshots emitted Base64-encoded `string` rows; current published runs time raw `bytes` payloads directly. Note also that `MS Bond Compact` adds varint integer compression (measured as a separate Dashboard row), and `MemoryPack` is called through its non-generic `Serialize(Type, object)` entry point in this runner.
