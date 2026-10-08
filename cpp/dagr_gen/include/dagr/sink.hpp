// dagr/sink.hpp — the DataSink runtime (spec/11, spec/34; spec/41 §10): stream framing,
// the record scan, the reverse span of a doubly-linked sink, record ranges and the fixed
// destination. Everything a generated `{sink}.hpp` needs beyond the graph runtime.
//
//   [LEB framing] ([LEB length][packed header]) ( [LEB type id][LEB size][body] [RLEB span]? )*
//
// Core tier: no allocation, no container. Every reader function is TOTAL (spec/41 §5): any
// bytes give an answer — a truncated or garbled tail ends the stream, it never reads
// outside the buffer.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

#include "fixed_writer.hpp"
#include "reader.hpp"

namespace dagr {

// ── Type ids ───────────────────────────────────────────────────────────────────

/// The reserved band of meta-record type ids (spec 34 §2.1): `meta_types[i]` is
/// `meta_type_id_base + i`. No payload type id reaches it.
inline constexpr std::uint64_t meta_type_id_base = 16384;
inline constexpr std::uint64_t meta_type_id_end = 32767;

/// Whether `type_id` addresses a meta record — one about the stream, not in it.
constexpr bool is_meta_type_id(std::uint64_t type_id) noexcept {
  return type_id >= meta_type_id_base && type_id <= meta_type_id_end;
}

// ── Record ranges ──────────────────────────────────────────────────────────────

/// A record's bytes, RELATIVE to the stream's records start (spec 34 §3.1, §5): `[start,
/// end)`, the trailing span of a doubly-linked sink included — so the ranges of a stream
/// tile its record region with no gap.
struct RecordRange {
  std::uint64_t type_id = 0;
  std::size_t start = 0;
  std::size_t end = 0;
};

constexpr bool operator==(const RecordRange& a, const RecordRange& b) noexcept {
  return a.type_id == b.type_id && a.start == b.start && a.end == b.end;
}
constexpr bool operator!=(const RecordRange& a, const RecordRange& b) noexcept { return !(a == b); }

/// The write observer (spec 34 §3.2): called once per appended record, meta records
/// included, in stream order, with the record's range and its exact bytes (valid for the
/// call only). A function pointer and a context, so that installing one allocates nothing.
using SinkObserver = void (*)(void* context, RecordRange range, Bytes bytes);

// ── Framing ────────────────────────────────────────────────────────────────────

/// The framing word of a sink stream: kind bit (1) set, and bit 0 when a header follows.
inline constexpr std::uint8_t sink_framing_plain = 2;
inline constexpr std::uint8_t sink_framing_with_header = 3;

/// Where a sink stream's parts are: the header block (`npos` without one) and the first
/// record.
struct SinkFrame {
  std::size_t header_at = npos;
  std::size_t records_start = 0;
};

/// Parses the framing word (and skips the header) of a sink stream. `header` says whether
/// the schema declares one: a stream that disagrees is refused — `bad_framing` for a graph
/// buffer or an unexpected header, `no_header` for a missing one. An EMPTY buffer is an
/// empty stream (a writer that never appended).
inline Result<SinkFrame> sink_frame(Bytes buf, bool header) noexcept {
  if (buf.empty()) return SinkFrame{};
  const Varint framing = read_leb(buf, 0);
  if (framing.len == 0 || (framing.value & 2u) == 0) return Status::bad_framing;
  const bool has = (framing.value & 1u) != 0;
  if (has != header) return has ? Status::bad_framing : Status::no_header;
  if (!header) return SinkFrame{npos, framing.len};
  const Varint length = read_leb(buf, framing.len);
  if (length.len == 0 || length.value > remaining(buf, framing.len + length.len)) return Status::bad_framing;
  return SinkFrame{framing.len, framing.len + length.len + static_cast<std::size_t>(length.value)};
}

// ── Records ────────────────────────────────────────────────────────────────────

/// One record of a stream, as positions: `[type id][size][body …][span?]` from `begin`;
/// `content` is the size prefix (where a record's packed accessor opens), `value` the byte
/// after it, `end` the byte after the body and `next` the next record.
struct SinkRecordAt {
  std::uint64_t type_id = 0;
  std::size_t begin = 0;
  std::size_t content = 0;
  std::size_t value = 0;
  std::size_t end = 0;
  std::size_t next = 0;
};

/// The record at `pos`, or false when none starts there: at the end of the buffer, and for
/// a tail too short to hold one (a stream cut off mid-record ends at the last whole one).
/// A doubly-linked record's trailing span is stepped over, not decoded (spec 11 §11.6).
inline bool sink_record_at(Bytes buf, std::size_t pos, bool doubly_linked, SinkRecordAt& out) noexcept {
  if (pos >= buf.size()) return false;
  const Varint tid = read_leb(buf, pos);
  if (tid.len == 0) return false;
  const std::size_t content = pos + tid.len;
  const Varint size = read_leb(buf, content);
  if (size.len == 0) return false;
  const std::size_t value = content + size.len;
  if (size.value > remaining(buf, value)) return false;
  const std::size_t end = value + static_cast<std::size_t>(size.value);
  std::size_t next = end;
  if (doubly_linked) {
    const std::size_t span = leb_length(end - pos);
    if (span > remaining(buf, end)) return false;
    next = end + span;
  }
  out = SinkRecordAt{tid.value, pos, content, value, end, next};
  return true;
}

/// The trailing span whose last byte is at `end - 1` (spec 11 §11.4: the LEB bytes in
/// reverse, so a right-to-left read stops at the leading terminator), never reading below
/// `floor`. `len == 0` when there is none: nothing between `floor` and `end`, no
/// terminator, or more than ten bytes.
inline Varint read_rleb_backward(Bytes buf, std::size_t floor, std::size_t end) noexcept {
  if (end > buf.size() || end <= floor) return Varint{0, 0};
  std::uint64_t value = 0;
  unsigned shift = 0;
  std::size_t pos = end;
  while (pos > floor && shift <= 63) {
    pos--;
    const std::uint8_t b = buf.data()[pos];
    value |= static_cast<std::uint64_t>(b & 0x7fu) << shift;
    if ((b & 0x80u) == 0) return Varint{value, end - pos};
    shift += 7;
  }
  return Varint{0, 0};
}

/// The record that ENDS at `end` in a doubly-linked stream, or false when the span there
/// does not lead to a whole record at or after `floor` (the records start).
inline bool sink_record_before(Bytes buf, std::size_t floor, std::size_t end, SinkRecordAt& out) noexcept {
  const Varint span = read_rleb_backward(buf, floor, end);
  if (span.len == 0) return false;
  const std::size_t body_end = end - span.len;
  if (span.value > body_end - floor) return false;
  const std::size_t begin = body_end - static_cast<std::size_t>(span.value);
  SinkRecordAt rec;
  if (!sink_record_at(buf, begin, true, rec) || rec.end != body_end || rec.next != end) return false;
  out = rec;
  return true;
}

/// `buf[from, to)`, clamped to the buffer: never a view outside it.
inline Bytes sink_slice(Bytes buf, std::size_t from, std::size_t to) noexcept {
  if (from > buf.size()) from = buf.size();
  if (to > buf.size()) to = buf.size();
  if (to < from) to = from;
  return Bytes(buf.data() + from, to - from);
}

/// A record's content — its size prefix and body: what `append_raw` takes back.
inline Bytes sink_record_content(Bytes buf, const SinkRecordAt& at) noexcept {
  return sink_slice(buf, at.content, at.end);
}

/// The bytes of `range` (relative to `records_start`): a record's exact wire bytes.
inline Bytes sink_range_bytes(Bytes buf, std::size_t records_start, const RecordRange& range) noexcept {
  if (range.start > static_cast<std::size_t>(-1) - records_start || range.end > static_cast<std::size_t>(-1) - records_start) {
    return Bytes();
  }
  return sink_slice(buf, records_start + range.start, records_start + range.end);
}

// ── Raw-embedded graphs in records (spec 18 §11) ───────────────────────────────

/// The standalone graph a record's raw-embedded entry holds: `[LEB payload length]`, then —
/// when the embedded graph has aligned arrays — a pad count `p` and `p` zero bytes, then
/// the graph. The pad LEADS here (spec 18 §11.4), unlike a graph's trailing pad: a sink
/// writer knows the absolute stream position and pads the graph onto its boundary.
/// Empty when the entry is unreadable.
inline Bytes sink_raw_blob(Bytes buf, std::size_t pos, bool has_pad) noexcept {
  if (pos == npos) return Bytes();
  const Varint length = read_leb(buf, pos);
  std::size_t start = pos + length.len;
  if (length.len == 0 || length.value > remaining(buf, start)) return Bytes();
  std::size_t size = static_cast<std::size_t>(length.value);
  if (has_pad) {
    if (size == 0) return Bytes();
    const std::size_t pad = read_u8(buf, start);
    if (pad + 1 > size) return Bytes();
    start += pad + 1;
    size -= pad + 1;
  }
  return Bytes(buf.data() + start, size);
}

/// The absolute root position of the graph `sink_raw_blob` finds, `npos` when unreadable.
inline std::size_t sink_raw_root(Bytes buf, std::size_t pos, bool has_pad) noexcept {
  const Bytes blob = sink_raw_blob(buf, pos, has_pad);
  if (blob.empty()) return npos;
  const Result<std::size_t> root = root_offset(blob);
  if (!root) return npos;
  return static_cast<std::size_t>(blob.data() - buf.data()) + *root;
}

/// Stores `blob`, a standalone graph, as a record field's raw-embedded payload with `pad`
/// leading zero bytes, and returns `b.cursor()` just after the blob — its distance from
/// the end of the record, which a writer needs to put the blob on its boundary.
template <class B>
inline std::size_t store_sink_raw(B& b, Bytes blob, bool has_pad, std::size_t pad) noexcept {
  const std::size_t before = b.cursor();
  store_bytes(b, blob);
  const std::size_t at = b.cursor();
  if (has_pad) {
    store_zeros(b, pad);
    store_u8(b, static_cast<std::uint8_t>(pad));
  }
  store_leb(b, b.cursor() - before);
  return at;
}

/// The leading pad of a record's raw-embedded graph (spec 18 §11.4, spec 42 D6). `block`
/// is the record content — `[LEB size][fields]` — written with pad 0, its graph starting
/// at `blob_offset`; `base` is the absolute stream position of the block's first byte. The
/// pad is the SMALLEST count in [0, 255] (it is stored in one byte) that puts the graph on
/// an `n` boundary in the stream, COUNTING that the pad lengthens the field's payload
/// length and the record's size — each may grow by a byte and move the graph one further.
/// 0 when no count does (possible only for n >= 128).
inline std::size_t sink_raw_pad(Bytes block, std::size_t blob_offset, std::size_t base, std::size_t n) noexcept {
  const Varint size = read_leb(block, 0);
  if (n == 0 || size.len == 0 || blob_offset < 2 || blob_offset > block.size()) return 0;
  std::size_t q = blob_offset - 2;                 // the payload length's last byte: the pad count follows
  while (q > 0 && (read_u8(block, q - 1) & 0x80u) != 0) q--;
  const Varint payload = read_leb(block, q);
  if (payload.len == 0) return 0;
  for (std::size_t pad = 0; pad < 256; pad++) {
    const std::size_t grow_p = leb_length(payload.value + pad) - payload.len;
    const std::size_t grow_c = leb_length(size.value + pad + grow_p) - size.len;
    if ((base + blob_offset + pad + grow_p + grow_c) % n == 0) return pad;
  }
  return 0;
}

namespace detail {
inline std::uint8_t* write_leb_at(std::uint8_t* p, std::uint64_t v) noexcept {
  do {
    const std::uint8_t low = static_cast<std::uint8_t>(v & 0x7fu);
    v >>= 7;
    *p++ = static_cast<std::uint8_t>(v != 0 ? low | 0x80u : low);
  } while (v != 0);
  return p;
}
}  // namespace detail

/// Puts the raw-embedded graph of the record content just stored in `b` (with pad 0) on its
/// `n` boundary in the stream, `base` being where the content will start there. `blob_at`
/// is what `store_sink_raw` returned. Nothing is serialized again: the graph and what
/// follows it stay where they are, and only the head in front of it — the record's size,
/// the fields before, the field's tag, payload length and pad count — moves down to make
/// room for the pad (spec 42 D6).
template <class B>
inline void place_sink_raw(B& b, std::size_t blob_at, std::size_t base, std::size_t n) noexcept {
  if (!b.ok()) return;
  const Bytes block = b.bytes();
  if (blob_at > block.size()) return;
  const std::size_t bo = block.size() - blob_at;
  const std::size_t pad = sink_raw_pad(block, bo, base, n);
  if (pad == 0) return;
  const Varint size = read_leb(block, 0);
  std::size_t q = bo - 2;
  while (q > 0 && (read_u8(block, q - 1) & 0x80u) != 0) q--;
  const Varint payload = read_leb(block, q);
  const std::uint64_t new_payload = payload.value + pad;
  const std::uint64_t new_size = size.value + pad + (leb_length(new_payload) - payload.len);
  const std::size_t grow = pad + (leb_length(new_payload) - payload.len) + (leb_length(new_size) - size.len);
  const std::size_t middle = q - size.len;          // the fields before, and the field's tag
  std::uint8_t* front = b.claim(grow);
  if (front == nullptr) return;                     // the builder has failed: nothing to place
  std::uint8_t* old = front + grow;                 // where the pad-0 content now starts
  std::memmove(front + leb_length(new_size), old + size.len, middle);
  std::uint8_t* p = detail::write_leb_at(front, new_size) + middle;
  p = detail::write_leb_at(p, new_payload);
  *p++ = static_cast<std::uint8_t>(pad);
  std::memset(p, 0, pad);                           // p + pad == old + bo: the graph, unmoved
}

// ── Writing ────────────────────────────────────────────────────────────────────

/// Frames the record just stored in `b` — its packed body, size prefix included — as a
/// record of `type_id`: the type id in front and, for a doubly-linked sink, the span at the
/// end (the span counts the type id and the body, never itself).
template <class B>
inline void frame_sink_record(B& b, std::uint64_t type_id, bool doubly_linked) noexcept {
  store_leb(b, type_id);
  if (!doubly_linked) return;
  std::uint64_t span = b.cursor();
  std::uint8_t tail[10];
  const std::size_t n = leb_length(span);
  for (std::size_t i = 0; i < n; i++) {           // the LEB bytes, last byte first
    const std::uint8_t low = static_cast<std::uint8_t>(span & 0x7fu);
    span >>= 7;
    tail[n - 1 - i] = static_cast<std::uint8_t>(span != 0 ? low | 0x80u : low);
  }
  b.append_tail(tail, n);
}

/// Stores the content of an ENUM record (spec 11 §2): its value — one raw byte for a
/// byte-wide enum; a wider one as a LEB when that is shorter than its width — behind the
/// size prefix every record content starts with.
template <class B>
inline void store_sink_enum(B& b, std::uint64_t value, std::size_t width) noexcept {
  const std::size_t before = b.cursor();
  if (width == 1) {
    store_u8(b, static_cast<std::uint8_t>(value));
  } else if (leb_length(value) < width) {
    store_leb(b, value);
  } else if (std::uint8_t* p = b.claim(width)) {
    for (std::size_t i = 0; i < width; i++) p[i] = static_cast<std::uint8_t>(value >> (8 * i));
  }
  store_leb(b, b.cursor() - before);
}

/// The value of an enum record whose content holds `size` bytes at `at`.
inline std::uint64_t read_sink_enum(Bytes buf, std::size_t at, std::size_t size, std::size_t width) noexcept {
  if (width == 1) return read_u8(buf, at);
  if (size == width) return read_uint_le(buf, at, width);
  return read_leb(buf, at).value;
}

/// A destination over caller storage (core tier): every record lands in one `write`, all
/// of it or — `buffer_full` — none of it.
class FixedDest {
 public:
  constexpr FixedDest() noexcept = default;
  constexpr FixedDest(std::uint8_t* storage, std::size_t capacity) noexcept : data_(storage), cap_(capacity) {}
  constexpr explicit FixedDest(Span<std::uint8_t> storage) noexcept : data_(storage.data()), cap_(storage.size()) {}

  Status write(Bytes bytes) noexcept {
    if (bytes.size() > cap_ - size_) return Status::buffer_full;
    if (!bytes.empty()) std::memcpy(data_ + size_, bytes.data(), bytes.size());
    size_ += bytes.size();
    return Status::ok;
  }

  /// What has been written so far.
  Bytes bytes() const noexcept { return Bytes(data_, size_); }
  constexpr std::size_t size() const noexcept { return size_; }

 private:
  std::uint8_t* data_ = nullptr;
  std::size_t cap_ = 0;
  std::size_t size_ = 0;
};

}  // namespace dagr
