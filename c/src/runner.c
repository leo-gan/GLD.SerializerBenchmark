#include "bench.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <errno.h>

uint64_t bench_now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static int mkdir_p(const char *path) {
    char tmp[512];
    snprintf(tmp, sizeof(tmp), "%s", path);
    size_t len = strlen(tmp);
    if (len == 0) return -1;
    for (size_t i = 1; i < len; i++) {
        if (tmp[i] == '/') {
            tmp[i] = 0;
            if (mkdir(tmp, 0755) && errno != EEXIST) return -1;
            tmp[i] = '/';
        }
    }
    if (mkdir(tmp, 0755) && errno != EEXIST) return -1;
    return 0;
}

static bool name_match(const char *name, const char *filter) {
    if (!filter || !filter[0]) return true;
    /* case-insensitive substring */
    size_t n = strlen(name), f = strlen(filter);
    for (size_t i = 0; i + f <= n; i++) {
        size_t j = 0;
        for (; j < f; j++) {
            char a = name[i + j], b = filter[j];
            if (a >= 'A' && a <= 'Z') a += 32;
            if (b >= 'A' && b <= 'Z') b += 32;
            if (a != b) break;
        }
        if (j == f) return true;
    }
    return false;
}

int run_benchmarks(int repetitions, const char *ser_filter, const char *data_filter,
                   const char *log_dir) {
    serializer_t sers[BENCH_MAX_SERIALIZERS];
    int ser_count = 0;
    register_all_serializers(sers, &ser_count);

    test_fixture_t fixtures[TD_COUNT];
    data_init_all(fixtures, TD_COUNT, 42);

    char path[512];
    snprintf(path, sizeof(path), "%s", log_dir ? log_dir : "logs/c");
    mkdir_p(path);

    // Timestamped result file. BENCHMARK_TS set by orchestrator for consistent naming.
    const char *ts = getenv("BENCHMARK_TS");
    char log_path[600];
    if (ts && strlen(ts) > 8) {
        snprintf(log_path, sizeof(log_path), "%s/%s.csv", path, ts);
    } else {
        // local fallback
        snprintf(log_path, sizeof(log_path), "%s/local-%ld.csv", path, (long)time(NULL));
    }
    csv_logger_t *log = csv_logger_create(log_path);
    if (!log) {
        fprintf(stderr, "Cannot create log %s\n", log_path);
        return 1;
    }

    static uint8_t buf[4 * 1024 * 1024];
    const char *modes[] = { "bytes", "stream" };

    printf("[PROGRESS] C benchmark: %d serializers, %d data types, %d reps\n",
           ser_count, TD_COUNT, repetitions);

    for (int di = 0; di < TD_COUNT; di++) {
        test_fixture_t *fx = &fixtures[di];
        if (!name_match(fx->name, data_filter)) continue;
        printf("[PROGRESS] Testing Data: %s\n", fx->name);

        for (int si = 0; si < ser_count; si++) {
            serializer_t *S = &sers[si];
            if (!name_match(S->name, ser_filter)) continue;
            if (S->supports && !S->supports(fx->kind)) continue;
            if (S->prepare && S->prepare(fx->kind, fx) != 0) continue;

            for (int mi = 0; mi < 2; mi++) {
                const char *mode = modes[mi];
                int had_error = 0;
                /* Log every successful rep including r==0 (warmup). Analysis drops warmup later. */
                for (int r = 0; r < repetitions; r++) {
                    size_t out_len = 0;
                    test_fixture_t out_fx;
                    memset(&out_fx, 0, sizeof(out_fx));
                    out_fx.kind = fx->kind;

                    uint64_t t0 = bench_now_ns();
                    int rc = S->serialize(fx, buf, sizeof(buf), &out_len);
                    if (rc == 0 && mode[0] == 's')
                        rc = bench_stream_write_all(buf, out_len);
                    uint64_t t1 = bench_now_ns();
                    if (rc != 0) {
                        if (!had_error) {
                            fprintf(stderr, "[ERROR] %s / %s / %s: serialize failed\n",
                                    S->name, fx->name, mode);
                            had_error = 1;
                        }
                        continue;
                    }
                    if (mode[0] == 's') {
                        if (bench_stream_read_all(buf, sizeof(buf), out_len) != 0) {
                            if (!had_error) {
                                fprintf(stderr, "[ERROR] %s / %s / %s: stream read failed\n",
                                        S->name, fx->name, mode);
                                had_error = 1;
                            }
                            continue;
                        }
                    }
                    rc = S->deserialize(buf, out_len, &out_fx, fx->kind);
                    uint64_t t2 = bench_now_ns();
                    if (rc != 0) {
                        if (!had_error) {
                            fprintf(stderr, "[ERROR] %s / %s / %s: deserialize failed\n",
                                    S->name, fx->name, mode);
                            had_error = 1;
                        }
                        continue;
                    }
                    bool ok = S->fidelity ? S->fidelity(fx, &out_fx) : true;
                    if (!ok) {
                        if (!had_error) {
                            fprintf(stderr, "[ERROR] %s / %s / %s: fidelity failed\n",
                                    S->name, fx->name, mode);
                            had_error = 1;
                        }
                        continue;
                    }
                    if (!had_error) {
                        const char *sm = (mode && strcmp(mode, "stream") == 0) ? "adapted" : "";
                        size_t gz = 0, zs = 0;
                        bench_compress_sizes(buf, out_len, &gz, &zs);
                        csv_logger_write(log, mode, fx->name, repetitions, r, S->name,
                                         t1 - t0, t2 - t1, out_len, 1.0, S->version,
                                         1, "", sm, -1, -1, gz, zs);
                    }
                }
            }
        }
    }
    csv_logger_close(log);
    printf("[PROGRESS] Complete. Results: %s\n", log_path);
    return 0;
}
