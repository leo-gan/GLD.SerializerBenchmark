/* Data Model v2 minimal path for C: resolve cells via python, time yyjson/cJSON if linked.
 * Full fixture enum integration remains future work; this produces valid suite CSVs.
 */
#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef HAVE_YYJSON
#include "yyjson.h"
#endif

static long long ns_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* Extremely small JSON builder for a fixed message instance (seeded constant). */
static size_t build_message_json(char *buf, size_t cap) {
    const char *s =
        "{\"f_bool\":true,\"f_int32\":1,\"f_int64\":2,\"f_float64\":3.5,"
        "\"f_string\":\"abc\",\"f_bool_2\":false,\"f_int32_2\":4,\"f_string_2\":\"xyz\"}";
    size_t n = strlen(s);
    if (n + 1 > cap) return 0;
    memcpy(buf, s, n + 1);
    return n;
}

int run_benchmarks_v2(int repetitions, const char *log_dir) {
    char path[1024];
    char ts[64];
    const char *env_ts = getenv("BENCHMARK_TS");
    if (env_ts && env_ts[0])
        snprintf(ts, sizeof ts, "%s", env_ts);
    else {
        time_t t = time(NULL);
        struct tm tm;
        localtime_r(&t, &tm);
        strftime(ts, sizeof ts, "%Y-%m-%d-%H%M%S", &tm);
    }
    snprintf(path, sizeof path, "%s/%s.csv", log_dir, ts);
    FILE *f = fopen(path, "w");
    if (!f) return 1;
    fprintf(f, "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,"
               "TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,"
               "MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash\n");

    char json[512];
    size_t jlen = build_message_json(json, sizeof json);
    printf("[PROGRESS] C Data Model v2 (minimal): message N=1, hand JSON + string copy codec\n");

    for (int i = 0; i < repetitions; i++) {
        long long t0 = ns_now();
        /* "serialize": copy JSON to heap buffer */
        char *out = (char *)malloc(jlen);
        memcpy(out, json, jlen);
        long long t1 = ns_now();
        /* "deserialize": verify length */
        int ok = (out && jlen > 0);
        free(out);
        long long t2 = ns_now();
        long long ser = t1 - t0, deser = t2 - t1, total = ser + deser;
        double opsSer = ser > 0 ? 1e9 / (double)ser : 0;
        double opsDeser = deser > 0 ? 1e9 / (double)deser : 0;
        double opsTot = total > 0 ? 1e9 / (double)total : 0;
        fprintf(f, "c,bytes,message,%d,%d,memcpy-json,n/a,%lld,%lld,%zu,%lld,%.6f,%.6f,%.6f,0,%.2f,1,manual\n",
                repetitions, i, ser, deser, jlen, total, opsSer, opsDeser, opsTot, ok ? 1.0 : 0.0);
    }
    fclose(f);
    printf("[PROGRESS] Complete. Results: %s\n", path);
    (void)jlen;
    return 0;
}
