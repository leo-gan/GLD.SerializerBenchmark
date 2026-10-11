/* Round-trip tests for all registered C serializers — Data Model v2 only. */
#include "bench.h"
#include "schedule.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int failures = 0;
static int checks = 0;

#define CHECK(cond, fmt, ...) do { \
    checks++; \
    if (!(cond)) { \
        failures++; \
        fprintf(stderr, "FAIL: " fmt "\n", ##__VA_ARGS__); \
    } \
} while (0)

static void test_compress_sizes(void) {
    size_t gz = 0, zs = 0;
    bench_compress_sizes((const uint8_t *)"hello", 5, &gz, &zs);
    CHECK(gz >= 20 && gz <= 40, "gzip(hello)=%zu want ~25", gz);
    /* zstd is optional */
    (void)zs;
    bench_compress_sizes(NULL, 0, &gz, &zs);
    CHECK(gz == 0 && zs == 0, "empty compress should be 0,0");
}

static void test_all_roundtrips(void) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
    memset(sers, 0, sizeof sers);
    int n = 0;
    register_all_serializers(sers, &n);
    CHECK(n >= 5, "expected several serializers, got %d", n);

    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 42);

    static uint8_t buf[4 * 1024 * 1024];

    for (int si = 0; si < n; si++) {
        serializer_t *S = &sers[si];
        for (int di = 0; di < TD_COUNT; di++) {
            test_fixture_t *fx = &fixtures[di];
            if (S->supports && !S->supports(fx->kind)) continue;
            if (S->prepare && S->prepare(fx->kind, fx) != 0) {
                CHECK(0, "%s prepare failed for %s", S->name, fx->name);
                continue;
            }
            size_t len = 0;
            test_fixture_t out;
            memset(&out, 0, sizeof out);
            int rc = S->serialize(fx, buf, sizeof buf, &len);
            CHECK(rc == 0, "%s serialize %s rc=%d", S->name, fx->name, rc);
            if (rc != 0) continue;
            CHECK(len > 0, "%s serialize %s empty", S->name, fx->name);
            rc = S->deserialize(buf, len, &out, fx->kind);
            CHECK(rc == 0, "%s deserialize %s rc=%d", S->name, fx->name, rc);
            if (rc != 0) continue;
            bool ok = S->fidelity ? S->fidelity(fx, &out) : true;
            data_free_grid(&out);
            CHECK(ok, "%s fidelity %s", S->name, fx->name);
            if (!(S->serialize_fp && S->deserialize_fp)) continue;
            FILE *wf = fmemopen(buf, sizeof buf, "w+");
            CHECK(wf != NULL, "%s fmemopen %s", S->name, fx->name);
            if (!wf) continue;
            size_t slen = 0;
            int src = S->serialize_fp(fx, wf, &slen);
            if (src == 0 && fflush(wf) != 0) src = -1;
            long pos = ftell(wf);
            fclose(wf);
            if (src == 0) slen = pos > 0 ? (size_t)pos : 0;
            CHECK(src == 0 && slen > 0, "%s stream serialize %s rc=%d len=%zu",
                  S->name, fx->name, src, slen);
            if (src != 0 || slen == 0) continue;
            FILE *rf = fmemopen(buf, slen, "r");
            CHECK(rf != NULL, "%s fmemopen read %s", S->name, fx->name);
            if (!rf) continue;
            test_fixture_t out2;
            memset(&out2, 0, sizeof out2);
            int drc = S->deserialize_fp(rf, &out2, fx->kind);
            fclose(rf);
            CHECK(drc == 0, "%s stream deserialize %s rc=%d", S->name, fx->name, drc);
            if (drc != 0) continue;
            bool ok2 = S->fidelity ? S->fidelity(fx, &out2) : true;
            data_free_grid(&out2);
            CHECK(ok2, "%s stream fidelity %s", S->name, fx->name);
        }
    }
}

/* Native FILE* serializers must encode every instance at N>1.
 * A single head-value write labels N but round-trips one object. */
static void test_native_stream_batch(void) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
    memset(sers, 0, sizeof sers);
    int nser = 0;
    register_all_serializers(sers, &nser);
    const int N = 3;
    test_fixture_t items[3];
    memset(items, 0, sizeof items);
    for (int i = 0; i < N; i++) {
        data_make_one(&items[i], TD_MESSAGE, (uint64_t)(1000 + i), 0, 8, 32, 32, 4);
        items[i].batch_n = 1;
        items[i].batch = NULL;
    }
    test_fixture_t fx;
    memset(&fx, 0, sizeof fx);
    fx.name = "message";
    fx.kind = TD_MESSAGE;
    fx.batch_n = N;
    fx.batch = items;
    fx.message = items[0].message;

    static uint8_t buf[1024 * 1024];
    int native = 0;
    for (int si = 0; si < nser; si++) {
        serializer_t *S = &sers[si];
        if (!(S->serialize_fp && S->deserialize_fp)) continue;
        native++;
        if (S->prepare && S->prepare(TD_MESSAGE, &items[0]) != 0) {
            CHECK(0, "%s batch prepare failed", S->name);
            continue;
        }
        FILE *wf = fmemopen(buf, sizeof buf, "w+");
        CHECK(wf != NULL, "%s batch fmemopen", S->name);
        if (!wf) continue;
        size_t len = 0;
        int rc = bench_serialize_cell_fp(S, &fx, wf, &len);
        if (rc == 0 && fflush(wf) != 0) rc = -1;
        long pos = ftell(wf);
        fclose(wf);
        if (rc == 0) len = pos > 0 ? (size_t)pos : 0;
        CHECK(rc == 0 && len > 200, "%s batch stream ser rc=%d len=%zu", S->name, rc, len);
        if (rc != 0 || len == 0) continue;
        test_fixture_t out;
        memset(&out, 0, sizeof out);
        out.kind = TD_MESSAGE;
        out.batch_n = N;
        rc = bench_deserialize_cell_fp(S, buf, len, &out, TD_MESSAGE);
        CHECK(rc == 0, "%s batch stream de rc=%d", S->name, rc);
        if (rc != 0) {
            if (out.batch) free(out.batch);
            continue;
        }
        CHECK(out.batch_n == N && out.batch != NULL, "%s batch_n %d", S->name, out.batch_n);
        bool ok = bench_fidelity_cell(S, &fx, &out);
        CHECK(ok, "%s batch stream fidelity", S->name);
        if (out.batch) free(out.batch);
    }
    CHECK(native >= 2, "expected yyjson and ion-c native streams, got %d", native);
}

static void test_telemetry_points_from_config(void) {
    test_fixture_t fx;
    data_make_one(&fx, TD_TELEMETRY, 42, 0, 8, 8, 32, 4);
    CHECK(fx.telemetry.value_count == 8, "points 8 got %d", fx.telemetry.value_count);
    data_make_one(&fx, TD_TELEMETRY, 42, 0, 8, 128, 32, 4);
    CHECK(fx.telemetry.value_count == 128, "points 128 got %d", fx.telemetry.value_count);
    data_make_one(&fx, TD_TELEMETRY, 42, 0, 8, 512, 32, 4);
    CHECK(fx.telemetry.value_count == 512, "points 512 got %d", fx.telemetry.value_count);
}

static void test_v2_type_names(void) {
    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 1);
    const char *expect[] = {"message", "document", "telemetry", "strings", "event"};
    for (int i = 0; i < 5; i++) {
        CHECK(strcmp(fixtures[i].name, expect[i]) == 0, "type %d name %s", i, fixtures[i].name);
        CHECK(strcmp(test_data_name(fixtures[i].kind), expect[i]) == 0, "kind name");
    }
    CHECK(strcmp(test_data_name(TD_GRID), "grid") == 0, "grid name");
    CHECK(strcmp(test_data_name(TD_GRID_WINDOW), "grid_window") == 0, "grid_window name");
    for (int i = 0; i < TD_COUNT; i++) data_free_grid(&fixtures[i]);
}

static void test_schedule_golden(void) {
    int rc = schedule_verify_golden();
    CHECK(rc == 0, "B-1 schedule golden vector rc=%d (expect A,B,C → C,B,A)", rc);
    uint64_t seed = schedule_derive_seed(42, "message", 1, "abc", "bytes", 0);
    CHECK(seed == 15992650003647724414ULL, "golden seed %llu", (unsigned long long)seed);
    const char *names[] = {"A", "B", "C"};
    const char *out[3];
    schedule_fisher_yates_cstr(names, 3, seed, out);
    CHECK(strcmp(out[0], "C") == 0 && strcmp(out[1], "B") == 0 && strcmp(out[2], "A") == 0,
          "golden perm %s,%s,%s", out[0], out[1], out[2]);
}

int main(void) {
    printf("C serializer roundtrip tests (Data Model v2)\n");
    test_schedule_golden();
    test_v2_type_names();
    test_telemetry_points_from_config();
    test_compress_sizes();
    test_all_roundtrips();
    test_native_stream_batch();
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
