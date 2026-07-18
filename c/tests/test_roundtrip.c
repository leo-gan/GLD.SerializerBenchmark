/* Round-trip tests for all registered C serializers — Data Model v2 only. */
#include "bench.h"
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

static void test_all_roundtrips(void) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
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
            CHECK(ok, "%s fidelity %s", S->name, fx->name);
        }
    }
}

static void test_v2_type_names(void) {
    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 1);
    const char *expect[] = {"message", "document", "telemetry", "strings", "event"};
    for (int i = 0; i < TD_COUNT; i++) {
        CHECK(strcmp(fixtures[i].name, expect[i]) == 0, "type %d name %s", i, fixtures[i].name);
        CHECK(strcmp(test_data_name(fixtures[i].kind), expect[i]) == 0, "kind name");
    }
}

int main(void) {
    printf("C serializer roundtrip tests (Data Model v2)\n");
    test_v2_type_names();
    test_all_roundtrips();
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
