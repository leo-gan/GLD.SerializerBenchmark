#include "bench.h"
#include <stdlib.h>
#include <string.h>

struct csv_logger {
    FILE *f;
};

csv_logger_t *csv_logger_create(const char *path) {
    csv_logger_t *L = calloc(1, sizeof(*L));
    if (!L) return NULL;
    L->f = fopen(path, "w");
    if (!L->f) { free(L); return NULL; }
    fprintf(L->f,
        "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,"
        "TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,"
        "MemoryPeakBytes,FidelityScore,SerializerVersion\n");
    return L;
}

void csv_logger_write(csv_logger_t *L, const char *mode, const char *td,
                      int reps, int rep_idx, const char *ser,
                      uint64_t ser_ns, uint64_t deser_ns, size_t size,
                      double fidelity, const char *version) {
    if (!L || !L->f) return;
    uint64_t tot = ser_ns + deser_ns;
    double ops_s = ser_ns ? 1e9 / (double)ser_ns : 0;
    double ops_d = deser_ns ? 1e9 / (double)deser_ns : 0;
    double ops_t = tot ? 1e9 / (double)tot : 0;
    fprintf(L->f,
        "c,%s,%s,%d,%d,%s,%llu,%llu,%zu,%llu,%.6f,%.6f,%.6f,0,%.1f,%s\n",
        mode, td, reps, rep_idx, ser,
        (unsigned long long)ser_ns, (unsigned long long)deser_ns, size,
        (unsigned long long)tot, ops_s, ops_d, ops_t, fidelity,
        version ? version : "");
}

void csv_logger_close(csv_logger_t *L) {
    if (!L) return;
    if (L->f) fclose(L->f);
    free(L);
}
