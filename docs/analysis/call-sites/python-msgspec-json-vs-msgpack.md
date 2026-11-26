# Python: `msgspec` JSON vs. MessagePack

This control note holds the library, C implementation, and typed `array_like=True` `msgspec.Struct` representation completely constant on the `document` ($n = 1$, `bytes` mode) payload, varying only the wire syntax (`msgspec.json` vs. `msgspec.msgpack`). It isolates pure text-versus-binary token cost after field names and Python dictionary overhead have already been removed.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=python&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=msgspec&ser=msgspec&ser=msgspec-msgpack#compare) · [Python overview](../../python/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `msgspec` (JSON) | `msgspec-msgpack` (MessagePack) |
|---|---|---|
| Standard | `json` (positional array encoding) | `msgpack` (positional array encoding) |
| Encoded size (`document`, $n = 1$) | **192 B** | **129 B** (−63 B) |
| In-memory representation | C-backed `msgspec.Struct(array_like=True)` (built in untimed `prepare_data`) | Identical `msgspec.Struct(array_like=True)` |
| Field names on wire | None (omitted by `array_like=True`) | None (omitted by `array_like=True`) |
| Primary wire difference | Brackets, commas, quotes, ASCII decimal integers | 1-byte array/string headers and binary integers |

## Timed Call Sites

Both adapters inherit `_MsgspecStructSerializer` in `python/src/benchmark/serializers/json_msgspec.py` and invoke `self._encoder.encode(obj)` and `self._decoder.decode(data)` on the identical C struct class generated with `array_like=True`:

```python
_STRUCT_TYPES[cls] = msgspec.defstruct(
    f"Msgspec{cls.__name__}",
    struct_fields,
    module=__name__,
    array_like=True,
)

class MsgspecSerializer(_MsgspecStructSerializer):
    def _make_encoder(self) -> msgspec.json.Encoder: return msgspec.json.Encoder()
    def _make_decoder(self, typ: Any) -> msgspec.json.Decoder: return msgspec.json.Decoder(type=typ)

class MsgspecMessagePackSerializer(_MsgspecStructSerializer):
    def _make_encoder(self) -> msgspec.msgpack.Encoder: return msgspec.msgpack.Encoder()
    def _make_decoder(self, typ: Any) -> msgspec.msgpack.Decoder: return msgspec.msgpack.Decoder(type=typ)
```

## Mechanistic Analysis and Scope Limits

1. **Where the 63-byte delta comes from ($192 - 129 = 63\text{ B}$):** Because `array_like=True` already removes all field-name keys from both outputs (reducing JSON from `orjson`'s 448 B down to 192 B), the remaining 63 bytes represent pure text-syntax overhead: `[` / `]` brackets, `,` separators, `"` string quotes across ten strings, and multi-digit ASCII integers versus compact MessagePack type-tagged headers and binary integers.
2. **Isolating layout vs. wire syntax:** Comparing this control pair against [4.8 Python: `msgspec-msgpack` vs. `orjson`](../../theory/401/python-msgspec-vs-orjson.md) decomposes the speedup over untyped JSON into two distinct parts: *(a)* typed fixed-slot `Struct` decoding vs. dynamic Python `dict` allocation + key hashing, and *(b)* compact binary token parsing vs. JSON delimiter scanning and decimal conversion ([2.3 Encode and decode cost](../../theory/201/encode-decode-cost.md)).
3. **Positional coupling:** Using `array_like=True` achieves compact payloads in both JSON and MessagePack at the cost of strict positional field coupling across producer and consumer. For equal-size named JSON across two libraries, see [Python: `orjson` vs. stdlib `json`](python-orjson-vs-json.md).
