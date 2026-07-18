#include "bench.h"
#include <stdio.h>

void register_all_serializers(serializer_t *out, int *count) {
    *count = 0;
#ifdef HAS_CJSON
    bench_register_cjson(out, count);
#endif
#ifdef HAS_YYJSON
    bench_register_yyjson(out, count);
#endif
#ifdef HAS_JANSSON
    bench_register_jansson(out, count);
#endif
#ifdef HAS_PARSON
    bench_register_parson(out, count);
#endif
#ifdef HAS_JSON_C
    bench_register_json_c(out, count);
#endif
#ifdef HAS_MPACK
    bench_register_mpack(out, count);
#endif
#ifdef HAS_MSGPACK_C
    bench_register_msgpack_c(out, count);
#endif
#ifdef HAS_TINYCBOR
    bench_register_tinycbor(out, count);
#endif
#ifdef HAS_LIBCBOR
    bench_register_libcbor(out, count);
#endif
#ifdef HAS_QCBOR
    bench_register_qcbor(out, count);
#endif
#ifdef HAS_UBJ
    bench_register_ubj(out, count);
#endif
#ifdef HAS_LIBBSON
    bench_register_libbson(out, count);
#endif
#ifdef HAS_CUSTOM_BINARY
    bench_register_custom_binary(out, count);
#endif
#ifdef HAS_NANOPB
    bench_register_nanopb(out, count);
#endif
#ifdef HAS_PROTOBUF_C
    bench_register_protobuf_c(out, count);
#endif
#ifdef HAS_LIBPROTOBUF
    bench_register_protobuf_google(out, count);
#endif
#ifdef HAS_UPB_WIRE
    bench_register_upb(out, count);
#endif
#ifdef HAS_FLATCC
    bench_register_flatcc(out, count);
#endif
#ifdef HAS_AVRO_C
    bench_register_avro_c(out, count);
#endif
#ifdef HAS_ZCBOR
    bench_register_zcbor(out, count);
#endif
    fprintf(stderr, "[bench-c] registered %d serializers\n", *count);
}
