#ifdef HAS_LIBCBOR
#include "compliance_decode.h"
#include "../third_party/libcbor/src/cbor.h"

int cmp_dec_libcbor(const unsigned char *data, size_t n, const struct cJSON *schema) {
  (void)schema;
  struct cbor_load_result res;
  cbor_item_t *item = cbor_load(data, n, &res);
  if (!item) return -1;
  cbor_decref(&item);
  return 0;
}
#endif
