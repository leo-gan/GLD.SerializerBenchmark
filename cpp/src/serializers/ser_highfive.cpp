#include "bench/serializer.hpp"

#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <string>
#include <unistd.h>
#include <vector>

#if defined(HAS_HIGHFIVE)
#include <highfive/highfive.hpp>
#endif

namespace bench {
namespace {

#if defined(HAS_HIGHFIVE)

std::vector<double> values_to_xy(const Grid& grid) {
  const int nx = grid.nx;
  const int ny = grid.ny;
  std::vector<double> xy(static_cast<size_t>(nx) * static_cast<size_t>(ny));
  for (int y = 0; y < ny; ++y) {
    for (int x = 0; x < nx; ++x) {
      xy[static_cast<size_t>(x) * static_cast<size_t>(ny) + static_cast<size_t>(y)] =
          grid.values[static_cast<size_t>(y) * static_cast<size_t>(nx) + static_cast<size_t>(x)];
    }
  }
  return xy;
}

std::vector<double> xy_to_values(const std::vector<double>& xy, int nx, int ny) {
  std::vector<double> values(static_cast<size_t>(nx) * static_cast<size_t>(ny));
  for (int y = 0; y < ny; ++y) {
    for (int x = 0; x < nx; ++x) {
      values[static_cast<size_t>(y) * static_cast<size_t>(nx) + static_cast<size_t>(x)] =
          xy[static_cast<size_t>(x) * static_cast<size_t>(ny) + static_cast<size_t>(y)];
    }
  }
  return values;
}

std::vector<uint8_t> read_file(const std::string& path) {
  std::ifstream in(path, std::ios::binary);
  if (!in) throw std::runtime_error("highfive: cannot read " + path);
  return std::vector<uint8_t>(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
}

class TempPath {
 public:
  TempPath() {
    char tmpl[] = "/tmp/gld-highfive-XXXXXX";
    const int fd = mkstemp(tmpl);
    if (fd < 0) throw std::runtime_error("highfive: mkstemp failed");
    ::close(fd);
    path_ = tmpl;
  }
  ~TempPath() { ::unlink(path_.c_str()); }
  const std::string& path() const { return path_; }

 private:
  std::string path_;
};

class HighFiveSer final : public ISerializer {
 public:
  const char* name() const override { return "highfive"; }
  const char* version() const override { return "2.10.1"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "archive"; }
  bool supports(const std::string& type_id) const override {
    return type_id == "grid" || type_id == "grid_window";
  }

  void prepare(const Fixture& fx) override {
    const auto& grid = std::get<Grid>(fx.value);
    window_ = fx.type_id == "grid_window";
    nx_ = grid.nx;
    ny_ = grid.ny;
    x0_ = grid.x0;
    y0_ = grid.y0;
    wx_ = grid.wx;
    wy_ = grid.wy;
  }

  std::vector<uint8_t> serialize_bytes(const Fixture& fx) override {
    const auto& grid = std::get<Grid>(fx.value);
    const auto xy = values_to_xy(grid);
    TempPath tmp;
    {
      HighFive::File file(tmp.path(), HighFive::File::Truncate);
      auto dataset = file.createDataSet<double>(
          "grid", HighFive::DataSpace({static_cast<size_t>(grid.nx), static_cast<size_t>(grid.ny)}));
      dataset.write_raw(xy.data());
    }
    return read_file(tmp.path());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    TempPath tmp;
    {
      std::ofstream out(tmp.path(), std::ios::binary);
      out.write(reinterpret_cast<const char*>(data.data()), static_cast<std::streamsize>(data.size()));
      if (!out) throw std::runtime_error("highfive: cannot write image");
    }
    HighFive::File file(tmp.path(), HighFive::File::ReadOnly);
    auto dataset = file.getDataSet("grid");
    const int nx = window_ ? wx_ : nx_;
    const int ny = window_ ? wy_ : ny_;
    std::vector<double> xy(static_cast<size_t>(nx) * static_cast<size_t>(ny));
    if (window_) {
      auto selection = dataset.select(std::vector<size_t>{static_cast<size_t>(x0_), static_cast<size_t>(y0_)},
                                      std::vector<size_t>{static_cast<size_t>(wx_), static_cast<size_t>(wy_)});
      selection.read_raw(xy.data());
    } else {
      dataset.read_raw(xy.data());
    }
    Grid out;
    out.values = xy_to_values(xy, nx, ny);
    return out;
  }

 private:
  bool window_ = false;
  int nx_ = 0;
  int ny_ = 0;
  int x0_ = 0;
  int y0_ = 0;
  int wx_ = 0;
  int wy_ = 0;
};

#endif

}  // namespace

SerializerPtr make_highfive() {
#if defined(HAS_HIGHFIVE)
  return std::make_unique<HighFiveSer>();
#else
  return nullptr;
#endif
}

}  // namespace bench
