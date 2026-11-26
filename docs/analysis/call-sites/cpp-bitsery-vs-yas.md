# C++: `Bitsery` vs. `YAS`

This note compares the C++ `bitsery` and `yas` binary adapters on the `document` ($n = 1$, `bytes` mode) payload. Both omit field names and serialize integers at fixed width; the structural differences are length-prefix encoding, archive headers, and output-buffer reuse.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=cpp&standard=custom&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=bitsery&ser=bitsery&ser=yas#compare) · [C++ overview](../../cpp/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `bitsery` | `yas` (default binary flags) |
|---|---|---|
| Standard | `custom` (explicit-schema binary) | `custom` (multi-format archive) |
| Encoded size (`document`, $n = 1$) | **190 B** | **274 B** (+84 B) |
| Archive header | None (0 B) | 7 B (`"yas"` magic + flags) |
| String / sequence length prefix | Compact varint (1 B for lengths $< 128$) | Fixed `uint64_t` (8 B per length) |
| Output buffer policy | Reused member `std::vector` (`buf_.clear()`) | Fresh 20 KiB `yas::mem_ostream` per `yas::save` |

## Timed Call Sites

**`bitsery`** (`cpp/src/serializers/ser_bitsery.cpp`) declares explicit fixed-width field sequences and writes into a cleared member vector:

```cpp
template <typename S>
void serialize(S& s, bench::DocumentItem& m) {
  s.text1b(m.sku, 256); s.value4b(m.qty); s.value8b(m.price_minor);
}
template <typename S>
void serialize(S& s, bench::Document& m) {
  s.text1b(m.id, 256); s.value4b(m.status); s.object(m.meta); s.container(m.items, 10000);
}

// Timed encode:
buf_.clear();
bitsery::Serializer<OutputAdapter> ser{OutputAdapter{buf_}};
ser.object(v);
auto written = ser.adapter().writtenBytesCount();
return {buf_.begin(), buf_.begin() + written};
```

**`yas`** (`cpp/src/serializers/ser_yas.cpp`) passes named-value tuples to `yas::save<yas::mem | yas::binary>` (in binary mode, field names are discarded at compile time, but `yas::save` constructs a new `yas::mem_ostream` reserving 20 KiB):

```cpp
constexpr auto kFlags = yas::mem | yas::binary;
auto buf = yas::save<kFlags>(YAS_OBJECT_NVP(
    "document", ("id", v.id), ("status", v.status), ("region", v.meta.region),
    ("version", v.meta.version), ("items", v.items)));
return {buf.data.get(), buf.data.get() + buf.size};
```

## Mechanistic Analysis and Scope Limits

1. **Exact 84-byte gap ($190 + 84 = 274\text{ B}$):** `document` carries 11 variable-length items (`id`, `meta.region`, the 8-element `items` vector, and 8 `sku` strings), all shorter than 128 elements. `bitsery::writeSize` encodes each length in 1 byte (11 B total), whereas YAS without `yas::compacted` writes 8-byte `uint64_t` lengths (88 B total)—a $+77\text{ B}$ difference—plus a 7-byte archive header ($77 + 7 = 84\text{ B}$).
2. **Configuration sensitivity:** Adding `yas::compacted | yas::no_header` and reusing a `yas::mem_ostream` would eliminate both the 84-byte wire delta and per-call stream construction; this suite measures each library's default binary configuration.
3. **Evolution trade-off:** Neither positional layout carries field identifiers or cross-language evolution rules. For schema-evolving C++ interchange, compare `protobuf` or `avro`; for C++ JSON wrapper auditing, see [4.12 C++: the `simdjson` wrapper](../../theory/401/cpp-simdjson-wrapper.md).
