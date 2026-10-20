#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    int reps = 10;
    const char *log_dir = getenv("LOG_DIR");
    if (!log_dir) log_dir = "../logs/c";

    const char *ser_filter = NULL;
    const char *data_filter = NULL;

    if (argc > 1) reps = atoi(argv[1]);
    if (argc > 2 && argv[2][0]) ser_filter = argv[2];
    if (argc > 3 && argv[3][0]) data_filter = argv[3];
    if (argc > 4) log_dir = argv[4];

    /* Suite fixtures: message / document / telemetry / strings / event.
     * argv[2]/argv[3] are case-insensitive substring filters (serializer, type). */
    extern int run_benchmarks_v2(int repetitions, const char *log_dir,
                                 const char *ser_filter, const char *data_filter);
    return run_benchmarks_v2(reps, log_dir, ser_filter, data_filter);
}
