# C#: why BinaryPack outruns Bond Fast on Document

## Why this article exists

On this suite’s **document** fixture, one instance, **BinaryPack** finishes more encode-and-decode cycles per second than **Microsoft Bond Fast**. Both omit JSON field names. Both compile a specialized writer once. The remaining difference is what that writer *puts on the wire* and how the runner calls it.

This page compares the two timed wrappers and the library code they invoke. After reading it you should be able to point at Bond’s per-field type-and-identifier prefix and at BinaryPack’s positional stores.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking. The C# “string” path (canonical `mode=bytes`) Base64-encodes binary codecs; compare ranks, not raw byte sizes against other languages.

[Open this slice on the Dashboard](../../dashboard/?lang=csharp&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=BinaryPack&ser=BinaryPack&ser=MS%20Bond%20Fast#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [C# overview](../../c-sharp/)

## Short answer

BinaryPack emits **raw fields in declaration order**. Bond Fast emits **a type byte and a 16-bit field identifier in front of every value**. Both specialize the encode function ahead of time. Bond pays extra stores (and extra reads) on every field in exchange for a skip rule: a reader can ignore an unknown identifier.

| | BinaryPack | Bond Fast |
|--|------------|-----------|
| Mean encode + decode, document, *n* = 1 (string path) | **about 190–210 thousand / s** | about 160–190 thousand / s |
| Wire idea | Positional, no identifiers | Tagged: type + id + value |
| Specialization | Dynamic IL, once per `T` | Expression trees, once per type |
| Evolution | Breaks if you reorder fields | Unknown ids can be skipped |

## The two timed call sites

**BinaryPack** binds a closed generic once and, on the clock, serializes then Base64-encodes (`c-sharp/src/Serializers/BinaryPackSerializerSer.cs`):

```csharp
public override string Serialize(object serializable)
    => Convert.ToBase64String(_serBytes(serializable));
```

`_serBytes` is `BinaryConverter.Serialize<T>` for the prepared `T`.

**Bond Fast** builds `Serializer<FastBinaryWriter<OutputBuffer>>` once, then allocates a 2 KiB `OutputBuffer` on every encode (`c-sharp/src/Serializers/BondFastSerializer.cs`):

```csharp
public override string Serialize(object serializable)
{
    Ensure();
    var output = new OutputBuffer(2 * 1024);
    _serializer.Serialize(serializable, new FastBinaryWriter<OutputBuffer>(output));
    return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
}
```

Both pay Base64. That cost is shared. It does not explain the rank.

## What BinaryPack generates

[BinaryPack](https://github.com/Sergio0694/BinaryPack) (Sergio Pedri) emits IL for `ObjectProcessor<T>`. Unmanaged members become a store of the bits. There is no field number.

```csharp
// ObjectProcessor<T> — conceptual form of the generated write
// writer.Write(obj.Property);
il.EmitLoadArgument(Arguments.Write.RefBinaryWriter);
il.EmitLoadArgumentForMemberRead(Arguments.Write.T, memberInfo);
il.EmitReadMember(memberInfo);
il.EmitCall(KnownMembers.BinaryWriter.WriteT(memberInfo.GetMemberType()));
```

The public entry constructs a pooled writer and copies the span out (`BinaryConverter.Serialize<T>`). After the first call, encode is a specialized delegate, not reflection.

The README is explicit: the format is **not** version-resilient. That is the Speedy / Bitsery / custom-binary idea in a .NET setting.

## What Bond Fast writes

[Microsoft Bond](https://github.com/microsoft/bond) (open-sourced 2015, after internal use at Microsoft) is a schema-driven stack in the Protocol Buffers family. **Fast binary** is the simpler of Bond’s two binary protocols: little-endian values, no variable-length integers. Compact binary adds those. This runner uses Fast.

Every field on the wire is:

```text
.------.----.----------.
| type | id |  value   |
```

The writer is three stores before the payload:

```csharp
// cs/src/core/protocols/FastBinary.cs
public void WriteFieldBegin(BondDataType type, ushort id, Metadata metadata)
{
    output.WriteUInt8((byte) type);
    output.WriteUInt16(id);
}
```

The serializer itself is specialized. `Serializer<W>` compiles an `Action<object, W>` from expression trees (`cs/src/core/Serializer.cs`). The runner skips Bond’s code generator (`BondSkipCodegen=true`) and uses that runtime compile. So Bond is *not* reflecting on every call. It is still writing three extra bytes per field, and it still allocates a fresh `OutputBuffer` in this wrapper.

**History.** Bond exists because Microsoft needed a schema that many languages could share, with a defined way to add fields. The type-and-id prefix is the same pressure that produced ASN.1 tags in 1984 and Protocol Buffers field numbers in the 2000s. BinaryPack exists because some .NET services only ever talk to themselves and want the processor to store, not to tag.

## Side-by-side: one `int` field

| Step | BinaryPack | Bond Fast |
|------|------------|-----------|
| How the field is found | Generated IL reads the property | Compiled action reads the property |
| Bytes before the value | None | 1 (type) + 2 (id) |
| The value | 4 bytes, little-endian | 4 bytes, little-endian |
| Unknown-field rule | None | Reader can skip by type |

Eight line items, each with three fields, plus the document header: the tag tax is tens of bytes and a comparable number of extra stores.

## Honesty

1. **Base64 is on the clock** for both. Do not compare these sizes to Rust or C byte counts.
2. **MemoryPack** is also specialized (source-generated formatters on the models). This runner calls the non-generic `MemoryPackSerializer.Serialize(Type, object)` API, so the measured MemoryPack row is not the fastest MemoryPack path. That is why this page uses Bond Fast as the schema-driven counterpart.
3. Bond Compact would change the integer encoding. It is a different row on the Dashboard.

## Self-check

1. If you removed Base64 from both wrappers, would you expect the *rank* to change? Why or why not?
2. Why can a Bond reader skip an unknown field, and why can a BinaryPack reader not?
3. Which historical format does Bond Fast most resemble, and which does BinaryPack most resemble?
