#pragma once
// Vector-backed stream helpers for timed stream-mode paths.
// Keeps the harness sink as std::vector<uint8_t> while using library ostream/istream APIs.

#include <cstdint>
#include <cstring>
#include <istream>
#include <ostream>
#include <streambuf>
#include <vector>

namespace bench {

// std::streambuf that appends to a vector (for std::ostream adapters).
class VecOutBuf final : public std::streambuf {
 public:
  explicit VecOutBuf(std::vector<uint8_t>& v) : v_(v) {}

 protected:
  int_type overflow(int_type ch) override {
    if (!traits_type::eq_int_type(ch, traits_type::eof())) {
      v_.push_back(static_cast<uint8_t>(ch));
    }
    return ch;
  }
  std::streamsize xsputn(const char* s, std::streamsize n) override {
    v_.insert(v_.end(), reinterpret_cast<const uint8_t*>(s),
              reinterpret_cast<const uint8_t*>(s) + n);
    return n;
  }

 private:
  std::vector<uint8_t>& v_;
};

class VecOutStream final : public std::ostream {
 public:
  explicit VecOutStream(std::vector<uint8_t>& v) : std::ostream(nullptr), buf_(v) {
    rdbuf(&buf_);
  }

 private:
  VecOutBuf buf_;
};

// std::streambuf that reads from a const byte span (for std::istream adapters).
class VecInBuf final : public std::streambuf {
 public:
  VecInBuf(const uint8_t* data, size_t len) {
    auto* p = const_cast<char*>(reinterpret_cast<const char*>(data));
    setg(p, p, p + len);
  }

 protected:
  pos_type seekoff(off_type off, std::ios_base::seekdir dir,
                   std::ios_base::openmode which) override {
    if ((which & std::ios_base::in) == 0) return pos_type(off_type(-1));
    char* base = eback();
    char* end = egptr();
    char* cur = gptr();
    if (dir == std::ios_base::beg) cur = base + off;
    else if (dir == std::ios_base::cur) cur = gptr() + off;
    else if (dir == std::ios_base::end) cur = end + off;
    if (cur < base || cur > end) return pos_type(off_type(-1));
    setg(base, cur, end);
    return pos_type(cur - base);
  }
};

class VecInStream final : public std::istream {
 public:
  VecInStream(const uint8_t* data, size_t len) : std::istream(nullptr), buf_(data, len) {
    rdbuf(&buf_);
  }
  explicit VecInStream(const std::vector<uint8_t>& v)
      : VecInStream(v.data(), v.size()) {}

 private:
  VecInBuf buf_;
};

// msgpack-cxx Stream concept: write(const char*, size_t)
struct MsgpackVecStream {
  std::vector<uint8_t>& v;
  void write(const char* buf, size_t len) {
    v.insert(v.end(), reinterpret_cast<const uint8_t*>(buf),
             reinterpret_cast<const uint8_t*>(buf) + len);
  }
};

}  // namespace bench
