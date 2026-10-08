// dagr/writer.hpp — the ALLOC tier of the write side (spec/41-cpp-codegen-plan.md §4.2,
// §8.5): the growing `Builder` and the growing `HeapScratch`. Everything that encodes is
// in dagr/fixed_writer.hpp and is the same code over this builder and the fixed one; this
// header only adds the two types that call `malloc`.
//
// Alloc tier: `malloc` / `free`. Still no exceptions, no RTTI, no containers.
#pragma once

#include <cstdlib>

#include "fixed_writer.hpp"
#include "values.hpp"

namespace dagr {

/// The growing writer: one `malloc`ed buffer filled from its end, doubled when a claim
/// does not fit. Reusable — `reset()` keeps the buffer, so a builder that has seen its
/// largest record allocates nothing afterwards. A failed allocation is
/// `Status::out_of_memory`, sticky like every writer failure.
class Builder {
 public:
  Builder() noexcept = default;
  /// Starts with room for `capacity` bytes, so the first record does not double its way up.
  explicit Builder(std::size_t capacity) noexcept { reserve(capacity); }
  ~Builder() { std::free(data_); }
  Builder(const Builder&) = delete;
  Builder& operator=(const Builder&) = delete;
  Builder(Builder&& other) noexcept
      : data_(other.data_),
        cap_(other.cap_),
        cursor_(other.cursor_),
        alignment_offset_(other.alignment_offset_),
        status_(other.status_) {
    other.data_ = nullptr;
    other.cap_ = other.cursor_ = 0;
    other.status_ = Status::ok;
  }
  Builder& operator=(Builder&& other) noexcept {
    if (this != &other) {
      std::free(data_);
      data_ = other.data_;
      cap_ = other.cap_;
      cursor_ = other.cursor_;
      alignment_offset_ = other.alignment_offset_;
      status_ = other.status_;
      other.data_ = nullptr;
      other.cap_ = other.cursor_ = 0;
      other.status_ = Status::ok;
    }
    return *this;
  }

  /// `n` writable bytes immediately below what is stored so far, or nullptr.
  std::uint8_t* claim(std::size_t n) noexcept {
    if (n > cap_ - cursor_ && !grow(n)) return nullptr;
    cursor_ += n;
    return data_ + (cap_ - cursor_);
  }

  std::size_t cursor() const noexcept { return cursor_; }
  std::size_t capacity() const noexcept { return cap_; }
  Status status() const noexcept { return status_; }
  bool ok() const noexcept { return status_ == Status::ok; }

  /// The number of bytes that will precede the finished buffer in whatever carries it
  /// (spec 12 §14): finish padding then aligns `offset + length`, so that aligned arrays
  /// land on their boundary in the ENVELOPE's frame. Configuration — `reset()` keeps it.
  void set_alignment_offset(std::size_t offset) noexcept { alignment_offset_ = offset; }
  std::size_t alignment_offset() const noexcept { return alignment_offset_; }

  /// Records the first failure and leaves no room, so that no later claim succeeds.
  void fail(Status status) noexcept {
    if (status_ == Status::ok) status_ = status;
    cursor_ = cap_;
  }

  /// The bytes stored so far — a view into this builder, valid until it is next used.
  /// Empty once anything has failed.
  Bytes bytes() const noexcept { return ok() && cursor_ != 0 ? Bytes(data_ + (cap_ - cursor_), cursor_) : Bytes(); }

  /// The byte stored when the cursor reached `at`, with `cursor() - at` more stored bytes
  /// after it, or nullptr (see `FixedBuilder::written`). Valid until the next claim.
  std::uint8_t* written(std::size_t at) noexcept {
    return ok() && at != 0 && at <= cursor_ ? data_ + (cap_ - at) : nullptr;
  }

  /// Rewinds for another record, keeping the buffer.
  void reset() noexcept {
    cursor_ = 0;
    status_ = Status::ok;
  }

  /// Makes room for a record of `n` bytes up front.
  void reserve(std::size_t n) noexcept {
    if (n > cap_ - cursor_) grow(n);
  }

  /// Appends `n` bytes AFTER what is stored — a doubly-linked sink's trailing span (spec
  /// 11 §11.5). What is stored moves down by `n`; fails like a claim.
  void append_tail(const std::uint8_t* tail, std::size_t n) noexcept {
    if (n == 0 || claim(n) == nullptr) return;
    std::uint8_t* front = data_ + (cap_ - cursor_);
    std::memmove(front, front + n, cursor_ - n);
    std::memcpy(data_ + (cap_ - n), tail, n);
  }

 private:
#if defined(__GNUC__) || defined(__clang__)
  [[gnu::noinline]]
#endif
  bool grow(std::size_t n) noexcept {
    if (status_ != Status::ok) return false;
    if (n > static_cast<std::size_t>(-1) / 2 - cursor_) {
      fail(Status::out_of_memory);
      return false;
    }
    std::size_t cap = cap_ < 64 ? 64 : cap_ * 2;
    while (cap - cursor_ < n) cap *= 2;
    std::uint8_t* data = static_cast<std::uint8_t*>(std::malloc(cap));
    if (data == nullptr) {
      fail(Status::out_of_memory);
      return false;
    }
    if (cursor_ != 0) std::memcpy(data + (cap - cursor_), data_ + (cap_ - cursor_), cursor_);
    std::free(data_);
    data_ = data;
    cap_ = cap;
    return true;
  }

  std::uint8_t* data_ = nullptr;
  std::size_t cap_ = 0;
  std::size_t cursor_ = 0;
  std::size_t alignment_offset_ = 0;
  Status status_ = Status::ok;
};

/// A zeroed block of `size` bytes whose start is a multiple of `align` (a power of two):
/// a SharedBuffer region (spec 20 §9.2) — the overlays place atomic words and aligned(N)
/// arrays relative to it. Freed when destroyed; `data()` is nullptr when allocation failed.
class Region {
 public:
  Region() noexcept = default;
  Region(std::size_t size, std::size_t align) noexcept : size_(size) {
    if (align < alignof(std::max_align_t)) align = alignof(std::max_align_t);
    raw_ = static_cast<std::uint8_t*>(std::malloc(size + align));
    if (raw_ == nullptr) {
      size_ = 0;
      return;
    }
    const std::uintptr_t at = reinterpret_cast<std::uintptr_t>(raw_);
    data_ = raw_ + ((align - (at & (align - 1))) & (align - 1));
    std::memset(data_, 0, size);
  }
  ~Region() { std::free(raw_); }
  Region(const Region&) = delete;
  Region& operator=(const Region&) = delete;
  Region(Region&& other) noexcept : raw_(other.raw_), data_(other.data_), size_(other.size_) {
    other.raw_ = other.data_ = nullptr;
    other.size_ = 0;
  }
  Region& operator=(Region&& other) noexcept {
    if (this != &other) {
      std::free(raw_);
      raw_ = other.raw_;
      data_ = other.data_;
      size_ = other.size_;
      other.raw_ = other.data_ = nullptr;
      other.size_ = 0;
    }
    return *this;
  }

  std::uint8_t* data() const noexcept { return data_; }
  std::size_t size() const noexcept { return size_; }
  Bytes bytes() const noexcept { return Bytes(data_, size_); }

 private:
  std::uint8_t* raw_ = nullptr;
  std::uint8_t* data_ = nullptr;
  std::size_t size_ = 0;
};

/// The growing DataSink destination (spec 11 §5): the stream in one `malloc`ed buffer that
/// doubles when a record does not fit. Every record lands in one `write` — all of it, or
/// (`out_of_memory`) none of it.
class HeapDest {
 public:
  HeapDest() noexcept = default;
  ~HeapDest() { std::free(data_); }
  HeapDest(const HeapDest&) = delete;
  HeapDest& operator=(const HeapDest&) = delete;
  HeapDest(HeapDest&& other) noexcept : data_(other.data_), cap_(other.cap_), size_(other.size_) {
    other.data_ = nullptr;
    other.cap_ = other.size_ = 0;
  }
  HeapDest& operator=(HeapDest&& other) noexcept {
    if (this != &other) {
      std::free(data_);
      data_ = other.data_;
      cap_ = other.cap_;
      size_ = other.size_;
      other.data_ = nullptr;
      other.cap_ = other.size_ = 0;
    }
    return *this;
  }

  Status write(Bytes bytes) noexcept {
    if (bytes.size() > cap_ - size_) {
      if (bytes.size() > static_cast<std::size_t>(-1) / 2 - size_) return Status::out_of_memory;
      std::size_t cap = cap_ < 256 ? 256 : cap_ * 2;
      while (cap - size_ < bytes.size()) cap *= 2;
      std::uint8_t* data = static_cast<std::uint8_t*>(std::malloc(cap));
      if (data == nullptr) return Status::out_of_memory;
      if (size_ != 0) std::memcpy(data, data_, size_);
      std::free(data_);
      data_ = data;
      cap_ = cap;
    }
    if (!bytes.empty()) std::memcpy(data_ + size_, bytes.data(), bytes.size());
    size_ += bytes.size();
    return Status::ok;
  }

  /// The stream so far — a view into this destination, valid until its next write.
  Bytes bytes() const noexcept { return Bytes(data_, size_); }
  std::size_t size() const noexcept { return size_; }
  /// Forgets what was written, keeping the buffer.
  void clear() noexcept { size_ = 0; }

 private:
  std::uint8_t* data_ = nullptr;
  std::size_t cap_ = 0;
  std::size_t size_ = 0;
};

/// The growing scratch: blocks from `malloc`, freed together when it is destroyed.
/// `reset()` keeps the LARGEST block and frees the others, so a scratch reused across
/// restores of similar size settles on one block and allocates nothing.
class HeapScratch : public Scratch {
 public:
  HeapScratch() noexcept {
    refill_ = &HeapScratch::refill;
    rewind_ = &HeapScratch::rewind;
    failure_ = Status::out_of_memory;
  }
  ~HeapScratch() { release(nullptr); }

 private:
  /// Every block starts with a link to the one before it.
  struct Block {
    Block* prev;
    std::size_t size;   // usable bytes after the header
  };
  static constexpr std::size_t header = (sizeof(Block) + alignof(std::max_align_t) - 1) / alignof(std::max_align_t) *
                                        alignof(std::max_align_t);

  static bool refill(Scratch& self, std::size_t bytes) {
    HeapScratch& me = static_cast<HeapScratch&>(self);
    std::size_t size = me.last_ != nullptr ? me.last_->size * 2 : 1024;
    if (bytes > static_cast<std::size_t>(-1) / 2 - header) return false;
    while (size < bytes) size *= 2;
    void* raw = std::malloc(header + size);
    if (raw == nullptr) return false;
    Block* block = new (raw) Block{me.last_, size};
    me.last_ = block;
    me.use(block);
    return true;
  }

  static void rewind(Scratch& self) {
    HeapScratch& me = static_cast<HeapScratch&>(self);
    // The newest block is the largest: each refill at least doubles.
    if (me.last_ != nullptr) {
      me.release(me.last_);
      me.last_->prev = nullptr;
      me.use(me.last_);
    }
  }

  void use(Block* block) noexcept {
    begin_ = static_cast<std::uint8_t*>(static_cast<void*>(block)) + header;
    cur_ = begin_;
    end_ = begin_ + block->size;
  }

  /// Frees every block except `keep`.
  void release(Block* keep) noexcept {
    Block* block = last_;
    while (block != nullptr) {
      Block* prev = block->prev;
      if (block != keep) std::free(block);
      block = prev;
    }
    last_ = keep;
  }

  Block* last_ = nullptr;
};

}  // namespace dagr
