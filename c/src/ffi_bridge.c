/* Experiment 15 only. Fortran fills these fields inside its timer, then this
 * file copies them into the suite's C fixture and calls the same serialize
 * and deserialize functions the C adapters time. Those adapters are thick
 * wrappers around v2_write_fixture, so the Fortran side does not reimplement
 * each library. */
#include "bench.h"
#include <stdio.h>
#include <string.h>

#ifdef HAS_CJSON
#include "cJSON.h"
#endif
#ifdef HAS_LIBBSON
#include <bson/bson.h>
#endif

#ifdef HAS_YYJSON
int bench_yyjson_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_yyjson_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_yyjson_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_CJSON
int bench_cjson_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_cjson_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_cjson_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_MPACK
int bench_mpack_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_mpack_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_mpack_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_TINYCBOR
int bench_tinycbor_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_tinycbor_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_tinycbor_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_NANOPB
int bench_nanopb_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_nanopb_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_nanopb_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_AVRO_C
int bench_avro_c_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_avro_c_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_avro_c_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_LIBYAML
int bench_yaml_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_yaml_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_yaml_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_LIBBSON
int bench_libbson_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_libbson_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_libbson_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_FLATCC
int bench_flatcc_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_flatcc_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_flatcc_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif
#ifdef HAS_IONC
int bench_ionc_prep(test_data_kind_t kind, const test_fixture_t *fx);
int bench_ionc_ser(const test_fixture_t *fx, uint8_t *buf, size_t cap, size_t *ol);
int bench_ionc_de(const uint8_t *buf, size_t len, test_fixture_t *out, test_data_kind_t kind);
#endif

static void copy_field(char *dst, const char *src) {
    size_t i;
    memset(dst, 0, V2_STR);
    if (!src) return;
    for (i = 0; i + 1 < V2_STR && src[i]; i++) dst[i] = src[i];
}

static void fill_doc(test_fixture_t *fx, const char *id, int32_t status, const char *region,
                      int32_t version, int32_t nitems, const char *sku, const int32_t *qty,
                      const int64_t *price) {
    int i;
    memset(fx, 0, sizeof(*fx));
    fx->kind = TD_DOCUMENT;
    fx->name = "document";
    fx->batch_n = 1;
    fx->batch = NULL;
    copy_field(fx->document.id, id);
    fx->document.status = status;
    copy_field(fx->document.meta.region, region);
    fx->document.meta.version = version;
    if (nitems < 0) nitems = 0;
    if (nitems > V2_MAX_CHILDREN) nitems = V2_MAX_CHILDREN;
    fx->document.item_count = nitems;
    for (i = 0; i < nitems; i++) {
        copy_field(fx->document.items[i].sku, sku ? sku + (size_t)i * V2_STR : "");
        fx->document.items[i].qty = qty ? qty[i] : 0;
        fx->document.items[i].price_minor = price ? price[i] : 0;
    }
}

static int known(const char *name) {
    if (!name) return 0;
#ifdef HAS_YYJSON
    if (strcmp(name, "yyjson") == 0) return 1;
#endif
#ifdef HAS_CJSON
    if (strcmp(name, "cJSON") == 0) return 1;
#endif
#ifdef HAS_MPACK
    if (strcmp(name, "mpack") == 0) return 1;
#endif
#ifdef HAS_TINYCBOR
    if (strcmp(name, "tinycbor") == 0) return 1;
#endif
#ifdef HAS_NANOPB
    if (strcmp(name, "nanopb") == 0) return 1;
#endif
#ifdef HAS_AVRO_C
    if (strcmp(name, "avro-c") == 0) return 1;
#endif
#ifdef HAS_LIBYAML
    if (strcmp(name, "libyaml") == 0) return 1;
#endif
#ifdef HAS_LIBBSON
    if (strcmp(name, "libbson") == 0) return 1;
#endif
#ifdef HAS_FLATCC
    if (strcmp(name, "flatcc") == 0) return 1;
#endif
#ifdef HAS_IONC
    if (strcmp(name, "ion-c") == 0) return 1;
#endif
    return 0;
}

void gld_ffi_version(const char *name, char *dst, int cap) {
    const char *v = "";
    if (!dst || cap < 1) return;
#ifdef HAS_YYJSON
    if (strcmp(name, "yyjson") == 0) v = "0.10.0";
#endif
#ifdef HAS_CJSON
    if (strcmp(name, "cJSON") == 0) v = cJSON_Version();
#endif
#ifdef HAS_MPACK
    if (strcmp(name, "mpack") == 0) v = "1.1.1";
#endif
#ifdef HAS_TINYCBOR
    if (strcmp(name, "tinycbor") == 0) v = "0.6.0";
#endif
#ifdef HAS_NANOPB
    if (strcmp(name, "nanopb") == 0) v = "0.4.9.2";
#endif
#ifdef HAS_AVRO_C
    if (strcmp(name, "avro-c") == 0) v = "1.11.3";
#endif
#ifdef HAS_LIBYAML
    if (strcmp(name, "libyaml") == 0) v = "0.2.5";
#endif
#ifdef HAS_LIBBSON
    if (strcmp(name, "libbson") == 0) v = BSON_VERSION_S;
#endif
#ifdef HAS_FLATCC
    if (strcmp(name, "flatcc") == 0) v = "0.6.3";
#endif
#ifdef HAS_IONC
    if (strcmp(name, "ion-c") == 0) v = "1.1.6";
#endif
    snprintf(dst, (size_t)cap, "%s", v ? v : "");
}

int gld_ffi_prep(const char *name, const char *id, int32_t status, const char *region, int32_t version,
                 int32_t nitems, const char *sku, const int32_t *qty, const int64_t *price) {
    test_fixture_t fx;
    if (!known(name)) return 2;
    fill_doc(&fx, id, status, region, version, nitems, sku, qty, price);
#ifdef HAS_YYJSON
    if (strcmp(name, "yyjson") == 0) return bench_yyjson_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_CJSON
    if (strcmp(name, "cJSON") == 0) return bench_cjson_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_MPACK
    if (strcmp(name, "mpack") == 0) return bench_mpack_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_TINYCBOR
    if (strcmp(name, "tinycbor") == 0) return bench_tinycbor_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_NANOPB
    if (strcmp(name, "nanopb") == 0) return bench_nanopb_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_AVRO_C
    if (strcmp(name, "avro-c") == 0) return bench_avro_c_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_LIBYAML
    if (strcmp(name, "libyaml") == 0) return bench_yaml_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_LIBBSON
    if (strcmp(name, "libbson") == 0) return bench_libbson_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_FLATCC
    if (strcmp(name, "flatcc") == 0) return bench_flatcc_prep(TD_DOCUMENT, &fx);
#endif
#ifdef HAS_IONC
    if (strcmp(name, "ion-c") == 0) return bench_ionc_prep(TD_DOCUMENT, &fx);
#endif
    return 2;
}

int gld_ffi_ser(const char *name, const char *id, int32_t status, const char *region, int32_t version,
                int32_t nitems, const char *sku, const int32_t *qty, const int64_t *price,
                uint8_t *buf, size_t cap, size_t *out_len) {
    test_fixture_t fx;
    if (!known(name)) return 2;
    fill_doc(&fx, id, status, region, version, nitems, sku, qty, price);
#ifdef HAS_YYJSON
    if (strcmp(name, "yyjson") == 0) return bench_yyjson_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_CJSON
    if (strcmp(name, "cJSON") == 0) return bench_cjson_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_MPACK
    if (strcmp(name, "mpack") == 0) return bench_mpack_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_TINYCBOR
    if (strcmp(name, "tinycbor") == 0) return bench_tinycbor_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_NANOPB
    if (strcmp(name, "nanopb") == 0) return bench_nanopb_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_AVRO_C
    if (strcmp(name, "avro-c") == 0) return bench_avro_c_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_LIBYAML
    if (strcmp(name, "libyaml") == 0) return bench_yaml_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_LIBBSON
    if (strcmp(name, "libbson") == 0) return bench_libbson_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_FLATCC
    if (strcmp(name, "flatcc") == 0) return bench_flatcc_ser(&fx, buf, cap, out_len);
#endif
#ifdef HAS_IONC
    if (strcmp(name, "ion-c") == 0) return bench_ionc_ser(&fx, buf, cap, out_len);
#endif
    return 2;
}

int gld_ffi_de(const char *name, const uint8_t *buf, size_t len, char *id, int32_t *status, char *region,
               int32_t *version, int32_t *nitems, char *sku, int32_t *qty, int64_t *price) {
    test_fixture_t fx;
    int rc = 2;
    int i, n;
    memset(&fx, 0, sizeof(fx));
#ifdef HAS_YYJSON
    if (strcmp(name, "yyjson") == 0) rc = bench_yyjson_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_CJSON
    if (strcmp(name, "cJSON") == 0) rc = bench_cjson_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_MPACK
    if (strcmp(name, "mpack") == 0) rc = bench_mpack_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_TINYCBOR
    if (strcmp(name, "tinycbor") == 0) rc = bench_tinycbor_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_NANOPB
    if (strcmp(name, "nanopb") == 0) rc = bench_nanopb_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_AVRO_C
    if (strcmp(name, "avro-c") == 0) rc = bench_avro_c_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_LIBYAML
    if (strcmp(name, "libyaml") == 0) rc = bench_yaml_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_LIBBSON
    if (strcmp(name, "libbson") == 0) rc = bench_libbson_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_FLATCC
    if (strcmp(name, "flatcc") == 0) rc = bench_flatcc_de(buf, len, &fx, TD_DOCUMENT);
#endif
#ifdef HAS_IONC
    if (strcmp(name, "ion-c") == 0) rc = bench_ionc_de(buf, len, &fx, TD_DOCUMENT);
#endif
    if (rc != 0) return rc == 2 ? 2 : 1;
    copy_field(id, fx.document.id);
    *status = fx.document.status;
    copy_field(region, fx.document.meta.region);
    *version = fx.document.meta.version;
    n = fx.document.item_count;
    if (n < 0) n = 0;
    if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
    *nitems = n;
    for (i = 0; i < n; i++) {
        copy_field(sku + (size_t)i * V2_STR, fx.document.items[i].sku);
        qty[i] = fx.document.items[i].qty;
        price[i] = fx.document.items[i].price_minor;
    }
    return 0;
}
