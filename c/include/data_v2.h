/* Data Model v2 — generators (within-language deterministic).
 * Cross-language payload identity is not required.
 * Full C runner wiring is pending; types align with docs/analysis/data_model_v2.md.
 */
#ifndef DATA_V2_H
#define DATA_V2_H
#include <stddef.h>
#include <stdint.h>

typedef enum {
  DV2_MESSAGE = 0,
  DV2_DOCUMENT,
  DV2_TELEMETRY,
  DV2_STRINGS,
  DV2_EVENT
} dv2_type_id_t;

/* Opaque instance handle for future harness integration. */
typedef struct dv2_instance dv2_instance_t;

/* Returns 0 on success. Caller frees with dv2_free. */
int dv2_make_one(dv2_type_id_t type_id, uint64_t seed, int instance_index, dv2_instance_t **out);
void dv2_free(dv2_instance_t *inst);

#endif
