# AMF0

AMF0 is the first Action Message Format, from Adobe Flash. Every number is an IEEE-754 double in network byte order. A value starts with a type marker. RTMP still uses AMF0 for commands.

The specification is [Action Message Format -- AMF 0](https://download.macromedia.com/pub/labs/amf/amf0_spec_121207.pdf) (Adobe Systems, 12 December 2007).

There is no OSI-licensed official test corpus. Cases are original (names `kelp` and `harbor`). The marker bytes are the type table in that PDF.

## What the cases cover

- Null, true, false
- Doubles 7 and 1.5
- String `kelp` and the empty string
- A strict array of two numbers
- Objects `{n: 7}` and `{harbor: kelp}`
- Rejects: empty buffer, a number marker without eight bytes, the unsupported movieclip marker `0x04`, an object that never writes the end marker, marker `0xFF`

Catalog: `compliance/data/amf0/spec.json`. Inputs are hex.

## Serializers

| Language | Serializer | Decode |
|----------|------------|--------|
| Python | `py3amf-amf0` | `pyamf.decode` with encoding AMF0 |
| Rust | `scuffle-amf0` | `from_slice` through Serde |
| Go | `go-amf0` | `Decoder.Decode` |
| Go | `gamf-amf0` | `Decoder.Decode` |

AMF0 and AMF3 are separate standards. A library that writes only AMF0 is not scored on the AMF3 column.

On this corpus, `go-amf0`, `scuffle-amf0`, and `py3amf-amf0` pass every case. `gamf-amf0` rejects the empty string. `amf-codec` accepts an object that never writes the end marker.

Pass/fail cells are on the [Dashboard → Compliance](../dashboard/index.html#compliance/python/py3amf-amf0/amf0) view, standard **AMF0**, column **AMF0**.
