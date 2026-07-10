/* Data Model v2 stub — make_one API placeholder for harness cutover. */
#include "data_v2.h"
#include <stdlib.h>

struct dv2_instance {
  dv2_type_id_t type_id;
  uint64_t seed;
  int index;
};

int dv2_make_one(dv2_type_id_t type_id, uint64_t seed, int instance_index, dv2_instance_t **out) {
  if (!out) return -1;
  dv2_instance_t *p = calloc(1, sizeof(*p));
  if (!p) return -1;
  p->type_id = type_id;
  p->seed = seed;
  p->index = instance_index;
  *out = p;
  return 0;
}

void dv2_free(dv2_instance_t *inst) { free(inst); }
