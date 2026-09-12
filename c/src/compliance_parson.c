#ifdef HAS_PARSON
#include "compliance_decode.h"
#include <stdlib.h>
#include <string.h>
#include "parson_pref.h"
#include "parson.h"

int cmp_dec_parson(const unsigned char *data, size_t n, const struct cJSON *schema) {
  (void)schema;
  char *tmp = malloc(n + 1);
  if (!tmp) return -1;
  memcpy(tmp, data, n);
  tmp[n] = 0;
  JSON_Value *v = json_parse_string(tmp);
  free(tmp);
  if (!v) return -1;
  json_value_free(v);
  return 0;
}
#endif
