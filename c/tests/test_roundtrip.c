/* Round-trip + API-contract tests for all registered C serializers. */
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
    CHECK(n >= 10, "expected many serializers, got %d", n);

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

/* Opaque-payload anti-pattern: map-style codecs must not emit custom-binary
 * layout as their only payload for SimpleObject (first byte kind, then fixed fields).
 * After native encoding, SimpleObject sizes should differ from custom-binary's 70. */
static void test_binary_not_opaque_custom_binary(void) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
    int n = 0;
    register_all_serializers(sers, &n);

    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 42);
    test_fixture_t *fx = NULL;
    for (int i = 0; i < TD_COUNT; i++)
        if (fixtures[i].kind == TD_SIMPLE) { fx = &fixtures[i]; break; }
    CHECK(fx != NULL, "SimpleObject fixture");

    static uint8_t buf[65536], custom[65536];
    size_t custom_len = 0;
    for (int si = 0; si < n; si++) {
        if (strcmp(sers[si].name, "custom-binary") != 0) continue;
        sers[si].serialize(fx, custom, sizeof custom, &custom_len);
    }
    CHECK(custom_len == 70, "custom-binary SimpleObject size got %zu", custom_len);

    /* Codecs that should encode library-native structure (not opaque custom-binary). */
    const char *native_expect[] = {
        "cJSON", "yyjson", "jansson", "parson", "json-c",
        "mpack", "msgpack-c", "tinycbor", "cbor-encode", "qcbor",
        "libbson", "zcbor", NULL
    };
    for (int si = 0; si < n; si++) {
        int match = 0;
        for (int j = 0; native_expect[j]; j++)
            if (strcmp(sers[si].name, native_expect[j]) == 0) match = 1;
        if (!match) continue;
        if (sers[si].prepare) sers[si].prepare(fx->kind, fx);
        size_t len = 0;
        int rc = sers[si].serialize(fx, buf, sizeof buf, &len);
        CHECK(rc == 0, "%s ser simple", sers[si].name);
        CHECK(!(len == custom_len && memcmp(buf, custom, len) == 0),
              "%s must not emit raw custom-binary layout", sers[si].name);
        if (strcmp(sers[si].name, "cJSON") == 0 || strcmp(sers[si].name, "yyjson") == 0 ||
            strcmp(sers[si].name, "jansson") == 0 || strcmp(sers[si].name, "parson") == 0 ||
            strcmp(sers[si].name, "json-c") == 0) {
            CHECK(buf[0] == '{', "%s should emit JSON object, got 0x%02x", sers[si].name, buf[0]);
        }
    }
}

/* Buffer-API smoke: serialize twice into different buffers yields identical output. */
static void test_deterministic_output(void) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
    int n = 0;
    register_all_serializers(sers, &n);
    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 7);
    test_fixture_t *fx = &fixtures[TD_PERSON < TD_COUNT ? TD_PERSON : 0];
    for (int i = 0; i < TD_COUNT; i++)
        if (fixtures[i].kind == TD_PERSON) fx = &fixtures[i];

    static uint8_t a[65536], b[65536];
    for (int si = 0; si < n; si++) {
        serializer_t *S = &sers[si];
        if (S->prepare) S->prepare(fx->kind, fx);
        size_t la = 0, lb = 0;
        if (S->serialize(fx, a, sizeof a, &la) != 0) continue;
        if (S->serialize(fx, b, sizeof b, &lb) != 0) continue;
        CHECK(la == lb && memcmp(a, b, la) == 0,
              "%s Person not deterministic (%zu vs %zu)", S->name, la, lb);
    }
}


/* ObjectGraph: graph-capable serializers round-trip cycles; tree-only skip. */
static void test_object_graph(void) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
    int n = 0;
    register_all_serializers(sers, &n);

    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 42);
    test_fixture_t *fx = NULL;
    for (int i = 0; i < TD_COUNT; i++)
        if (fixtures[i].kind == TD_OBJECT_GRAPH) { fx = &fixtures[i]; break; }
    CHECK(fx != NULL, "ObjectGraph fixture present");
    CHECK(fx->graph.node_count == 3, "ObjectGraph node_count=%d", fx->graph.node_count);
    CHECK(fx->graph.nodes[1].related == 2 && fx->graph.nodes[2].related == 1,
          "sibling cycle Related edges");
    CHECK(fx->graph.nodes[1].parent == 0 && fx->graph.nodes[2].parent == 0,
          "children parent back-edges");

    static uint8_t buf[65536];
    int graph_ok = 0, tree_skip = 0;
    for (int si = 0; si < n; si++) {
        serializer_t *S = &sers[si];
        bool sup = !S->supports || S->supports(TD_OBJECT_GRAPH);
        if (!sup) {
            tree_skip++;
            continue;
        }
        if (S->prepare && S->prepare(TD_OBJECT_GRAPH, fx) != 0) {
            CHECK(0, "%s prepare ObjectGraph failed", S->name);
            continue;
        }
        size_t len = 0;
        test_fixture_t out;
        memset(&out, 0, sizeof out);
        int rc = S->serialize(fx, buf, sizeof buf, &len);
        CHECK(rc == 0 && len > 0, "%s ObjectGraph serialize rc=%d len=%zu", S->name, rc, len);
        if (rc != 0) continue;
        rc = S->deserialize(buf, len, &out, TD_OBJECT_GRAPH);
        CHECK(rc == 0, "%s ObjectGraph deserialize rc=%d", S->name, rc);
        if (rc != 0) continue;
        bool ok = S->fidelity ? S->fidelity(fx, &out) : true;
        CHECK(ok, "%s ObjectGraph fidelity", S->name);
        if (ok) {
            /* Reconstructed sibling cycle */
            CHECK(out.graph.nodes[1].related == 2 && out.graph.nodes[2].related == 1,
                  "%s restored Related cycle", S->name);
            graph_ok++;
        }
    }
    CHECK(graph_ok >= n - 1, "almost all serializers should pass ObjectGraph (ok=%d n=%d)", graph_ok, n);
    CHECK(tree_skip == 0, "no serializer should skip ObjectGraph (skips=%d)", tree_skip);
    printf("  ObjectGraph: %d serializers ok, %d skipped\n", graph_ok, tree_skip);
}

int main(void) {
    printf("C serializer roundtrip tests\n");
    test_all_roundtrips();
    test_object_graph();
    test_binary_not_opaque_custom_binary();
    test_deterministic_output();
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
