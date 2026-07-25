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
        "SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,"
        "OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash,"
        "RunOrder,SchedulePosition\n");
    return L;
}

void csv_logger_write(csv_logger_t *L, const char *mode, const char *td,
                      int reps, int rep_idx, const char *ser,
                      uint64_t ser_ns, uint64_t deser_ns, size_t size,
                      double fidelity, const char *version,
                      int instance_count, const char *type_config_hash,
                      int run_order, int schedule_position) {
    if (!L || !L->f) return;
    uint64_t tot = ser_ns + deser_ns;
    double ops_s = ser_ns ? 1e9 / (double)ser_ns : 0;
    double ops_d = deser_ns ? 1e9 / (double)deser_ns : 0;
    double ops_t = tot ? 1e9 / (double)tot : 0;
    if (instance_count < 1) instance_count = 1;
    char ro[32] = "", sp[32] = "";
    if (run_order >= 0) snprintf(ro, sizeof ro, "%d", run_order);
    if (schedule_position >= 0) snprintf(sp, sizeof sp, "%d", schedule_position);
    fprintf(L->f,
        "c,%s,%s,%d,%d,%s,%s,%llu,%llu,%zu,%llu,%.6f,%.6f,%.6f,0,%.1f,%d,%s,%s,%s\n",
        mode, td, reps, rep_idx, ser, version ? version : "",
        (unsigned long long)ser_ns, (unsigned long long)deser_ns, size,
        (unsigned long long)tot, ops_s, ops_d, ops_t, fidelity,
        instance_count, type_config_hash ? type_config_hash : "",
        ro, sp);
}

void csv_logger_close(csv_logger_t *L) {
    if (!L) return;
    if (L->f) fclose(L->f);
    free(L);
}
