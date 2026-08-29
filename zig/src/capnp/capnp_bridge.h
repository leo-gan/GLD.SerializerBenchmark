#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque encode result: fills *out_len; returns malloc'd buffer (caller frees with capnp_free). */
void capnp_free(void* p);

/* kind: 0=message 1=document 2=telemetry 3=strings 4=event
   For batches, pass JSON-less packed domain via typed builders from Swift using
   the field-level C structs below. */

typedef struct {
  bool f_bool;
  int32_t f_int32;
  int64_t f_int64;
  double f_float64;
  const char* f_string;   /* UTF-8, not owned */
  bool f_bool_2;
  int32_t f_int32_2;
  const char* f_string_2;
} CapnpCMessage;

typedef struct {
  const char* region;
  int32_t version;
} CapnpCDocumentMeta;

typedef struct {
  const char* sku;
  int32_t qty;
  int64_t price_minor;
} CapnpCDocumentItem;

typedef struct {
  const char* id;
  int32_t status;
  CapnpCDocumentMeta meta;
  const CapnpCDocumentItem* items;
  size_t items_count;
} CapnpCDocument;

typedef struct {
  const char* source;
  int64_t ts;
  const char* const* tags;
  size_t tags_count;
  const double* values;
  size_t values_count;
} CapnpCTelemetry;

typedef struct {
  const char* const* items;
  size_t items_count;
} CapnpCStrings;

typedef struct {
  const char* key;
  const char* value;
} CapnpCEventAttr;

typedef struct {
  const char* event_id;
  const char* event_type;
  int64_t occurred_at;
  const char* producer;
  const CapnpCEventAttr* attrs;
  size_t attrs_count;
} CapnpCEvent;

/* Encode single instance → malloc buffer; returns NULL on error. */
void* capnp_encode_message(const CapnpCMessage* m, size_t* out_len);
void* capnp_encode_document(const CapnpCDocument* d, size_t* out_len);
void* capnp_encode_telemetry(const CapnpCTelemetry* t, size_t* out_len);
void* capnp_encode_strings(const CapnpCStrings* s, size_t* out_len);
void* capnp_encode_event(const CapnpCEvent* e, size_t* out_len);

/* Encode batch: array of N instances */
void* capnp_encode_batch_message(const CapnpCMessage* items, size_t n, size_t* out_len);
void* capnp_encode_batch_document(const CapnpCDocument* items, size_t n, size_t* out_len);
void* capnp_encode_batch_telemetry(const CapnpCTelemetry* items, size_t n, size_t* out_len);
void* capnp_encode_batch_strings(const CapnpCStrings* items, size_t n, size_t* out_len);
void* capnp_encode_batch_event(const CapnpCEvent* items, size_t n, size_t* out_len);

/* Decode into caller-owned heap structures; free with capnp_free_decoded_* */
int capnp_decode_message(const void* data, size_t len, CapnpCMessage* out);
int capnp_decode_document(const void* data, size_t len, CapnpCDocument* out);
int capnp_decode_telemetry(const void* data, size_t len, CapnpCTelemetry* out);
int capnp_decode_strings(const void* data, size_t len, CapnpCStrings* out);
int capnp_decode_event(const void* data, size_t len, CapnpCEvent* out);

/* Batch decode: allocates arrays of N; *out_n set. Free with matching free. */
int capnp_decode_batch_message(const void* data, size_t len, CapnpCMessage** out, size_t* out_n);
int capnp_decode_batch_document(const void* data, size_t len, CapnpCDocument** out, size_t* out_n);
int capnp_decode_batch_telemetry(const void* data, size_t len, CapnpCTelemetry** out, size_t* out_n);
int capnp_decode_batch_strings(const void* data, size_t len, CapnpCStrings** out, size_t* out_n);
int capnp_decode_batch_event(const void* data, size_t len, CapnpCEvent** out, size_t* out_n);

void capnp_free_message(CapnpCMessage* m); /* frees internal strings only if owned */
void capnp_free_document(CapnpCDocument* d);
void capnp_free_telemetry(CapnpCTelemetry* t);
void capnp_free_strings(CapnpCStrings* s);
void capnp_free_event(CapnpCEvent* e);
void capnp_free_batch_message(CapnpCMessage* items, size_t n);
void capnp_free_batch_document(CapnpCDocument* items, size_t n);
void capnp_free_batch_telemetry(CapnpCTelemetry* items, size_t n);
void capnp_free_batch_strings(CapnpCStrings* items, size_t n);
void capnp_free_batch_event(CapnpCEvent* items, size_t n);

const char* capnp_bridge_version(void);

#ifdef __cplusplus
}
#endif
