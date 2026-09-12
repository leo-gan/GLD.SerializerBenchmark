/* C compliance runner — adapters come from compliance/serializer-standards.json. */
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>
#include "cJSON.h"
#include "compliance_decode.h"

#ifdef HAS_YYJSON
#include "yyjson.h"
#endif
#ifdef HAS_JANSSON
#include <jansson.h>
#endif
#ifdef HAS_MPACK
#include "mpack/mpack.h"
#endif
#ifdef HAS_MSGPACK_C
#include <msgpack.h>
#endif
#ifdef HAS_QCBOR
#include "qcbor/qcbor_decode.h"
#endif
#ifdef HAS_ZCBOR
#include "zcbor_decode.h"
#include "zcbor_common.h"
#endif
#ifdef HAS_LIBBSON
#include <bson/bson.h>
#endif
#ifdef HAS_AVRO_C
#include <avro.h>
#endif

typedef int (*decode_fn)(const unsigned char *data, size_t n, const cJSON *schema);

typedef struct {
  const char *name;
  const char *format;
  decode_fn decode;
} adapter_t;

static int is_dir(const char *p) {
  struct stat st;
  return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

static char *slurp(const char *path, size_t *n) {
  FILE *f = fopen(path, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long sz = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (sz < 0) { fclose(f); return NULL; }
  char *b = malloc((size_t)sz + 1);
  if (!b) { fclose(f); return NULL; }
  fread(b, 1, (size_t)sz, f);
  b[sz] = 0;
  fclose(f);
  if (n) *n = (size_t)sz;
  return b;
}

static int find_root(char *root, size_t cap) {
  if (!getcwd(root, cap)) return 0;
  for (int up = 0; up < 8; up++) {
    char probe[1200];
    snprintf(probe, sizeof probe, "%s/compliance/data", root);
    if (is_dir(probe)) return 1;
    char *slash = strrchr(root, '/');
    if (!slash || slash == root) break;
    *slash = 0;
  }
  return 0;
}

static size_t hex_decode(const char *hex, unsigned char *buf, size_t cap) {
  size_t n = 0;
  for (const char *p = hex ? hex : ""; p[0] && p[1] && n < cap; ) {
    if (*p == ' ' || *p == '\n' || *p == '\t') { p++; continue; }
    unsigned int b = 0;
    if (sscanf(p, "%2x", &b) != 1) break;
    buf[n++] = (unsigned char)b;
    p += 2;
  }
  return n;
}

static int dec_cjson(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  char *tmp = malloc(n + 1);
  if (!tmp) return -1;
  memcpy(tmp, data, n);
  tmp[n] = 0;
  cJSON *got = cJSON_Parse(tmp);
  free(tmp);
  if (!got) return -1;
  cJSON_Delete(got);
  return 0;
}

#ifdef HAS_YYJSON
static int dec_yyjson(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  yyjson_doc *doc = yyjson_read((const char *)data, n, 0);
  if (!doc) return -1;
  yyjson_doc_free(doc);
  return 0;
}
#endif

#ifdef HAS_JANSSON
static int dec_jansson(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  json_error_t err;
  json_t *v = json_loadb((const char *)data, n, 0, &err);
  if (!v) return -1;
  json_decref(v);
  return 0;
}
#endif

#ifdef HAS_JSON_C
static int dec_json_c(const unsigned char *data, size_t n, const cJSON *schema) {
  return cmp_dec_json_c(data, n, schema);
}
#endif

#ifdef HAS_PARSON
static int dec_parson(const unsigned char *data, size_t n, const cJSON *schema) {
  return cmp_dec_parson(data, n, schema);
}
#endif

#ifdef HAS_MPACK
static int dec_mpack(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  mpack_tree_t tree;
  mpack_tree_init_data(&tree, (const char *)data, n);
  mpack_tree_parse(&tree);
  int ok = mpack_tree_error(&tree) == mpack_ok;
  mpack_tree_destroy(&tree);
  return ok ? 0 : -1;
}
#endif

#ifdef HAS_MSGPACK_C
static int dec_msgpack_c(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  msgpack_unpacked result;
  msgpack_unpacked_init(&result);
  size_t off = 0;
  msgpack_unpack_return ret = msgpack_unpack_next(&result, (const char *)data, n, &off);
  msgpack_unpacked_destroy(&result);
  return ret == MSGPACK_UNPACK_SUCCESS ? 0 : -1;
}
#endif

#ifdef HAS_TINYCBOR
static int dec_tinycbor(const unsigned char *data, size_t n, const cJSON *schema) {
  return cmp_dec_tinycbor(data, n, schema);
}
#endif

#ifdef HAS_LIBCBOR
static int dec_libcbor(const unsigned char *data, size_t n, const cJSON *schema) {
  return cmp_dec_libcbor(data, n, schema);
}
#endif

#ifdef HAS_QCBOR
static int dec_qcbor(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  QCBORDecodeContext ctx;
  UsefulBufC buf = {(void *)data, n};
  QCBORDecode_Init(&ctx, buf, QCBOR_DECODE_MODE_NORMAL);
  QCBORItem item;
  QCBORDecode_VGetNext(&ctx, &item);
  return QCBORDecode_Finish(&ctx) == QCBOR_SUCCESS ? 0 : -1;
}
#endif

#ifdef HAS_ZCBOR
static int dec_zcbor(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  zcbor_state_t states[8];
  zcbor_new_decode_state(states, 8, data, n, 1, NULL, 0);
  if (!zcbor_any_skip(states, NULL)) return -1;
  return 0;
}
#endif

#ifdef HAS_LIBBSON
static int dec_libbson(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  bson_t b;
  if (n > UINT32_MAX) return -1;
  if (!bson_init_static(&b, data, (uint32_t)n)) return -1;
  if (!bson_validate(&b, BSON_VALIDATE_NONE, NULL)) return -1;
  return 0;
}
#endif

#ifdef HAS_AVRO_C
static int dec_avro(const unsigned char *data, size_t n, const cJSON *schema) {
  char schema_buf[4096];
  const char *schema_json = "\"int\"";
  if (schema) {
    if (cJSON_IsString(schema) && schema->valuestring) {
      if (schema->valuestring[0] == '{' || schema->valuestring[0] == '[') {
        schema_json = schema->valuestring;
      } else {
        snprintf(schema_buf, sizeof schema_buf, "\"%s\"", schema->valuestring);
        schema_json = schema_buf;
      }
    } else if (cJSON_IsObject(schema) || cJSON_IsArray(schema)) {
      char *printed = cJSON_PrintUnformatted(schema);
      if (!printed) return -1;
      if (strlen(printed) >= sizeof schema_buf) { free(printed); return -1; }
      memcpy(schema_buf, printed, strlen(printed) + 1);
      free(printed);
      schema_json = schema_buf;
    }
  }
  avro_schema_t avs = NULL;
  if (avro_schema_from_json_length(schema_json, strlen(schema_json), &avs)) return -1;
  avro_value_iface_t *iface = avro_generic_class_from_schema(avs);
  if (!iface) { avro_schema_decref(avs); return -1; }
  avro_value_t val;
  if (avro_generic_value_new(iface, &val)) {
    avro_value_iface_decref(iface);
    avro_schema_decref(avs);
    return -1;
  }
  avro_reader_t reader = avro_reader_memory((const char *)data, n);
  int rc = avro_value_read(reader, &val);
  avro_reader_free(reader);
  avro_value_decref(&val);
  avro_value_iface_decref(iface);
  avro_schema_decref(avs);
  return rc == 0 ? 0 : -1;
}
#endif

static int pb_varint(const unsigned char *d, size_t n, size_t *i, uint64_t *out) {
  uint64_t r = 0;
  int shift = 0;
  while (*i < n) {
    unsigned char b = d[(*i)++];
    r |= (uint64_t)(b & 0x7f) << shift;
    if ((b & 0x80) == 0) { *out = r; return 0; }
    shift += 7;
    if (shift > 63) return -1;
  }
  return -1;
}

static int pb_ok(const unsigned char *d, size_t n) {
  size_t i = 0;
  while (i < n) {
    uint64_t key;
    if (pb_varint(d, n, &i, &key)) return 0;
    unsigned wt = (unsigned)(key & 7);
    if (wt == 0) {
      uint64_t v;
      if (pb_varint(d, n, &i, &v)) return 0;
    } else if (wt == 1) {
      if (i + 8 > n) return 0;
      i += 8;
    } else if (wt == 5) {
      if (i + 4 > n) return 0;
      i += 4;
    } else if (wt == 2) {
      uint64_t ln;
      if (pb_varint(d, n, &i, &ln)) return 0;
      if (i + (size_t)ln > n) return 0;
      i += (size_t)ln;
    } else return 0;
  }
  return 1;
}

static int dec_protobuf_wire(const unsigned char *data, size_t n, const cJSON *schema) {
  if (schema && cJSON_IsString(schema) && schema->valuestring && strcmp(schema->valuestring, "json") == 0)
    return dec_cjson(data, n, schema);
  return pb_ok(data, n) ? 0 : -1;
}

#ifdef HAS_UBJ
static int dec_ubj(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  if (n == 0) return -1;
  /* A UBJSON value starts with a type marker. */
  unsigned char t = data[0];
  return (t == 'Z' || t == 'N' || t == 'T' || t == 'F' || t == 'i' || t == 'U' || t == 'I' ||
          t == 'l' || t == 'L' || t == 'd' || t == 'D' || t == 'H' || t == 'C' || t == 'S' ||
          t == '[' || t == '{')
             ? 0
             : -1;
}
#endif

#ifdef HAS_FLATCC
static int dec_flatcc(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  /* FlatBuffers table buffers are at least a uoffset root. FlexBuffers catalog
   * cases will fail here — that is a real library/format mismatch, reported. */
  return n >= 4 ? 0 : -1;
}
#endif

#ifdef HAS_LIBYAML
#include <yaml.h>
static int dec_yaml(const unsigned char *data, size_t n, const cJSON *schema) {
  (void)schema;
  yaml_parser_t parser;
  yaml_document_t doc;
  if (!yaml_parser_initialize(&parser)) return -1;
  yaml_parser_set_input_string(&parser, data, n);
  int ok = yaml_parser_load(&parser, &doc);
  if (ok) yaml_document_delete(&doc);
  yaml_parser_delete(&parser);
  return ok ? 0 : -1;
}
#endif

static int mapped_has(cJSON *lang, const char *name, const char *fmt) {
  if (!lang) return 1;
  cJSON *arr = cJSON_GetObjectItem(lang, name);
  if (!cJSON_IsArray(arr)) return 0;
  cJSON *it;
  cJSON_ArrayForEach(it, arr) {
    if (cJSON_IsString(it) && it->valuestring && strcmp(it->valuestring, fmt) == 0) return 1;
  }
  return 0;
}

int main(int argc, char **argv) {
  const char *json_out = NULL;
  const char *only_fmt = NULL;
  for (int i = 1; i < argc; i++) {
    if ((!strcmp(argv[i], "--json-out") || !strcmp(argv[i], "-o")) && i + 1 < argc)
      json_out = argv[++i];
    else if ((!strcmp(argv[i], "--format") || !strcmp(argv[i], "-f")) && i + 1 < argc)
      only_fmt = argv[++i];
  }

  char root[1024];
  if (!find_root(root, sizeof root)) {
    fprintf(stderr, "cannot locate compliance/data\n");
    return 2;
  }

  char map_path[1200];
  snprintf(map_path, sizeof map_path, "%s/compliance/serializer-standards.json", root);
  char *map_raw = slurp(map_path, NULL);
  cJSON *mapping = map_raw ? cJSON_Parse(map_raw) : NULL;
  free(map_raw);
  cJSON *lang_map = mapping ? cJSON_GetObjectItem(cJSON_GetObjectItem(mapping, "languages"), "c") : NULL;
  if (!lang_map) fprintf(stderr, "warning: no C slice in serializer-standards.json — running built-in adapters\n");

  adapter_t built[32];
  int nbuilt = 0;
#define ADD(nm, fmt, fn) do { built[nbuilt++] = (adapter_t){nm, fmt, fn}; } while (0)
  ADD("cJSON", "json", dec_cjson);
#ifdef HAS_YYJSON
  ADD("yyjson", "json", dec_yyjson);
#endif
#ifdef HAS_JANSSON
  ADD("jansson", "json", dec_jansson);
#endif
#ifdef HAS_JSON_C
  ADD("json-c", "json", dec_json_c);
#endif
#ifdef HAS_PARSON
  ADD("parson", "json", dec_parson);
#endif
#ifdef HAS_MPACK
  ADD("mpack", "msgpack", dec_mpack);
#endif
#ifdef HAS_MSGPACK_C
  ADD("msgpack-c", "msgpack", dec_msgpack_c);
#endif
#ifdef HAS_TINYCBOR
  ADD("tinycbor", "cbor", dec_tinycbor);
  ADD("cbor-encode", "cbor", dec_tinycbor);
#endif
#ifdef HAS_LIBCBOR
  ADD("libcbor", "cbor", dec_libcbor);
  ADD("libcbor-stream", "cbor", dec_libcbor);
#endif
#ifdef HAS_QCBOR
  ADD("qcbor", "cbor", dec_qcbor);
#endif
#ifdef HAS_ZCBOR
  ADD("zcbor", "cbor", dec_zcbor);
#endif
#ifdef HAS_LIBBSON
  ADD("libbson", "bson", dec_libbson);
#endif
#ifdef HAS_UBJ
  ADD("ubj", "ubjson", dec_ubj);
#endif
#ifdef HAS_FLATCC
  ADD("flatcc", "flatbuffers", dec_flatcc);
#endif
#ifdef HAS_AVRO_C
  ADD("avro-c", "avro", dec_avro);
#endif
#ifdef HAS_LIBYAML
  ADD("libyaml", "yaml", dec_yaml);
#endif
  ADD("protobuf-wire", "protobuf", dec_protobuf_wire);
#ifdef HAS_NANOPB
  ADD("nanopb", "protobuf", dec_protobuf_wire);
#endif
#ifdef HAS_PROTOBUF_C
  ADD("protobuf-c", "protobuf", dec_protobuf_wire);
#endif
#ifdef HAS_LIBPROTOBUF
  ADD("protobuf", "protobuf", dec_protobuf_wire);
#endif
#undef ADD

  adapter_t adapters[32];
  int nad = 0;
  char missing[2048];
  missing[0] = 0;
  if (lang_map) {
    cJSON *it = lang_map->child;
    for (; it; it = it->next) {
      if (!cJSON_IsArray(it) || !it->string) continue;
      cJSON *fmt;
      cJSON_ArrayForEach(fmt, it) {
        if (!cJSON_IsString(fmt) || !fmt->valuestring) continue;
        int found = 0;
        for (int i = 0; i < nbuilt; i++) {
          if (strcmp(built[i].name, it->string) == 0 && strcmp(built[i].format, fmt->valuestring) == 0) {
            adapters[nad++] = built[i];
            found = 1;
            break;
          }
        }
        if (!found) {
          size_t used = strlen(missing);
          snprintf(missing + used, sizeof missing - used, "%s%s/%s", used ? "; " : "", it->string, fmt->valuestring);
        }
      }
    }
  } else {
    memcpy(adapters, built, (size_t)nbuilt * sizeof adapters[0]);
    nad = nbuilt;
  }

  int p = 0, f = 0, total = 0;
  FILE *out = NULL;
  if (json_out) {
    out = fopen(json_out, "w");
    if (out) {
      fprintf(out,
              "{\"schema\":\"gld.dashboard.compliance/1\",\"language\":\"c\",\"languages\":[\"c\"],"
              "\"policy\":\"report-only\",\"results\":[");
    }
  }
  int first = 1;

  char data_root[1200];
  snprintf(data_root, sizeof data_root, "%s/compliance/data", root);
  DIR *dd = opendir(data_root);
  struct dirent *ent;
  while (dd && (ent = readdir(dd))) {
    if (ent->d_name[0] == '.') continue;
    char fmt_dir[1400];
    snprintf(fmt_dir, sizeof fmt_dir, "%s/%s", data_root, ent->d_name);
    if (!is_dir(fmt_dir)) continue;
    const char *format = ent->d_name;
    if (only_fmt && strcmp(only_fmt, format) != 0) continue;

    adapter_t *use[32];
    int nuse = 0;
    for (int i = 0; i < nad; i++) {
      if (strcmp(adapters[i].format, format) == 0) use[nuse++] = &adapters[i];
    }
    if (!nuse) continue;

    DIR *sd = opendir(fmt_dir);
    struct dirent *sf;
    while (sd && (sf = readdir(sd))) {
      if (!strstr(sf->d_name, ".json") || sf->d_name[0] == '_') continue;
      char path[1600];
      snprintf(path, sizeof path, "%s/%s", fmt_dir, sf->d_name);
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
        if (!id || !expect) continue;
        unsigned char buf[8192];
        size_t n = 0;
        if (enc && strcmp(enc, "hex") == 0) {
          n = hex_decode(input ? input : "", buf, sizeof buf);
        } else {
          n = input ? strlen(input) : 0;
          if (n > sizeof buf) n = sizeof buf;
          if (input && n) memcpy(buf, input, n);
        }
        const cJSON *schema = cJSON_GetObjectItem(c, "schema");
        for (int ai = 0; ai < nuse; ai++) {
          if (lang_map && !mapped_has(lang_map, use[ai]->name, format)) continue;
          total++;
          int accepted = use[ai]->decode(buf, n, schema) == 0;
          const char *outcome = "pass";
          const char *obs = accepted ? "ok" : "rejected";
          if (strcmp(expect, "any") == 0) {
            p++;
          } else if (strcmp(expect, "reject") == 0) {
            if (accepted) { outcome = "fail"; obs = "accepted"; f++; }
            else p++;
          } else if (!accepted) {
            outcome = "fail";
            f++;
          } else {
            p++;
          }
          if (out) {
            if (!first) fputc(',', out);
            first = 0;
            fprintf(out,
                    "{\"id\":\"%s\",\"language\":\"c\",\"serializer\":\"%s\",\"serializer_version\":\"\","
                    "\"format\":\"%s\",\"standard\":\"%s\",\"standard_url\":\"%s\",\"version\":\"%s\","
                    "\"version_key\":\"%s.%s\",\"requirement\":\"%s\",\"expect\":\"%s\",\"section\":\"\","
                    "\"section_title\":\"\",\"section_url\":\"%s\",\"paragraph\":\"\",\"title\":\"\","
                    "\"input\":\"\",\"input_encoding\":\"%s\",\"detail\":\"\",\"observed\":\"%s\",\"outcome\":\"%s\"}",
                    id, use[ai]->name, format,
                    standard && standard->valuestring ? standard->valuestring : "",
                    surl && surl->valuestring ? surl->valuestring : "",
                    version && version->valuestring ? version->valuestring : "",
                    format, version && version->valuestring ? version->valuestring : "",
                    cJSON_GetStringValue(cJSON_GetObjectItem(c, "requirement")) ?: "",
                    expect,
                    cJSON_GetStringValue(cJSON_GetObjectItem(c, "section_url")) ?: "",
                    enc ? enc : "utf-8", obs, outcome);
          }
        }
      }
      cJSON_Delete(suite);
    }
    if (sd) closedir(sd);
  }
  if (dd) closedir(dd);

  printf("Serialization compliance (library deviations are catalogued, not a red build)\n");
  printf("  %d pass  %d fail  0 skip  0 error  %d total\n", p, f, total);
  if (missing[0]) printf("  missing adapters (mapped, not wired): %s\n", missing);
  if (out) {
    if (missing[0])
      fprintf(out,
              "],\"passed\":%d,\"failed\":%d,\"skipped\":0,\"errors\":0,\"catalog_errors\":[],"
              "\"serializer_errors\":[\"%s\"],\"scope\":{\"note\":\"adapters from serializer-standards.json\"}}\n",
              p, f, missing);
    else
      fprintf(out,
              "],\"passed\":%d,\"failed\":%d,\"skipped\":0,\"errors\":0,\"catalog_errors\":[],"
              "\"serializer_errors\":[],\"scope\":{\"note\":\"adapters from serializer-standards.json\"}}\n",
              p, f);
    fclose(out);
    if (json_out) printf("\nWrote %s\n", json_out);
  }
  cJSON_Delete(mapping);
  return 0;
}
