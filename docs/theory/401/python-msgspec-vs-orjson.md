# Python: why msgspec-msgpack outruns orjson on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **msgspec-msgpack** finishes slightly more encode-and-decode cycles per second than **orjson**, and it writes a message about **3.5 times smaller**. Both libraries are native extensions (C and Rust). Both leave the Python interpreter for the inner loop. A results table therefore cannot tell you *which lines of code* create the gap.

This page compares the two timed call sites in this repository and the layouts they emit. After reading it you should be able to say why orjson can still *encode* faster, why msgspec-msgpack *decodes* faster, and why the PyPI `msgpack` package is far slower even though it writes MessagePack as well.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=python&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=orjson&ser=msgspec-msgpack&ser=orjson#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Python overview](../../python/)

## Short answer

msgspec-msgpack completes more encode-and-decode cycles per second than orjson (272 thousand versus 242 thousand). We can see that in the table. It is faster on the total because it encodes a **typed, positional record**, not a dictionary of named fields.

1. In untimed `prepare_data`, the runner converts the shared dataclass into a `msgspec.Struct` built with `array_like=True`. Encode then writes a MessagePack **array** of values. Field names never appear.
2. orjson is given a **plain Python dictionary**. Encode writes a JSON **object**. Every key (`"id"`, `"sku"`, `"price_minor"`, …) is copied on every message. Decode allocates nested dictionaries.
3. orjson’s Rust encoder is so fast that it still *writes* 448 bytes of JSON in less time than msgspec writes 129 bytes of MessagePack. msgspec is faster on **decode** and smaller on **size**, and therefore faster on total cycles.

| | msgspec-msgpack 0.21.1 | orjson 3.11.9 | PyPI msgpack 1.2.1 |
|--|------------------------|---------------|---------------------|
| Mean encode + decode, document, *n* = 1 | **272 thousand / s** | 242 thousand / s | 113 thousand / s |
| Encode | 1.73 µs | **1.62 µs** | 4.17 µs |
| Decode | **1.95 µs** | 2.50 µs | 4.72 µs |
| Encoded size | **129 B** | 448 B | 325 B |

orjson has the shorter encode time. msgspec-msgpack has the smaller message and the shorter total time.

## The two timed call sites

**msgspec-msgpack** (`python/src/benchmark/serializers/json_msgspec.py`) builds one encoder and one typed decoder. Conversion to a Struct is untimed `prepare_data`:

```python
# Struct types are generated once, with array_like=True (positional).
_STRUCT_TYPES[cls] = msgspec.defstruct(
    f"Msgspec{cls.__name__}",
    struct_fields,
    module=__name__,
    array_like=True,
)

def serialize_bytes(self, obj: Any) -> bytes:
    return self._encoder.encode(obj)

def deserialize_bytes(self, data: bytes) -> Any:
    return self._decoder.decode(data)
```

The MessagePack subclass only swaps the encoder class:

```python
class MsgspecMessagePackSerializer(_MsgspecStructSerializer):
    codec_name = "msgspec-msgpack"

    def _make_encoder(self) -> msgspec.msgpack.Encoder:
        return msgspec.msgpack.Encoder()

    def _make_decoder(self, typ: Any) -> msgspec.msgpack.Decoder:
        return msgspec.msgpack.Decoder(type=typ)
```

**orjson** converts the dataclass to a dictionary (untimed) and then calls the Rust extension:

```python
# python/src/benchmark/serializers/json_orjson.py
def prepare_data(self, obj, test_data_name, test_data_type):
    return to_dict(obj)

def serialize_bytes(self, obj):
    return orjson.dumps(obj)

def deserialize_bytes(self, data):
    return orjson.loads(data)
```

So the timed calls do **not** include “dataclass to Struct” or “dataclass to dict.” They include only encode and decode of the library-native value.

## What the bytes look like

A document in this suite is an identifier, a status, a small metadata record, and eight line items (`children: 8` in the catalog). Conceptually:

```text
Document
  id, status
  meta: { region, version }
  items: [ { sku, qty, price_minor }, … eight times ]
```

**orjson** emits a JSON object. Every name is text:

```text
{"id":"…","status":1,"meta":{"region":"…","version":1},
 "items":[{"sku":"…","qty":2,"price_minor":300}, …]}
```

448 bytes. The letters of `"price_minor"` appear eight times.

**msgspec-msgpack** with `array_like=True` emits a MessagePack array in field order:

```text
[ id, status, [ region, version ], [ [ sku, qty, price_minor ], … ] ]
```

129 bytes. The names live in the Struct type, which the decoder already has.

That is the same *idea* as Protocol Buffers field numbers and Avro schema order, taught in [self-describing versus schema-dependent](../201/self-describing-vs-schema-dependent.md). Jim Crist-Harif’s **msgspec** (early 2020s) applied it to Python by generating a compact C type whose fields are slots, not a hash table.

**orjson** (ijl, late 2010s) applied the other idea: keep JSON, but write and parse it in Rust, examining many characters at once. That is the simdjson tradition of Geoff Langdale and Daniel Lemire (2018–2019), brought into CPython as a single `dumps` / `loads` pair.

## Why orjson can encode faster

Writing 448 bytes of JSON in 1.62 µs, versus 129 bytes of MessagePack in 1.73 µs, looks surprising until you look at the inner loop.

orjson’s `dumps` is a Rust function that walks a Python dictionary and writes UTF-8 into a byte buffer. There is no intermediate Python `str`. The standard library, by contrast, builds a Unicode string and then encodes it:

```python
# python/src/benchmark/serializers/json_stdlib.py (not the faster library — the baseline)
return json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
```

That extra `str` plus a new encoder object is why stdlib JSON sits near 47 thousand cycles per second on the same fixture.

msgspec still has to walk eight nested Structs and emit MessagePack type codes. The C core (`msgspec._core`) is fast. It is not faster *per byte written* than orjson’s JSON writer on this small document. Encode is therefore a near tie, with orjson slightly ahead.

## Why msgspec-msgpack decodes faster

Decode is where the typed layout pays.

msgspec’s `Decoder(type=MsgspecDocument)` already knows there are four slots, that slot 3 is a list of items, and that each item has three slots. The C decoder fills those slots. It does not hash `"sku"`. It does not allocate a Python `dict` per line item.

orjson’s `loads` has no schema. It must:

1. scan 448 bytes of JSON;
2. allocate a dictionary for the document, one for `meta`, and one per item;
3. intern and hash every key.

A key cache in orjson keeps the third step cheap. It cannot avoid the dictionaries. That is the 2.50 µs versus 1.95 µs.

## Why PyPI msgpack is not in the same race

The `msgpack` wrapper also converts to a dictionary and then calls a C packer:

```python
# python/src/benchmark/serializers/binary_msgpack.py
return self._packer.pack(obj)          # encode a dict
return msgpack.unpackb(data, ...)      # decode to a dict
```

The encoding is MessagePack, but the **layout** is a map with string keys (325 bytes), not a positional array (129 bytes). Decode is generic. You pay binary type codes *and* key hashing, and you still allocate dictionaries. That is why this MessagePack row is 2.4 times slower than msgspec-msgpack on this fixture.

## What you give up

| Axis | msgspec-msgpack as timed here | orjson as timed here |
|------|-------------------------------|----------------------|
| Public readability | No | Yes (JSON) |
| Need a shared field order | Yes | No |
| Encode of this document | Slightly slower | Slightly faster |
| Decode of this document | Faster (typed slots) | Slower (dictionaries) |
| Size | 129 B | 448 B |
| Other languages | MessagePack arrays are readable if they share the order | JSON is universal |

The wrapper is honest about the model: it measures “an application written with msgspec Structs,” not “msgspec encoding a dataclass.” If your service only has dictionaries, orjson is the closer comparison, and JSON size is the price of that flexibility.

## History, in one paragraph

JSON became the web default because [Douglas Crockford](https://en.wikipedia.org/wiki/Douglas_Crockford) extracted an encoding browsers already used (early 2000s). MessagePack ([Sadayuki Furuhashi](https://en.wikipedia.org/wiki/Sadayuki_Furuhashi), 2008) kept that data model and dropped decimal text. msgspec’s `array_like` step is older still: it is the packed record — names in the contract, values on the wire — that [Serialization 101](../101/historical_perspective.md) traces from COBOL through Protocol Buffers and Avro. orjson is the other historical thread: keep the popular encoding, spend engineering on the implementation.

Related control experiments: [msgspec JSON versus MessagePack](python-msgspec-json-vs-msgpack.md) (same library, two encodings) and [orjson versus stdlib json](python-orjson-vs-json.md) (same JSON, two libraries).

## Self-check

1. Why is msgspec *JSON* (192 B, 247 thousand / s on this fixture) smaller than orjson but larger than msgspec-msgpack?
2. Name one change to the orjson wrapper that would *not* be a fair comparison (hint: moving `to_dict` into the timed `serialize` call).
3. Why does beating PyPI msgpack not prove that “msgspec’s C is 2.4 times faster than msgpack’s C”?
