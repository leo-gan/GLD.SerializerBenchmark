#ifdef HAS_JSON_C
#include "compliance_decode.h"
#include <json-c/json.h>

int cmp_dec_json_c(const unsigned char *data, size_t n, const struct cJSON *schema) {
  (void)schema;
  struct json_tokener *tok = json_tokener_new();
  if (!tok) return -1;
  struct json_object *obj = json_tokener_parse_ex(tok, (const char *)data, (int)n);
  int ok = obj != NULL && json_tokener_get_error(tok) == json_tokener_success;
  if (obj) json_object_put(obj);
  json_tokener_free(tok);
  return ok ? 0 : -1;
}
#endif
