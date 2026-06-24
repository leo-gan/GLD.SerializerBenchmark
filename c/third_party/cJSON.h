/* Minimal cJSON subset for benchmark - API compatible subset */
#ifndef cJSON__h
#define cJSON__h
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
#define cJSON_Invalid (0)
#define cJSON_False  (1 << 0)
#define cJSON_True   (1 << 1)
#define cJSON_NULL   (1 << 2)
#define cJSON_Number (1 << 3)
#define cJSON_String (1 << 4)
#define cJSON_Array  (1 << 5)
#define cJSON_Object (1 << 6)
typedef struct cJSON {
    struct cJSON *next, *prev, *child;
    int type;
    char *valuestring;
    int valueint;
    double valuedouble;
    char *string;
} cJSON;
cJSON *cJSON_Parse(const char *value);
char *cJSON_PrintUnformatted(const cJSON *item);
void cJSON_Delete(cJSON *item);
cJSON *cJSON_CreateObject(void);
cJSON *cJSON_CreateArray(void);
cJSON *cJSON_CreateString(const char *s);
cJSON *cJSON_CreateNumber(double num);
cJSON *cJSON_CreateBool(int b);
cJSON *cJSON_AddItemToObject(cJSON *obj, const char *name, cJSON *item);
cJSON *cJSON_AddItemToArray(cJSON *arr, cJSON *item);
cJSON *cJSON_GetObjectItem(const cJSON *obj, const char *name);
int cJSON_GetArraySize(const cJSON *arr);
cJSON *cJSON_GetArrayItem(const cJSON *arr, int index);
const char *cJSON_GetErrorPtr(void);
#ifdef __cplusplus
}
#endif
#endif
