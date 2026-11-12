# AMF3

AMF3 is the compact Action Message Format from later Flash players. It adds a U29 integer, and tables for strings, objects, and traits. A small integer is not stored as an eight-byte double.

The specification is Adobe's AMF 3 file-format PDF. The original Adobe wiki attachment is offline. The same PDF is at [amf3-file-format-spec.pdf](https://github.com/deathmemory/AMF3/blob/master/amf3-file-format-spec.pdf).

There is no OSI-licensed official test corpus. Cases are original (names `kelp` and `harbor`). The marker bytes are the type table in that PDF.

## What the cases cover

- Null, false, true
- U29 integer 7 and double 1.5
- String `kelp` and the empty string
- Dense array `[1, 2]`
- Dynamic anonymous objects `{n: 7}` and `{harbor: kelp}`
- Rejects: empty buffer, an integer marker without a U29, an array count without its values, marker `0xFF`

Catalog: `compliance/data/amf3/spec.json`. Inputs are hex.

## Serializers

| Language | Serializer | Decode |
|----------|------------|--------|
| Python | `py3amf-amf3` | `pyamf.decode` with encoding AMF3 |
| JavaScript | `biorate-amf` | `decode` |

AMF0 and AMF3 are separate standards. An AMF0 library is not placed on this column.

On this corpus, `py3amf-amf3` passes every case. `biorate-amf` treats marker `0xFF` as undefined instead of rejecting it.

Pass/fail cells are on the [Dashboard → Compliance](../dashboard/index.html#compliance/python/py3amf-amf3/amf3) view, standard **AMF3**, column **AMF3**.
