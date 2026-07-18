// Stub when libprotobuf / protobuf sysroot is not configured.
#include "bench/serializer.hpp"

namespace bench {

SerializerPtr make_protobuf() { return nullptr; }

}  // namespace bench
