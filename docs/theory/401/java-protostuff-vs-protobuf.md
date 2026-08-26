# Java: why Protostuff outruns protobuf-java on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **Protostuff** and **protobuf-java** write the **same number of bytes** (155). Protostuff still finishes more encode-and-decode cycles per second. When two libraries emit the same size, the gap cannot be “a more compact encoding.” It has to be the object they build and the path they take to build it.

This page compares the two timed wrappers and the write/parse loops they call.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=java&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protostuff&ser=protostuff&ser=protobuf#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Java overview](../../java/)

## Short answer

Protostuff completes more encode-and-decode cycles per second than protobuf-java (59 thousand versus 36 thousand). We can see that in the table. Both write 155 bytes, so size cannot explain the difference.

**Encode:** protobuf-java is often *faster*. The runner converts the domain object to a generated message in untimed `prepare`, then times `toByteArray()` on that prepared message.

**Decode:** Protostuff is much faster. It allocates a plain suite `Document` with public fields and fills those fields. protobuf-java’s `parseFrom` builds an immutable generated graph (builders, bit fields, UTF-8 checks). The runner does **not** time the later copy back to the domain type.

Protostuff has the higher total cycle rate because decode dominates.

| | Protostuff | protobuf-java | jsoniter |
|--|------------|---------------|----------|
| Mean encode + decode, document, *n* = 1 | **59 thousand / s** | 36 thousand / s | 49 thousand / s |
| Encoded size | **155 B** | **155 B** | 440 B |
| Timed encode input | Domain POJO | Prepared generated message | Domain POJO |
| Timed decode output | Domain POJO | Generated message | Domain POJO |

jsoniter is second on this fixture because a generated JSON encoder is fast — and then it writes 440 bytes of names. It falls behind as the payload grows.

## The two timed call sites

**Protostuff** (`java/src/main/java/benchmark/serializers/ProtostuffSer.java`) caches a `RuntimeSchema` and a `LinkedBuffer`:

```java
public void prepare(Fixture fx) {
    schema = (Schema<Object>) (Schema<?>) RuntimeSchema.getSchema(elementClass);
    buffer.clear();
}
public byte[] serializeBytes(Fixture fx) {
    buffer.clear();
    return ProtostuffIOUtil.toByteArray(fx.value, schema, buffer);
}
public Object deserializeBytes(byte[] data) {
    Object msg = schema.newMessage();
    ProtostuffIOUtil.mergeFrom(data, msg, schema);
    return msg;
}
```

**protobuf-java** (`java/src/main/java/benchmark/serializers/ProtobufSer.java`) does the domain-to-proto mapping in untimed `prepare`:

```java
public void prepare(Fixture fx) {
    prepared = toProto(fx);
    parser = prepared.getParserForType();
}
public byte[] serializeBytes(Fixture fx) {
    return prepared.toByteArray();
}
public Object deserializeBytes(byte[] data) {
    return parser.parseFrom(data);
}
```

There is no `Message.clear()` / reuse of a single builder. Each decode allocates a new generated message.

## Why the sizes match

The suite `.proto` numbers document fields `id = 1`, `status = 2`, `meta = 3`, `items = 4`. Protostuff’s `RuntimeSchema.createFrom` assigns field numbers in **declaration order**, which on `benchmark.model.v2.Document` is the same order. Both write Protocol Buffers field numbers and variable-length integers.

The wrapper uses `ProtostuffIOUtil` (Protostuff’s own grouping for nested messages), not `ProtobufIOUtil`. For these small nested lengths a group end-byte and a length prefix happen to occupy one byte each, so the totals land on 155.

Generated protobuf write (length-delimited nested messages):

```java
// target/generated-sources/.../Document.java
public void writeTo(CodedOutputStream output) {
    if (!isStringEmpty(id_)) { writeString(output, 1, id_); }
    if (status_ != 0) { output.writeInt32(2, status_); }
    if ((bitField0_ & 1) != 0) { output.writeMessage(3, getMeta()); }
    for (int i = 0; i < items_.size(); i++) {
        output.writeMessage(4, items_.get(i));
    }
}
```

Protostuff write is a cached field list:

```java
// RuntimeSchema.writeTo
public final void writeTo(Output output, T message) {
    for (Field<T> f : getFields())
        f.writeTo(output, message);
}
```

## Why encode favours protobuf-java here

`toByteArray()` on a prepared immutable message uses a memoized size and writes once into `new byte[size]` (`AbstractMessageLite`). Protostuff must walk public fields of a live POJO through runtime accessors, even with a cached schema. The `LinkedBuffer` avoids some allocation; it does not make the walk cheaper than a generated `writeTo`.

So if you only looked at encode nanoseconds, you might rank protobuf-java first. The suite reports encode **plus** decode.

## Why decode favours Protostuff

Protostuff’s `newMessage()` is a plain `new Document()`. `mergeFrom` writes `id`, `status`, `meta`, and `items` as ordinary Java fields.

protobuf-java’s `parseFrom` constructs generated types. Those types track presence bits, validate UTF-8, and keep unknown fields. They are the right objects for a long-lived public API. They are heavier than a POJO when all you need is the suite’s fidelity check.

The runner copies protobuf messages back to domain objects **after** the timed decode (`toDomain`). The decode gap is therefore still codec work, not the mapping.

**History.** Protocol Buffers (Google, open-sourced 2008) generated the immutable message class so that many languages would share one contract. [Protostuff](https://github.com/protostuff/protostuff) (David Yu and contributors, late 2000s) asked a different question: can we write a Protocol Buffers byte stream from an existing POJO, without `protoc`? `RuntimeSchema` is that answer. The speed you see is “fill the object you already have,” not “a denser encoding.”

## What you give up

Protostuff’s runtime schema follows Java declaration order. A `.proto` that numbers fields differently will not interoperate. The official Java runtime follows the `.proto` file and the published evolution rules. If the bytes leave this process, protobuf-java is the contract. If the bytes stay inside a JVM cache, Protostuff’s POJO path is why it is faster on this fixture.

## Self-check

1. Why is equal size evidence that the encoding is not the speed story?
2. Which library would pull ahead if the runner timed `toProto` + `toByteArray` together?
3. Why is jsoniter faster than protobuf-java on this one-instance document and still the wrong library to copy into a multi-language log?
