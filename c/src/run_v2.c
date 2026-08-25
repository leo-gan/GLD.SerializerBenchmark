/* Data Model v2: resolve cells, map onto existing fixture kinds, FULL serializer registry.
 * B-1 schedule: prepare once per cell; mode → rep → Fisher–Yates serializers (default). */
#include "bench.h"
#include "schedule.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <errno.h>

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

static char *read_cmd(const char *cmd) {
    FILE *p = popen(cmd, "r");
    if (!p) return NULL;
    size_t cap = 1 << 20, n = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { pclose(p); return NULL; }
    for (;;) {
        if (n + 4096 >= cap) {
            cap *= 2;
            char *nb = (char *)realloc(buf, cap);
            if (!nb) { free(buf); pclose(p); return NULL; }
            buf = nb;
        }
        size_t r = fread(buf + n, 1, 4096, p);
        n += r;
        if (r < 4096) break;
    }
    pclose(p);
    buf[n] = 0;
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) buf[--n] = 0;
    return buf;
}

static test_data_kind_t kind_from_type_id(const char *type_id) {
    if (strcmp(type_id, "message") == 0) return TD_MESSAGE;
    if (strcmp(type_id, "document") == 0) return TD_DOCUMENT;
    if (strcmp(type_id, "telemetry") == 0) return TD_TELEMETRY;
    if (strcmp(type_id, "strings") == 0) return TD_STRINGS;
    if (strcmp(type_id, "event") == 0) return TD_EVENT;
    return TD_MESSAGE;
}

static void fill_v2_fixture(test_fixture_t *fx, const char *type_id, int seed,
                            int children, int points, int str_count, int attr_count) {
    data_make_one(fx, kind_from_type_id(type_id), (uint64_t)seed, 0,
                  children, points, str_count, attr_count);
}

/* Timed trial for one serializer × mode × rep. Returns 0 on success. */
static int run_one_trial(serializer_t *S, test_fixture_t *fx, const char *type_id,
                         const char *mode, int n, uint8_t *buf, size_t buf_cap,
                         int repetitions, int r, const char *type_hash,
                         csv_logger_t *log, int record_ro, int *run_order, int pos) {
    size_t out_len = 0;
    test_fixture_t out_fx;
    memset(&out_fx, 0, sizeof(out_fx));
    out_fx.kind = fx->kind;
    out_fx.batch_n = n;

    uint64_t t0 = bench_now_ns();
    int rc = 0;
    int native_stream = 0;
    if (mode[0] == 's' && S->serialize_fp && S->deserialize_fp) {
        native_stream = 1;
        FILE *wf = fmemopen(buf, buf_cap, "w+");
        if (!wf) rc = -1;
        else {
            rc = S->serialize_fp(fx, wf, &out_len);
            if (rc == 0) {
                if (fflush(wf) != 0) rc = -1;
                else out_len = (size_t)ftell(wf);
            }
            fclose(wf);
        }
    } else {
        rc = bench_serialize_cell(S, fx, buf, buf_cap, &out_len);
        if (rc == 0 && mode[0] == 's') { /* stream: adapted FILE* write */
            rc = bench_stream_write_all(buf, out_len);
        }
    }
    uint64_t t1 = bench_now_ns();
    bench_do_not_optimize(buf);
    bench_do_not_optimize(&out_len);
    if (rc != 0) {
        fprintf(stderr, "[ERROR] %s / %s N=%d / %s: serialize failed\n",
                S->name, type_id, n, mode);
        return -1;
    }
    if (native_stream) {
        FILE *rf = fmemopen(buf, out_len ? out_len : 1, "r");
        if (!rf) rc = -1;
        else {
            rc = S->deserialize_fp(rf, &out_fx, fx->kind);
            fclose(rf);
        }
    } else {
        if (mode[0] == 's') {
            rc = bench_stream_read_all(buf, buf_cap, out_len);
            if (rc != 0) {
                fprintf(stderr, "[ERROR] %s / %s N=%d / %s: stream read failed\n",
                        S->name, type_id, n, mode);
                return -1;
            }
        }
        rc = bench_deserialize_cell(S, buf, out_len, &out_fx, fx->kind);
    }
    uint64_t t2 = bench_now_ns();
    bench_do_not_optimize(&out_fx);
    if (rc != 0) {
        fprintf(stderr, "[ERROR] %s / %s N=%d / %s: deserialize failed\n",
                S->name, type_id, n, mode);
        if (out_fx.batch) { free(out_fx.batch); out_fx.batch = NULL; }
        return -1;
    }
    bool ok = bench_fidelity_cell(S, fx, &out_fx);
    if (out_fx.batch) { free(out_fx.batch); out_fx.batch = NULL; }
    if (!ok) {
        fprintf(stderr, "[ERROR] %s / %s N=%d / %s: fidelity failed\n",
                S->name, type_id, n, mode);
        return -1;
    }
    int ro = -1, sp = -1;
    if (record_ro) {
        ro = *run_order;
        sp = pos;
        (*run_order)++;
    }
    {
        const char *sm = "";
        if (mode && strcmp(mode, "stream") == 0)
            sm = native_stream ? "native" : "adapted";
        size_t gz = 0, zs = 0;
        bench_compress_sizes(buf, out_len, &gz, &zs);
        csv_logger_write(log, mode, type_id, repetitions, r, S->name,
                         t1 - t0, t2 - t1, out_len, 1.0, S->version,
                         n, type_hash, sm, ro, sp, gz, zs);
    }
    return 0;
}

int run_benchmarks_v2(int repetitions, const char *log_dir) {
    char root_buf[512] = ".";
    if (getenv("BENCHMARK_REPO_ROOT") && getenv("BENCHMARK_REPO_ROOT")[0]) {
        snprintf(root_buf, sizeof root_buf, "%s", getenv("BENCHMARK_REPO_ROOT"));
    } else {
        if (realpath("..", root_buf) == NULL) {
            if (realpath("../..", root_buf) == NULL) strcpy(root_buf, ".");
        }
        char cand[640];
        snprintf(cand, sizeof cand, "%s/config/benchmark_config.yaml", root_buf);
        FILE *tf = fopen(cand, "r");
        if (!tf) {
            snprintf(cand, sizeof cand, "%s/../config/benchmark_config.yaml", root_buf);
            tf = fopen(cand, "r");
            if (tf) {
                char up[512];
                if (realpath(root_buf, up)) {
                    char *slash = strrchr(up, '/');
                    if (slash && slash != up) { *slash = 0; snprintf(root_buf, sizeof root_buf, "%s", up); }
                }
                fclose(tf);
            }
        } else fclose(tf);
    }
    const char *root = root_buf;

    char ts[64];
    const char *env_ts = getenv("BENCHMARK_TS");
    if (env_ts && env_ts[0]) snprintf(ts, sizeof ts, "%s", env_ts);
    else {
        time_t t = time(NULL);
        struct tm tm;
        localtime_r(&t, &tm);
        strftime(ts, sizeof ts, "%Y-%m-%d-%H%M%S", &tm);
    }
    mkdir_p(log_dir);
    char path[1024];
    snprintf(path, sizeof path, "%s/%s.csv", log_dir, ts);
    csv_logger_t *log = csv_logger_create(path);
    if (!log) {
        fprintf(stderr, "Cannot create log %s\n", path);
        return 1;
    }

    serializer_t sers[BENCH_MAX_SERIALIZERS];
    int ser_count = 0;
    register_all_serializers(sers, &ser_count);

    uint64_t seed = 42;
    if (getenv("BENCHMARK_SEED") && getenv("BENCHMARK_SEED")[0])
        seed = (uint64_t)strtoull(getenv("BENCHMARK_SEED"), NULL, 10);
    char cfg_path[1024];
    if (getenv("BENCHMARK_RUN_CONFIG") && getenv("BENCHMARK_RUN_CONFIG")[0])
        snprintf(cfg_path, sizeof cfg_path, "%s", getenv("BENCHMARK_RUN_CONFIG"));
    else
        snprintf(cfg_path, sizeof cfg_path, "%s/config/library/default.yaml", root);

    char resolve_cmd[2048];
    snprintf(resolve_cmd, sizeof resolve_cmd,
             "PYTHONPATH='%s/analysis/src' python3 '%s/scripts/resolve_run_config.py' '%s' --seed %llu",
             root, root, cfg_path, (unsigned long long)seed);
    char *resolved = read_cmd(resolve_cmd);
    if (!resolved || !resolved[0]) {
        fprintf(stderr, "[ERROR] resolve_run_config failed\n");
        free(resolved);
        csv_logger_close(log);
        return 1;
    }
    char tmpj[256];
    snprintf(tmpj, sizeof tmpj, "/tmp/c_v2_cells_%d.json", (int)getpid());
    FILE *tj = fopen(tmpj, "w");
    fputs(resolved, tj);
    fclose(tj);
    free(resolved);

    char cells_py[256];
    snprintf(cells_py, sizeof cells_py, "/tmp/c_v2_list_%d.py", (int)getpid());
    FILE *cspf = fopen(cells_py, "w");
    fprintf(cspf,
            "import json,sys\n"
            "d=json.load(open(sys.argv[1]))\n"
            "for c in d['cells']:\n"
            "    tc=c.get('type_config') or {}\n"
            "    print(c['type_id'], c['data_type_instance_count'], "
            "c.get('type_config_hash',''),\n"
            "          int(tc.get('points', 32)), int(tc.get('children', 8)),\n"
            "          int(tc.get('count', 32)), int(tc.get('attr_count', 4)),\n"
            "          sep='\\t')\n");
    fclose(cspf);
    char cells_cmd[512];
    snprintf(cells_cmd, sizeof cells_cmd, "python3 %s %s", cells_py, tmpj);
    FILE *cp = popen(cells_cmd, "r");
    if (!cp) { csv_logger_close(log); unlink(tmpj); unlink(cells_py); return 1; }

    /* Harness-owned encode/decode scratch (issue #59): fixed capacity, reused. */
    static uint8_t buf[8 * 1024 * 1024];
    const char *modes[] = { "bytes", "stream" };
    const int n_modes = 2;
    char line[512];
    int cells = 0;
    const char *strategy = schedule_resolve_strategy();
    int record_ro = schedule_resolve_record_run_order();
    int run_order = 0;
    printf("[PROGRESS] C suite cells: %d serializers schedule=%s record_run_order=%d seed=%llu\n",
           ser_count, strategy, record_ro, (unsigned long long)seed);

    while (fgets(line, sizeof line, cp)) {
        char type_id[64] = {0};
        char type_hash[128] = {0};
        int n = 1;
        int points = 32, children = 8, str_count = 32, attr_count = 4;
        /* type_id \t N \t hash \t points \t children \t count \t attr_count */
        char *toks[8] = {0};
        int nt = 0;
        for (char *t = strtok(line, "\t\r\n"); t && nt < 7; t = strtok(NULL, "\t\r\n"))
            toks[nt++] = t;
        if (nt < 2) continue;
        strncpy(type_id, toks[0], sizeof type_id - 1);
        n = atoi(toks[1]);
        if (nt >= 3) {
            size_t hl = strlen(toks[2]);
            if (hl >= sizeof type_hash) hl = sizeof type_hash - 1;
            memcpy(type_hash, toks[2], hl);
            type_hash[hl] = 0;
        }
        if (nt >= 4) points = atoi(toks[3]);
        if (nt >= 5) children = atoi(toks[4]);
        if (nt >= 6) str_count = atoi(toks[5]);
        if (nt >= 7) attr_count = atoi(toks[6]);
        if (n < 1) n = 1;
        if (points < 0) points = 0;
        printf("[PROGRESS] Cell %s N=%d hash=%s points=%d\n",
               type_id, n, type_hash, points);
        cells++;

        /* Build N single-instance fixtures (seeded per index). */
        test_fixture_t *items = (test_fixture_t *)calloc((size_t)n, sizeof(test_fixture_t));
        if (!items) {
            fprintf(stderr, "[ERROR] OOM batch N=%d\n", n);
            continue;
        }
        for (int i = 0; i < n; i++) {
            fill_v2_fixture(&items[i], type_id, (int)seed + cells * 1000 + i,
                            children, points, str_count, attr_count);
            items[i].batch_n = 1;
            items[i].batch = NULL;
            items[i].name = type_id;
        }

        test_fixture_t fx;
        memset(&fx, 0, sizeof(fx));
        char *name_owned = strdup(type_id);
        fx.name = name_owned;
        fx.kind = items[0].kind;
        fx.batch_n = n;
        if (n == 1) {
            fx = items[0];
            fx.name = name_owned;
            fx.batch_n = 1;
            fx.batch = NULL;
            free(items);
            items = NULL;
        } else {
            fx.batch = items;
            /* peek first instance fields for codecs that only inspect union head */
            fx.message = items[0].message;
            fx.document = items[0].document;
            fx.telemetry = items[0].telemetry;
            fx.strings = items[0].strings;
            fx.event = items[0].event;
        }

        /* Untimed prepare once per cell; collect eligible serializers. */
        int ready_idx[BENCH_MAX_SERIALIZERS];
        int ready_n = 0;
        int failed[BENCH_MAX_SERIALIZERS];
        memset(failed, 0, sizeof failed);
        for (int si = 0; si < ser_count; si++) {
            serializer_t *S = &sers[si];
            if (S->supports && !S->supports(fx.kind)) continue;
            const test_fixture_t *prep_fx = (n > 1 && fx.batch) ? &fx.batch[0] : &fx;
            if (S->prepare && S->prepare(fx.kind, prep_fx) != 0) {
                failed[si] = 1;
                continue;
            }
            ready_idx[ready_n++] = si;
        }

        if (strcmp(strategy, "none") == 0) {
            /* Legacy: serializer → mode → all reps */
            for (int ri = 0; ri < ready_n; ri++) {
                int si = ready_idx[ri];
                serializer_t *S = &sers[si];
                for (int mi = 0; mi < n_modes; mi++) {
                    const char *mode = modes[mi];
                    int had_error = 0;
                    for (int r = 0; r < repetitions; r++) {
                        if (had_error) break;
                        if (run_one_trial(S, &fx, type_id, mode, n, buf, sizeof(buf),
                                          repetitions, r, type_hash, log,
                                          record_ro, &run_order, 0) != 0) {
                            had_error = 1;
                            failed[si] = 1;
                        }
                    }
                }
            }
        } else {
            /* block_shuffle: mode → rep → shuffled serializers */
            for (int mi = 0; mi < n_modes; mi++) {
                const char *mode = modes[mi];
                for (int r = 0; r < repetitions; r++) {
                    /* Build eligible list for this rep */
                    int elig[BENCH_MAX_SERIALIZERS];
                    int elig_n = 0;
                    for (int ri = 0; ri < ready_n; ri++) {
                        int si = ready_idx[ri];
                        if (!failed[si]) elig[elig_n++] = si;
                    }
                    if (elig_n == 0) continue;
                    uint64_t shuf_seed = schedule_derive_seed(
                        seed, type_id, n, type_hash, mode, r);
                    int order[BENCH_MAX_SERIALIZERS];
                    schedule_fisher_yates_indices(order, elig_n, shuf_seed);
                    /* Remap order through elig[] */
                    for (int pos = 0; pos < elig_n; pos++) {
                        int si = elig[order[pos]];
                        if (failed[si]) continue;
                        serializer_t *S = &sers[si];
                        if (run_one_trial(S, &fx, type_id, mode, n, buf, sizeof(buf),
                                          repetitions, r, type_hash, log,
                                          record_ro, &run_order, pos) != 0) {
                            failed[si] = 1;
                        }
                    }
                }
            }
        }
        free(name_owned);
        if (items) free(items);
        else if (fx.batch) free(fx.batch);
    }
    pclose(cp);
    unlink(tmpj);
    unlink(cells_py);
    csv_logger_close(log);
    printf("[PROGRESS] C suite complete (%d cells, %d serializers) → %s\n",
           cells, ser_count, path);
    return 0;
}
