# Mojo: EmberJson vs mojo-avro

## Why this article exists

Mojo has a widely used **JSON** library (EmberJson) and a native **Avro** library (`leo-gan/gld-avro`). They do not write the same bytes. This page opens both timed wrappers on the suite **document** fixture (one shop order: an id, a status, and eight line items).

[Open this slice on the Dashboard](../../dashboard/?lang=mojo&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=EmberJson&ser=EmberJson&ser=mojo-avro#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Mojo overview](../../mojo/)

## The two timed call sites

**EmberJson** (`mojo/src/bench/emberjson_ser.mojo`) uses official reflection serde:

```mojo
var text = serialize(document)
var back = deserialize[Document](text)
```

**mojo-avro** (`mojo/src/bench/avro_ser.mojo`) times the official `AvroDatum` path:

```mojo
var buf = encode(document)
var back = decode[Document](buf)
```

Both rows start from the same suite `Document` struct. EmberJson writes named JSON text. Avro writes the binary datum (field order from the schema, no field names on the wire). Stream mode is not claimed for either row.

## An L1 slice (document, n=1, bytes)

One Linux x86_64 session, warmup dropped, nine remaining trials. Sizes are exact for this sample. Times are median total serialize+deserialize.

| Serializer | Size | Median total |
|------------|-----:|-------------:|
| EmberJson | 452 B | 2.4 µs |
| mojo-avro | 118 B | 1.5 µs |

Avro is smaller because it does not write key strings. The time gap on this tiny record is small; a different machine or a later Mojo compiler can move it. Read the Dashboard similar / close sets before you quote a ranking.

## What this does not claim

It does not claim Avro is always faster than JSON in Mojo. It does not compare these times to Python `fastavro` or Rust `serde_avro_fast`. Cross-language times are not one contest.

## Self-check

1. Why can Avro be about one quarter the size of EmberJson on the same struct?
2. Which row writes field names into the payload?
3. Why is stream mode missing from both rows?
