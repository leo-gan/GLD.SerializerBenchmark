# C: why custom-binary outruns the UBJSON envelope on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, the C entry named **custom-binary** finishes about **1.4 times** as many encode-and-decode cycles per second as **ubj**, and it writes 37 fewer bytes. Both paths are ordinary C. There is no garbage collector and no visitor framework. The gap is visible in a few dozen lines.

This page places those lines side by side. After reading it you should be able to say what extra stores the UBJSON wrapper performs, and why that wrapper exists at all.

Numbers are from the committed C **Results** snapshot. See [C Results](../../c/results.md).

## Short answer

**ubj does not use a third-party UBJSON library.** It writes the *same* packed record that custom-binary writes, then wraps that record in a small UBJSON map with two keys, `"kind"` and `"payload"`. Custom-binary skips the wrap. That is the entire race.

| | custom-binary | ubj |
|--|---------------|-----|
| Mean encode + decode, document, *n* = 1 | **3.78 million / s** | 2.62 million / s |
| Encode | **157 ns** | 239 ns |
| Decode | **108 ns** | 143 ns |
| Encoded size | **196 B** | 233 B |

196 + 37 = 233. The 37 extra bytes are the envelope. The extra time is a second copy plus type tags and big-endian integers.

## The winning encode: copy fields in order

`c/src/serializers/ser_custom_binary.c` is a one-function wrapper:

```c
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    return bin_write_fixture(fx, buf, cap, ol);
}
```

`bin_write_fixture` in `c/src/ser_common.h` writes a kind byte and then the document fields with `memcpy`. Strings carry a two-byte little-endian length. There are no field names.

```c
/* c/src/ser_common.h — document case (abbreviated) */
case TD_DOCUMENT: {
    const document_t *d = &fx->document;
    if (bin_wr_str(buf, cap, &o, d->id)) return -1;
    BIN_WR_I32(buf, cap, &o, d->status);
    if (bin_wr_str(buf, cap, &o, d->meta.region)) return -1;
    BIN_WR_I32(buf, cap, &o, d->meta.version);
    BIN_WR_I32(buf, cap, &o, d->item_count);
    for (int i = 0; i < d->item_count; i++) {
        if (bin_wr_str(buf, cap, &o, d->items[i].sku)) return -1;
        BIN_WR_I32(buf, cap, &o, d->items[i].qty);
        BIN_WR_I64(buf, cap, &o, d->items[i].price_minor);
    }
}
```

An `i32` is four host bytes:

```c
#define BIN_WR_I32(buf, cap, o, v) do { \
    if (*(o) + 4 > (cap)) return -1; \
    int32_t _v = (v); memcpy((buf) + *(o), &_v, 4); *(o) += 4; \
} while (0)
```

Decode is the inverse into a `document_t` that already contains a fixed array of items (`items[V2_MAX_CHILDREN]`). There is no heap allocation on this path.

**History.** This is the packed record of [Serialization 101](../101/historical_perspective.md): declare the order and the widths, then copy. Sun’s XDR (1987) did the same with big-endian integers and alignment. The C baseline here uses host byte order and two-byte lengths because the runner and the reader are the same process. It is a measurement baseline, not a public contract.

## The runner-up: the same bytes, then an envelope

`c/src/serializers/ser_ubj.c` first calls that same function into a 64 KiB stack buffer, then writes a UBJSON object:

```c
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    uint8_t raw[65536]; size_t n = 0;
    if (bin_write_fixture(fx, raw, sizeof raw, &n)) return -1;
    uint8_t *p = buf, *end = buf + cap;
    if (w_char(&p, end, '{')) return -1;
    if (w_key(&p, end, "kind") || w_i32(&p, end, (int32_t)fx->kind)) return -1;
    if (w_key(&p, end, "payload") || w_bytes(&p, end, raw, n)) return -1;
    if (w_char(&p, end, '}')) return -1;
    *ol = (size_t)(p - buf);
    return 0;
}
```

A UBJSON integer is a type letter plus a **big-endian** four-byte value:

```c
static int w_i32(uint8_t **p, uint8_t *end, int32_t v) {
    if (w_char(p, end, 'l')) return -1;   /* type tag: int32 */
    uint32_t uv = (uint32_t)v;
    (*p)[0] = (uint8_t)((uv >> 24) & 0xff);
    (*p)[1] = (uint8_t)((uv >> 16) & 0xff);
    (*p)[2] = (uint8_t)((uv >> 8) & 0xff);
    (*p)[3] = (uint8_t)(uv & 0xff);
    *p += 4;
    return 0;
}
```

A key is that integer (the length) plus the letters of the name. The payload is a typed byte array: `[ $ U #` plus a length plus the 196 inner bytes.

## Side-by-side: where the 37 bytes and the extra nanoseconds go

| Extra work in ubj | What the CPU does |
|-------------------|-------------------|
| First `bin_write_fixture` into `raw[65536]` | The *entire* winning encode, before the envelope starts |
| `{` `"kind"` integer `"payload"` array `}` | Type letters, two English keys, big-endian lengths |
| `memcpy` of the 196-byte payload into the envelope | A second copy of every field |
| Decode: scan keys with `strcmp`, then `bin_read_fixture` | The winning decode, after a parse |

On a little-endian host, custom-binary’s `memcpy` of an `i32` is one unaligned store. ubj’s `w_i32` is a type byte plus four shifts. It does that for every length in the envelope, not for the inner document fields — those were already written the fast way.

## What you give up

custom-binary is **not** an interchange format. Another language, or another C compiler with a different `int` width, cannot be assumed to read it. The kind byte is the only self-description.

ubj, even in this minimal form, is closer to a document: a reader can see that a map contains `kind` and `payload`. [UBJSON](https://ubjson.org/) (late 2000s, a binary cousin of JSON) was designed for that inspectability. The suite’s wrapper is a teaching envelope, not a full UBJSON implementation of the document fields.

If you want compactness *and* a real schema in C, look at **nanopb** and **protobuf-c** on the same Results page (154 bytes, about 1.3 million cycles per second). Those paths are compared as engines in [nanopb versus protobuf-c](protobuf-c-nanopb-compare.md). They lose the stopwatch to custom-binary because they write tags and variable-length integers instead of host `memcpy`. They win as a contract.

## Self-check

1. Count the envelope: `{` + key `kind` + int32 + key `payload` + typed array header + 196 payload bytes + `}`. Why is the total 233, not “196 plus a few”?
2. Why would switching `w_i32` to `memcpy` of a little-endian value *not* close most of the gap?
3. Name one reason a production service should still prefer nanopb to custom-binary.
