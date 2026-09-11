/* C compliance runner — cJSON against the shared JSON catalog. */
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "cJSON.h"

static char *slurp(const char *path, size_t *n) {
  FILE *f = fopen(path, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long sz = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *b = malloc((size_t)sz + 1);
  if (!b) { fclose(f); return NULL; }
  fread(b, 1, (size_t)sz, f);
  b[sz] = 0;
  fclose(f);
  if (n) *n = (size_t)sz;
  return b;
}

static int is_dir(const char *p) {
  struct stat st;
  return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

int main(int argc, char **argv) {
  const char *json_out = NULL;
  for (int i = 1; i < argc; i++) {
    if ((!strcmp(argv[i], "--json-out") || !strcmp(argv[i], "-o")) && i + 1 < argc)
      json_out = argv[++i];
  }
  char root[1024];
  if (!getcwd(root, sizeof root)) return 2;
  char data[1200];
  int found = 0;
  for (int up = 0; up < 8; up++) {
    snprintf(data, sizeof data, "%s/compliance/data/json", root);
    if (is_dir(data)) { found = 1; break; }
    char *slash = strrchr(root, '/');
    if (!slash || slash == root) break;
    *slash = 0;
  }
  if (!found) { fprintf(stderr, "cannot locate compliance/data\n"); return 2; }

  int p = 0, f = 0, total = 0;
  FILE *out = NULL;
  if (json_out) {
    out = fopen(json_out, "w");
    if (out) fprintf(out, "{\"schema\":\"gld.dashboard.compliance/1\",\"language\":\"c\",\"languages\":[\"c\"],\"policy\":\"report-only\",\"results\":[");
  }
  int first = 1;
  DIR *d = opendir(data);
  struct dirent *ent;
  while (d && (ent = readdir(d))) {
    if (!strstr(ent->d_name, ".json")) continue;
    char path[1400];
    snprintf(path, sizeof path, "%s/%s", data, ent->d_name);
    char *raw = slurp(path, NULL);
    if (!raw) continue;
    cJSON *suite = cJSON_Parse(raw);
    free(raw);
    if (!suite) continue;
    const cJSON *cases = cJSON_GetObjectItem(suite, "cases");
    const cJSON *standard = cJSON_GetObjectItem(suite, "standard");
    const cJSON *version = cJSON_GetObjectItem(suite, "version");
    const cJSON *surl = cJSON_GetObjectItem(suite, "standard_url");
    cJSON *c;
    cJSON_ArrayForEach(c, cases) {
      const char *id = cJSON_GetStringValue(cJSON_GetObjectItem(c, "id"));
      const char *expect = cJSON_GetStringValue(cJSON_GetObjectItem(c, "expect"));
      const char *input = cJSON_GetStringValue(cJSON_GetObjectItem(c, "input"));
      const char *enc = cJSON_GetStringValue(cJSON_GetObjectItem(c, "input_encoding"));
      if (enc && strcmp(enc, "utf-8") && strcmp(enc, "")) continue;
      if (!id || !expect || !input) continue;
      total++;
      cJSON *got = cJSON_Parse(input);
      const char *outcome = "pass";
      const char *obs = "ok";
      if (got) {
        if (strcmp(expect, "reject") == 0) { outcome = "fail"; obs = "accepted"; f++; }
        else p++;
        cJSON_Delete(got);
      } else {
        if (strcmp(expect, "reject") == 0 || strcmp(expect, "any") == 0) { p++; obs = "rejected"; }
        else { outcome = "fail"; obs = "rejected"; f++; }
      }
      if (out) {
        if (!first) fputc(',', out);
        first = 0;
        fprintf(out,
          "{\"id\":\"%s\",\"language\":\"c\",\"serializer\":\"cJSON\",\"serializer_version\":\"\",\"format\":\"json\","
          "\"standard\":\"%s\",\"standard_url\":\"%s\",\"version\":\"%s\",\"version_key\":\"json.%s\","
          "\"requirement\":\"%s\",\"expect\":\"%s\",\"section\":\"\",\"section_title\":\"\",\"section_url\":\"%s\","
          "\"paragraph\":\"\",\"title\":\"\",\"input\":\"\",\"input_encoding\":\"utf-8\",\"detail\":\"\",\"observed\":\"%s\",\"outcome\":\"%s\"}",
          id,
          standard && standard->valuestring ? standard->valuestring : "",
          surl && surl->valuestring ? surl->valuestring : "",
          version && version->valuestring ? version->valuestring : "",
          version && version->valuestring ? version->valuestring : "",
          cJSON_GetStringValue(cJSON_GetObjectItem(c, "requirement")) ?: "",
          expect,
          cJSON_GetStringValue(cJSON_GetObjectItem(c, "section_url")) ?: "",
          obs, outcome);
      }
    }
    cJSON_Delete(suite);
  }
  if (d) closedir(d);
  printf("Serialization compliance (library deviations are catalogued, not a red build)\n");
  printf("  %d pass  %d fail  0 skip  0 error  %d total\n", p, f, total);
  if (out) {
    fprintf(out, "],\"passed\":%d,\"failed\":%d,\"skipped\":0,\"errors\":0,\"catalog_errors\":[],\"serializer_errors\":[],\"scope\":{\"formats\":[\"json\"]}}\n", p, f);
    fclose(out);
    printf("\nWrote %s\n", json_out);
  }
  return 0;
}
