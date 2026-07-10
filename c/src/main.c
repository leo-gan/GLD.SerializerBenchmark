#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    int reps = 10;
    const char *ser_f = NULL;
    const char *data_f = NULL;
    const char *log_dir = getenv("LOG_DIR");
    if (!log_dir) log_dir = "../logs/c";

    if (argc > 1) reps = atoi(argv[1]);
    if (argc > 2) ser_f = argv[2];
    if (argc > 3) data_f = argv[3];
    if (argc > 4) log_dir = argv[4];

    const char *dm = getenv("BENCHMARK_DATA_MODEL");
    if (dm && (strcmp(dm, "v2") == 0 || strcmp(dm, "2") == 0)) {
        /* declare in run_v2.c */
        extern int run_benchmarks_v2(int repetitions, const char *log_dir);
        return run_benchmarks_v2(reps, log_dir);
    }
    return run_benchmarks(reps, ser_f, data_f, log_dir);
}
