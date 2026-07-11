#include "bench/fixture.hpp"
#include "bench/serializer.hpp"

#include <iostream>
#include <string>

int main() {
  using namespace bench;
  TypeConfig cfg;
  auto sers = all_serializers();
  const char* types[] = {"message", "document", "telemetry", "strings", "event"};
  int failures = 0;
  for (auto& ser : sers) {
    for (const char* tid : types) {
      try {
        Fixture fx = make_fixture(tid, cfg, 42, 1, "test");
        ser->prepare(fx);
        auto buf = ser->serialize_bytes(fx);
        if (buf.empty() && tid != std::string("strings")) {
          // empty protobuf for all-zero is possible; still try decode
        }
        auto out = ser->deserialize_bytes(buf);
        out = ser->to_domain(std::move(out));
        if (!fidelity(fx.value, out)) {
          std::cerr << "FAIL fidelity " << ser->name() << " / " << tid << " size=" << buf.size()
                    << "\n";
          ++failures;
        } else {
          std::cout << "OK " << ser->name() << " / " << tid << " size=" << buf.size() << "\n";
        }
        // stream path (native or adapted) must round-trip independently of bytes
        {
          ser->prepare(fx);
          std::vector<uint8_t> sbuf;
          sbuf.reserve(buf.size() + 64);
          size_t n = ser->serialize_stream(fx, sbuf);
          if (n != sbuf.size()) {
            std::cerr << "FAIL stream size " << ser->name() << " / " << tid << " n=" << n
                      << " sbuf=" << sbuf.size() << "\n";
            ++failures;
          }
          auto sout = ser->to_domain(ser->deserialize_stream(sbuf));
          if (!fidelity(fx.value, sout)) {
            std::cerr << "FAIL stream fidelity " << ser->name() << " / " << tid
                      << " stream_mode=" << ser->stream_mode() << " size=" << sbuf.size() << "\n";
            ++failures;
          }
        }
        // batch N=2 smoke
        Fixture batch = make_fixture(tid, cfg, 42, 2, "test");
        ser->prepare(batch);
        auto b2 = ser->serialize_bytes(batch);
        auto o2 = ser->to_domain(ser->deserialize_bytes(b2));
        if (!fidelity(batch.value, o2)) {
          std::cerr << "FAIL batch " << ser->name() << " / " << tid << "\n";
          ++failures;
        }
      } catch (const std::exception& e) {
        std::cerr << "FAIL " << ser->name() << " / " << tid << ": " << e.what() << "\n";
        ++failures;
      }
    }
  }
  if (failures) {
    std::cerr << failures << " failure(s)\n";
    return 1;
  }
  std::cout << "All roundtrips OK (" << sers.size() << " serializers)\n";
  return 0;
}
