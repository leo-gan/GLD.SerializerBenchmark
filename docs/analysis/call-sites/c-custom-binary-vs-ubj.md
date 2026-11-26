# C: `custom-binary` vs. `ubj`

This note inspects the C runner's `custom-binary` and `ubj` adapters on the `document` ($n = 1$, `bytes` mode) payload. Both execute in plain C11 with zero heap allocation and no garbage collector; the difference isolates the exact byte and copy cost of wrapping a packed binary record inside a minimal UBJSON envelope.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=c&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=custom-binary&ser=custom-binary&ser=ubj#compare) · [C overview](../../c/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `custom-binary` | `ubj` |
|---|---|---|
| Standard | `custom` (in-tree baseline) | `ubjson` (minimal teaching envelope) |
| Encoded size (`document`, $n = 1$) | **196 B** | **233 B** (+37 B envelope) |
| Timed boundary | `document_t` → buffer → `document_t` | `document_t` → stack buffer → UBJSON envelope → `document_t` |
| Endianness & lengths | Host little-endian `memcpy`; 2-byte LE string lengths | Big-endian 4-byte UBJSON integers for envelope metadata |
| Heap allocations | 0 (fixed `items[V2_MAX_CHILDREN]` array) | 0 (64 KiB stack scratch buffer + output buffer) |

## Timed Call Sites

**`custom-binary`** (`c/src/serializers/ser_custom_binary.c`, invoking `bin_write_fixture` in `c/src/ser_common.h`) writes a kind tag followed by fields in fixed declaration order with unaligned host-endian `memcpy`:

```c
static int ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol) {
    return bin_write_fixture(fx, buf, cap, ol);
}

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

**`ubj`** (`c/src/serializers/ser_ubj.c`) executes the **entire** `bin_write_fixture` pass into a 64 KiB stack buffer, then wraps those 196 bytes in a two-key UBJSON map (`"kind"` and `"payload"`):

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

## Mechanistic Analysis and Scope Limits

1. **Exact 37-byte overhead ($196 + 37 = 233\text{ B}$):** The UBJSON envelope adds delimiters (`{`, `}`), two length-prefixed ASCII keys (`"kind"`, `"payload"`), type markers (`'l'` for int32, `[ $ U #` for a strongly typed byte array), and big-endian 4-byte lengths (`w_i32` shifts four bytes explicitly).
2. **Double pass on encode and decode:** `ubj` strictly performs `custom-binary` plus a second `memcpy` of the 196-byte payload into the output buffer on encode, and UBJSON key scanning (`strcmp`) prior to `bin_read_fixture` on decode.
3. **Contract trade-off:** Neither adapter is a full production interchange implementation. `custom-binary` relies on host byte order and fixed field positions; `ubj` is an in-tree UBJSON framing wrapper rather than a field-by-field third-party UBJSON codec. For portable schema-driven C encoding, inspect `protobuf` (`libprotobuf`) and the runtime internals in [4.5 C: `protobuf-c`](../../theory/401/protobuf-c-protobuf-c.md) and [4.6 C: `nanopb` vs. `protobuf-c`](../../theory/401/protobuf-c-nanopb-compare.md).
