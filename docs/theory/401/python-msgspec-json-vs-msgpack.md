# Python: msgspec JSON versus msgspec-msgpack

## Why this article exists

The [msgspec-msgpack versus orjson](python-msgspec-vs-orjson.md) page compares two libraries *and* two layouts at once. A student can fairly ask: how much of that gap is MessagePack, and how much is msgspec?

This page holds the library still. Both rows use the same `array_like` Structs, the same C core, and the same untimed conversion from a dataclass. Only the encoder class changes. After reading it you should be able to say what remains when names are already gone and the implementation is already native.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=python&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=msgspec&ser=msgspec&ser=msgspec-msgpack#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Python overview](../../python/)

## Short answer

Once msgspec already writes a **positional record**, switching from JSON tokens to MessagePack tags saves about **63 bytes** and a little decode time. Encode is a near tie. JSON is even slightly faster to write. The large gap versus orjson on the previous page is therefore mostly **typed slots versus named dictionaries**, not “MessagePack is magic.”

| | msgspec JSON 0.21.1 | msgspec-msgpack 0.21.1 |
|--|---------------------|------------------------|
| Mean encode + decode | 247 thousand / s | **272 thousand / s** |
| Encode | **1.66 µs** | 1.73 µs |
| Decode | 2.39 µs | **1.95 µs** |
| Encoded size | 192 B | **129 B** |

Same Struct. Same field order. Different token language.

## The two timed call sites

Both classes share `_MsgspecStructSerializer` in `python/src/benchmark/serializers/json_msgspec.py`. The only difference is which encoder and decoder they construct:

```python
class MsgspecSerializer(_MsgspecStructSerializer):
    codec_name = "msgspec"

    def _make_encoder(self) -> msgspec.json.Encoder:
        return msgspec.json.Encoder()

    def _make_decoder(self, typ: Any) -> msgspec.json.Decoder:
        return msgspec.json.Decoder(type=typ)


class MsgspecMessagePackSerializer(_MsgspecStructSerializer):
    codec_name = "msgspec-msgpack"

    def _make_encoder(self) -> msgspec.msgpack.Encoder:
        return msgspec.msgpack.Encoder()

    def _make_decoder(self, typ: Any) -> msgspec.msgpack.Decoder:
        return msgspec.msgpack.Decoder(type=typ)
```

Timed work is `self._encoder.encode(obj)` and `self._decoder.decode(data)` in both cases. `prepare` builds a `Decoder(type=MsgspecDocument)`. `prepare_data` builds the Struct. Neither of those steps is on the clock.

The Structs are created once with `array_like=True`:

```python
_STRUCT_TYPES[cls] = msgspec.defstruct(
    f"Msgspec{cls.__name__}",
    struct_fields,
    module=__name__,
    array_like=True,
)
```

So both encodings are arrays of values, not objects of named fields.

## What the bytes look like

For a teaching record `{ id: 7, name: "Ada" }` the two positional encodings are:

```text
msgspec JSON:      [7,"Ada"]
                   5b 37 2c 22 41 64 61 22 5d     (9 bytes)

msgspec-msgpack:   array(2), 7, str "Ada"
                   92 07 a3 41 64 61              (6 bytes)
```

The letters of `"id"` and `"name"` appear in neither row. JSON still spends bytes on `[`, `,`, quotes, and the decimal digit `7`. MessagePack spends a one-byte array tag, a one-byte integer, and a one-byte string header.

On the suite document the same arithmetic scales up. Eight line items mean eight copies of quotes around every string and eight decimal integers. That is most of the 192 − 129 = 63 bytes.

**History.** JSON ([Douglas Crockford](https://en.wikipedia.org/wiki/Douglas_Crockford), early 2000s) chose characters a human can type. MessagePack ([Sadayuki Furuhashi](https://en.wikipedia.org/wiki/Sadayuki_Furuhashi), 2008) kept the JSON *data model* and replaced those characters with short binary tags. msgspec (Jim Crist-Harif, early 2020s) applied both encodings to one C Struct type. This page is that history with the library held constant. See [Historical perspective](../101/historical_perspective.md).

## Why encode does not follow size

Writing 192 bytes of JSON in 1.66 µs, versus 129 bytes of MessagePack in 1.73 µs, looks backwards. The JSON writer in msgspec is a tight C loop that emits punctuation and copies UTF-8. The MessagePack writer emits a tag per value. On a small document the tag machine is not cheaper than “write a bracket and a digit.” Size and encode time are different questions. [Encode and decode cost](../201/encode-decode-cost.md) made that distinction; here you can see it in one package.

Decode favours MessagePack because the reader does not scan for quotes or convert decimal digits. It reads a tag and a length. That is the 2.39 µs versus 1.95 µs.

## What this page is for

Use this pair when you need a **control experiment**. If you want the larger story — typed Struct versus a Python dictionary — return to [msgspec-msgpack versus orjson](python-msgspec-vs-orjson.md). If you want “same JSON bytes, two engines,” go to [orjson versus stdlib json](python-orjson-vs-json.md).

## Self-check

1. Why can you not use this pair to claim that “MessagePack is always faster to write than JSON”?
2. Draw the 63-byte gap as “punctuation and decimal digits,” not as “field names.” Where did the names already go?
3. What would you expect if `array_like=False` were set on both encoders?
