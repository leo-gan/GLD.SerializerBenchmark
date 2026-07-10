/* Data Model v2 for C: resolve cells via python, export payloads via python generators,
 * time memcpy-json + cJSON + yyjson when available. */
#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <errno.h>

#ifdef HAS_CJSON
#include "cJSON.h"
#endif
#ifdef HAS_YYJSON
#include "yyjson.h"
#endif

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

static char *export_payload(const char *root, const char *type_id, int n, int seed, const char *cfg_json) {
    char cmd[16384];
    /* Escape single quotes in cfg_json for shell */
    snprintf(cmd, sizeof cmd,
        "PYTHONPATH='%s/python/src:%s/analysis/src' python3 -c '"
        "import json; from dataclasses import is_dataclass, fields; "
        "from benchmark.data_v2.generator import instances_for_cell; "
        "type_id=%s; n=%d; seed=%d; cfg=json.loads(%s); "
        "def toj(o):\n"
        "  if is_dataclass(o) and not isinstance(o, type):\n"
        "    return {f.name: toj(getattr(o, f.name)) for f in fields(o)}\n"
        "  if isinstance(o, list): return [toj(x) for x in o]\n"
        "  return o\n"
        "b=instances_for_cell(type_id,cfg,seed,n); p=b[0] if n==1 else b; "
        "print(json.dumps(toj(p), separators=(\",\", \":\")))"
        "'",
        root, root,
        /* type_id quoted in python */
        "", n, seed, "");
    /* Build without broken format: write helper script */
    char py[256];
    snprintf(py, sizeof py, "/tmp/c_v2_payload_%d.py", (int)getpid());
    FILE *f = fopen(py, "w");
    if (!f) return NULL;
    fprintf(f,
        "import json,sys\n"
        "from dataclasses import is_dataclass, fields\n"
        "from benchmark.data_v2.generator import instances_for_cell\n"
        "type_id=sys.argv[1]\n"
        "n=int(sys.argv[2]); seed=int(sys.argv[3])\n"
        "cfg=json.loads(sys.argv[4])\n"
        "def toj(o):\n"
        "    if is_dataclass(o) and not isinstance(o, type):\n"
        "        return {f.name: toj(getattr(o, f.name)) for f in fields(o)}\n"
        "    if isinstance(o, list): return [toj(x) for x in o]\n"
        "    return o\n"
        "b=instances_for_cell(type_id,cfg,seed,n)\n"
        "p=b[0] if n==1 else b\n"
        "print(json.dumps(toj(p), separators=(',', ':')))\n");
    fclose(f);
    char esc_cfg[8192];
    /* pass cfg as argv - escape for shell via base writing to file */
    char cfgf[256];
    snprintf(cfgf, sizeof cfgf, "/tmp/c_v2_cfg_%d.json", (int)getpid());
    FILE *cf = fopen(cfgf, "w");
    fputs(cfg_json && cfg_json[0] ? cfg_json : "{}", cf);
    fclose(cf);
    snprintf(cmd, sizeof cmd,
             "PYTHONPATH='%s/python/src:%s/analysis/src' python3 %s %s %d %d \"$(cat %s)\"",
             root, root, py, type_id, n, seed, cfgf);
    char *out = read_cmd(cmd);
    unlink(py);
    unlink(cfgf);
    return out;
}

static void write_row(FILE *f, const char *type_id, int reps, int idx, const char *ser,
                      long long ser_ns, long long deser_ns, size_t size, int n, const char *hash) {
    long long total = ser_ns + deser_ns;
    double opsSer = ser_ns > 0 ? 1e9 / (double)ser_ns : 0;
    double opsDeser = deser_ns > 0 ? 1e9 / (double)deser_ns : 0;
    double opsTot = total > 0 ? 1e9 / (double)total : 0;
    fprintf(f,
            "c,bytes,%s,%d,%d,%s,n/a,%lld,%lld,%zu,%lld,%.6f,%.6f,%.6f,0,1.00,%d,%s\n",
            type_id, reps, idx, ser, ser_ns, deser_ns, size, total, opsSer, opsDeser, opsTot, n,
            hash && hash[0] ? hash : "");
}

int run_benchmarks_v2(int repetitions, const char *log_dir) {
    char root_buf[512] = ".";
    if (getenv("BENCHMARK_REPO_ROOT") && getenv("BENCHMARK_REPO_ROOT")[0]) {
        snprintf(root_buf, sizeof root_buf, "%s", getenv("BENCHMARK_REPO_ROOT"));
    } else {
        if (realpath("..", root_buf) == NULL) {
            if (realpath("../..", root_buf) == NULL) strcpy(root_buf, ".");
        }
        /* Prefer monorepo root that contains config/ */
        char cand[640];
        snprintf(cand, sizeof cand, "%s/config/benchmark_config.yaml", root_buf);
        FILE *tf = fopen(cand, "r");
        if (!tf) {
            snprintf(cand, sizeof cand, "%s/../config/benchmark_config.yaml", root_buf);
            tf = fopen(cand, "r");
            if (tf) {
                char up[512];
                if (realpath(root_buf, up)) {
                    /* go up one */
                    char *slash = strrchr(up, '/');
                    if (slash && slash != up) { *slash = 0; snprintf(root_buf, sizeof root_buf, "%s", up); }
                }
                fclose(tf);
            }
        } else fclose(tf);
    }
    const char *root = root_buf;

    char ts[64], path[1024];
    const char *env_ts = getenv("BENCHMARK_TS");
    if (env_ts && env_ts[0]) snprintf(ts, sizeof ts, "%s", env_ts);
    else {
        time_t t = time(NULL);
        struct tm tm;
        localtime_r(&t, &tm);
        strftime(ts, sizeof ts, "%Y-%m-%d-%H%M%S", &tm);
    }
    mkdir_p(log_dir);
    snprintf(path, sizeof path, "%s/%s.csv", log_dir, ts);
    FILE *outf = fopen(path, "w");
    if (!outf) return 1;
    fprintf(outf, "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,"
                  "TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,"
                  "MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash\n");

    int seed = getenv("BENCHMARK_SEED") ? atoi(getenv("BENCHMARK_SEED")) : 42;
    char cfg_path[1024];
    if (getenv("BENCHMARK_RUN_CONFIG") && getenv("BENCHMARK_RUN_CONFIG")[0])
        snprintf(cfg_path, sizeof cfg_path, "%s", getenv("BENCHMARK_RUN_CONFIG"));
    else
        snprintf(cfg_path, sizeof cfg_path, "%s/config/library/default.yaml", root);

    char resolve_cmd[2048];
    snprintf(resolve_cmd, sizeof resolve_cmd,
             "PYTHONPATH='%s/analysis/src' python3 '%s/scripts/resolve_run_config.py' '%s' --seed %d",
             root, root, cfg_path, seed);
    char *resolved = read_cmd(resolve_cmd);
    if (!resolved || !resolved[0]) {
        fprintf(stderr, "[ERROR] resolve_run_config failed\n");
        free(resolved);
        fclose(outf);
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
    if (!cspf) { fclose(outf); unlink(tmpj); return 1; }
    fprintf(cspf,
            "import json,sys\n"
            "d=json.load(open(sys.argv[1]))\n"
            "for c in d['cells']:\n"
            "    print(c['type_id'], c['data_type_instance_count'], c.get('type_config_hash',''),\n"
            "          json.dumps(c.get('type_config') or {}), sep='\\t')\n");
    fclose(cspf);
    char cells_cmd[1024];
    snprintf(cells_cmd, sizeof cells_cmd, "python3 %s %s", cells_py, tmpj);
    FILE *cp = popen(cells_cmd, "r");
    if (!cp) { fclose(outf); unlink(tmpj); unlink(cells_py); return 1; }

    char line[65536];
    int cells = 0;
    while (fgets(line, sizeof line, cp)) {
        char type_id[64]={0}, hash[80]={0}, cfgjson[8192]="{}";
        int n = 1;
        char *t1 = strchr(line, '\t'); if (!t1) continue; *t1=0;
        strncpy(type_id, line, sizeof type_id-1);
        char *t2 = strchr(t1+1, '\t'); if (!t2) continue; *t2=0;
        n = atoi(t1+1);
        char *t3 = strchr(t2+1, '\t');
        if (t3) {
            *t3=0;
            strncpy(hash, t2+1, sizeof hash-1);
            strncpy(cfgjson, t3+1, sizeof cfgjson-1);
            size_t L=strlen(cfgjson);
            while (L && (cfgjson[L-1]=='\n'||cfgjson[L-1]=='\r')) cfgjson[--L]=0;
        } else {
            strncpy(hash, t2+1, sizeof hash-1);
            size_t L=strlen(hash);
            while (L && (hash[L-1]=='\n'||hash[L-1]=='\r')) hash[--L]=0;
        }
        printf("[PROGRESS] Cell %s N=%d\n", type_id, n);
        char *payload = export_payload(root, type_id, n, seed, cfgjson);
        if (!payload) {
            fprintf(stderr, "[WARN] export failed %s\n", type_id);
            continue;
        }
        size_t plen = strlen(payload);
        cells++;

        for (int i = 0; i < repetitions; i++) {
            long long t0 = (long long)bench_now_ns();
            char *copy = (char *)malloc(plen + 1);
            memcpy(copy, payload, plen + 1);
            long long t1 = (long long)bench_now_ns();
            free(copy);
            long long t2 = (long long)bench_now_ns();
            write_row(outf, type_id, repetitions, i, "memcpy-json", t1 - t0, t2 - t1, plen, n, hash);
        }
#ifdef HAS_CJSON
        for (int i = 0; i < repetitions; i++) {
            long long t0 = (long long)bench_now_ns();
            cJSON *rootj = cJSON_Parse(payload);
            char *printed = cJSON_PrintUnformatted(rootj);
            long long t1 = (long long)bench_now_ns();
            cJSON *back = cJSON_Parse(printed ? printed : "");
            long long t2 = (long long)bench_now_ns();
            size_t sz = printed ? strlen(printed) : 0;
            cJSON_Delete(rootj); cJSON_Delete(back); free(printed);
            write_row(outf, type_id, repetitions, i, "cJSON", t1 - t0, t2 - t1, sz, n, hash);
        }
#endif
#ifdef HAS_YYJSON
        for (int i = 0; i < repetitions; i++) {
            long long t0 = (long long)bench_now_ns();
            yyjson_doc *doc = yyjson_read(payload, plen, 0);
            char *printed = yyjson_write(doc, 0, NULL);
            long long t1 = (long long)bench_now_ns();
            yyjson_doc *back = yyjson_read(printed, printed ? strlen(printed) : 0, 0);
            long long t2 = (long long)bench_now_ns();
            size_t sz = printed ? strlen(printed) : 0;
            yyjson_doc_free(doc); yyjson_doc_free(back); free(printed);
            write_row(outf, type_id, repetitions, i, "yyjson", t1 - t0, t2 - t1, sz, n, hash);
        }
#endif
        free(payload);
    }
    pclose(cp);
    unlink(tmpj);
    unlink(cells_py);
    fclose(outf);
    printf("[PROGRESS] C Data Model v2 complete (%d cells) → %s\n", cells, path);
    return 0;
}
