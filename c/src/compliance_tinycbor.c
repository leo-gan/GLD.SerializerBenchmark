#ifdef HAS_TINYCBOR
#include "compliance_decode.h"
#include "tinycbor_pref.h"

int cmp_dec_tinycbor(const unsigned char *data, size_t n, const struct cJSON *schema) {
  (void)schema;
  CborParser parser;
  CborValue it;
  if (cbor_parser_init(data, n, 0, &parser, &it) != CborNoError) return -1;
  if (cbor_value_validate_basic(&it) != CborNoError) return -1;
  return 0;
}
#endif
