# C++: why Bitsery outruns YAS on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **Bitsery** finishes about **1.3 times** as many encode-and-decode cycles per second as **YAS**, and it writes 84 fewer bytes. Both libraries omit field names. Both store integers at fixed width. The gap is not “binary versus text.” It is how each library writes *lengths*, whether it emits a header, and whether it reuses a buffer.

This page compares the two C++ call sites and the library code they invoke.

Numbers are from the committed C++ **Results** snapshot. See [C++ Results](../../cpp/results.md).

## Short answer

Bitsery writes a positional little-endian image with **one-byte length prefixes** for short strings and lists, into a **reused** `std::vector`. YAS writes the same fields with **eight-byte lengths** and a **seven-byte archive header**, and it constructs a fresh 20 KiB stream on every encode.

| | Bitsery 5.2.4 | YAS (binary) |
|--|---------------|--------------|
| Mean encode + decode, document, *n* = 1 | **1.10 million / s** | 0.83 million / s |
| Encode | **396 ns** | 598 ns |
| Decode | **515 ns** | 601 ns |
| Encoded size | **190 B** | 274 B |

190 + 84 = 274. Eleven short lengths that Bitsery stores in one byte each cost eight bytes in YAS (11 × 7 extra) plus a seven-byte header.

## The two timed call sites

**Bitsery** (`cpp/src/serializers/ser_bitsery.cpp`) declares the layout as a sequence of fixed-width operations. There is no name in the output:

```cpp
template <typename S>
void serialize(S& s, bench::DocumentItem& m) {
  s.text1b(m.sku, 256); s.value4b(m.qty); s.value8b(m.price_minor);
}
template <typename S>
void serialize(S& s, bench::Document& m) {
  s.text1b(m.id, 256); s.value4b(m.status); s.object(m.meta); s.container(m.items, 10000);
}
```

The timed encode clears a member buffer and writes into it:

```cpp
buf_.clear();
bitsery::Serializer<OutputAdapter> ser{OutputAdapter{buf_}};
ser.object(v);
auto written = ser.adapter().writtenBytesCount();
return {buf_.begin(), buf_.begin() + written};
```

**YAS** (`cpp/src/serializers/ser_yas.cpp`) uses `YAS_OBJECT_NVP`. In binary mode the names are *not* written — they exist so the same macro can also speak JSON — but every `yas::save` builds a new stream:

```cpp
constexpr auto kFlags = yas::mem | yas::binary;
auto buf = yas::save<kFlags>(YAS_OBJECT_NVP(
    "document", ("id", v.id), ("status", v.status), ("region", v.meta.region),
    ("version", v.meta.version), ("items", v.items)));
return {buf.data.get(), buf.data.get() + buf.size};
```

Inside `yas::save` (library header `yas/serialize.hpp`) that is:

```cpp
yas::mem_ostream os;                    // default reserve: 20 KiB
yas::binary_oarchive<...> oa(os);
oa(std::forward<Types>(args)...);
return os.get_shared_buffer();
```

## What Bitsery stores

`value4b` / `value8b` copy four or eight bytes. On a little-endian host there is no swap (`bitsery/details/adapter_common.h`). A string is a **compact size** plus the characters:

```cpp
// bitsery/details/adapter_common.h
void writeSize(Writer& w, const size_t size)
{
  if (size < 0x80u) {
    w.template writeBytes<1>(static_cast<uint8_t>(size));
  } else if (size < 0x4000u) { /* two bytes */ }
    else { /* four bytes */ }
}
```

For this document every string and the items list is shorter than 128, so each count is **one byte**. Integers stay full width. There is no archive banner.

**History.** Bitsery (M. Pusz / bitsery authors, late 2010s) is a C++ take on the packed record: you state the widths in the `serialize` function, the compiler inlines them, and the adapter copies. It is closer to Speedy in Rust than to Protocol Buffers.

## What YAS stores

Without the `compacted` flag, every sequence length is a `uint64_t`:

```cpp
// yas/detail/io/binary_streams.hpp
void write_seq_size(std::size_t size) {
    const auto tsize = __YAS_SCAST(std::uint64_t, size);
    write(tsize);
}
```

Every archive also writes a seven-byte header (`"yas"` plus flags) unless `no_header` is set. The wrapper does not set that flag.

This document has eleven sizes (id, region, items, and eight SKUs). Bitsery: 11 bytes. YAS: 88 bytes. Plus 7 bytes of header. That is the 84-byte gap.

YAS (niXman, mid-2010s) is a general archive library in the Boost.Serialization tradition: one set of macros, several backends (binary, JSON, text). Generality shows up as a header, fat lengths, and a new stream object. The binary backend is not slow because it prints text. It is slower because it was built as an *archive*, not as a one-record dump.

## Side-by-side

| Step | Bitsery | YAS binary as configured here |
|------|---------|-------------------------------|
| Header | None | 7 bytes every message |
| `status` (`int32`) | 4 bytes | 4 bytes |
| Length of `id` | 1 byte if `< 128` | 8 bytes |
| Buffer | `buf_.clear()` on a member `vector` | New 20 KiB `mem_ostream` |
| Dispatch | One argument-dependent `serialize()` | `operator&` on a generated tuple of named values |

## What you give up

Bitsery’s layout is a private contract. There are no field numbers. Adding a field in the middle breaks old readers. YAS can grow into JSON with the same macros; Bitsery cannot. If you need evolution, the C++ Results page’s **protobuf** and **Avro** rows are the relevant comparison, not this pair.

A fairer YAS configuration would add `yas::compacted` and `yas::no_header`. This suite does not. The measured gap is therefore “Bitsery’s defaults versus YAS’s archive defaults,” which is how both libraries are commonly first used.

A JSON row on the same Results page is a different lesson: [what the simdjson row times](cpp-simdjson-wrapper.md).

## Self-check

1. Why does `value4b` for `qty` not explain the 84-byte size gap?
2. If every SKU were 200 characters long, which part of Bitsery’s `writeSize` would change, and would YAS change at all?
3. Name one wrapper change that would shrink YAS’s time without changing Bitsery.
