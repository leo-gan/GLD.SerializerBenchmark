#ifndef COMPLIANCE_DECODE_H
#define COMPLIANCE_DECODE_H
#include <stddef.h>
struct cJSON;
int cmp_dec_tinycbor(const unsigned char *data, size_t n, const struct cJSON *schema);
int cmp_dec_libcbor(const unsigned char *data, size_t n, const struct cJSON *schema);
int cmp_dec_parson(const unsigned char *data, size_t n, const struct cJSON *schema);
int cmp_dec_json_c(const unsigned char *data, size_t n, const struct cJSON *schema);
#endif
