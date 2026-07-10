#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    int reps = 10;
    const char *log_dir = getenv("LOG_DIR");
    if (!log_dir) log_dir = "../logs/c";

    if (argc > 1) reps = atoi(argv[1]);
    if (argc > 4) log_dir = argv[4];
    /* argv[2]/argv[3] ser/data filters reserved for future v2 filtering */

    /* Data Model v2 only (V1 Person/EDI fixtures removed from the run path). */
    extern int run_benchmarks_v2(int repetitions, const char *log_dir);
    return run_benchmarks_v2(reps, log_dir);
}
