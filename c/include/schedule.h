/* B-1 deterministic block_shuffle schedule (must match analysis golden vector). */
#ifndef BENCH_SCHEDULE_H
#define BENCH_SCHEDULE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Normalize mode: string/buffer → bytes; Stream → stream; lowercase. */
void schedule_normalize_mode(const char *mode, char *out, size_t out_cap);

/* 64-bit seed: first 8 bytes of SHA-256(key) little-endian. */
uint64_t schedule_derive_seed(uint64_t base_seed,
                              const char *type_id,
                              int instance_count,
                              const char *type_config_hash,
                              const char *mode,
                              int rep);

/* Fisher–Yates shuffle of indices 0..n-1 into *out (must hold n ints). */
void schedule_fisher_yates_indices(int *out, int n, uint64_t seed);

/* Fisher–Yates on an array of string pointers (shuffles in place via copy into out). */
void schedule_fisher_yates_cstr(const char **items, int n, uint64_t seed, const char **out);

/* Env BENCHMARK_SCHEDULE: none | block_shuffle (default). */
const char *schedule_resolve_strategy(void);

/* Env BENCHMARK_RECORD_RUN_ORDER: 0/false/no → false; else true. */
int schedule_resolve_record_run_order(void);

/* Golden: A,B,C @ 42|message|1|abc|bytes|0 → C,B,A; seed == 15992650003647724414.
 * Returns 0 on success, non-zero on mismatch. */
int schedule_verify_golden(void);

#ifdef __cplusplus
}
#endif

#endif /* BENCH_SCHEDULE_H */
