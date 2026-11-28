/* Shared JNI bridge for Java and Kotlin gld-kiln-asm 0.2.0 harnesses.
 * Statically links build/kiln-asm/libkiln_asm_bench.a into build/kiln-asm/libkiln_asm_jni.so.
 * Package/class: benchmark.serializers.KilnAsmJni
 *
 * All functions enforce full RFC 3629 UTF-8 validation (no KILN_OPT_TRUSTED).
 * Critical array pointers are ALWAYS released before any JNI allocation or exception throw.
 */
#include <jni.h>
#include "kiln_asm_bench.h"
#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KILN_DTYPE_F64 1U
#define KILN_DTYPE_F32 2U
#define KILN_DTYPE_I64 14U
#define KILN_LARGE_CAP (1ULL << 28)

typedef struct tls_buf_t {
    uint8_t *ptr;
    size_t cap;
} tls_buf_t;

static __thread tls_buf_t g_out = {NULL, 0};
static __thread tls_buf_t g_arena = {NULL, 0};
static __thread tls_buf_t g_enc = {NULL, 0};

static inline uint8_t *tls_reserve(tls_buf_t *b, size_t need) {
    if (need < 4096) need = 4096;
    if (b->cap >= need) return b->ptr;
    size_t next = b->cap ? b->cap * 2 : need;
    if (next < need) next = need;
    uint8_t *p = (uint8_t *)realloc(b->ptr, next);
    if (!p) return NULL;
    b->ptr = p;
    b->cap = next;
    return p;
}

static inline size_t align16(size_t n) {
    return (n + 15u) & ~(size_t)15u;
}

static void throw_err(JNIEnv *env, const char *op, int err) {
    char msg[160];
    snprintf(msg, sizeof msg, "gld-kiln-asm %s failed (err=%d)", op, err);
    jclass cls = (*env)->FindClass(env, "java/lang/IllegalArgumentException");
    if (cls) (*env)->ThrowNew(env, cls, msg);
}

static jbyteArray make_byte_array(JNIEnv *env, const uint8_t *src, size_t n) {
    jbyteArray out = (*env)->NewByteArray(env, (jsize)n);
    if (!out) return NULL;
    if (n > 0) (*env)->SetByteArrayRegion(env, out, 0, (jsize)n, (const jbyte *)src);
    return out;
}

static inline void set_tensor_2d(kiln_tensor_t *t, uint16_t dtype, uint64_t d0, uint64_t d1,
                                 const void *data, size_t nbytes) {
    kiln_tensor_init(t);
    t->dtype = dtype;
    t->rank = 2;
    t->shape[0] = d0;
    t->shape[1] = d1;
    t->data = (const uint8_t *)data;
    t->data_len = (uint64_t)nbytes;
}

static inline void set_tensor_1d(kiln_tensor_t *t, uint16_t dtype, uint64_t d0,
                                 const void *data, size_t nbytes) {
    kiln_tensor_init(t);
    t->dtype = dtype;
    t->rank = 1;
    t->shape[0] = d0;
    t->data = (const uint8_t *)data;
    t->data_len = (uint64_t)nbytes;
}

static inline void store_str_off(const uint8_t *wire, kiln_str_t s, jint *dst) {
    dst[0] = (s.len > 0 && s.ptr) ? (jint)(s.ptr - wire) : 0;
    dst[1] = (jint)s.len;
}

/* ==================== MESSAGE ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeMessage(
    JNIEnv *env, jclass cls,
    jboolean b1, jint i1, jlong l1, jdouble d1, jbyteArray s1,
    jboolean b2, jint i2, jbyteArray s2) {
    (void)cls;
    jsize n1 = s1 ? (*env)->GetArrayLength(env, s1) : 0;
    jsize n2 = s2 ? (*env)->GetArrayLength(env, s2) : 0;
    uint8_t *out = tls_reserve(&g_out, (size_t)n1 + (size_t)n2 + 64);
    if (!out) { throw_err(env, "oom", -1); return NULL; }

    jbyte *p1 = n1 > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, s1, NULL) : NULL;
    jbyte *p2 = n2 > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, s2, NULL) : NULL;

    bench_message_t m;
    m.f_bool = b1 ? 1 : 0;
    m.f_int32 = (int32_t)i1;
    m.f_int64 = (int64_t)l1;
    m.f_float64 = (double)d1;
    m.f_string.ptr = (const uint8_t *)p1;
    m.f_string.len = (uint64_t)n1;
    m.f_bool_2 = b2 ? 1 : 0;
    m.f_int32_2 = (int32_t)i2;
    m.f_string_2.ptr = (const uint8_t *)p2;
    m.f_string_2.len = (uint64_t)n2;

    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_message(&m, out, g_out.cap, NULL, &res);

    if (p2) (*env)->ReleasePrimitiveArrayCritical(env, s2, p2, JNI_ABORT);
    if (p1) (*env)->ReleasePrimitiveArrayCritical(env, s1, p1, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeMessage", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeMessageBatch(
    JNIEnv *env, jclass cls,
    jint n, jbyteArray bools, jintArray ints, jlongArray longs, jdoubleArray doubles,
    jbyteArray strUtf8, jint strLen, jintArray strLens) {
    (void)cls;
    size_t cnt = (size_t)n;
    uint8_t *enc = tls_reserve(&g_enc, cnt * sizeof(bench_message_t) + 64);
    uint8_t *out = tls_reserve(&g_out, (size_t)strLen + cnt * 48 + 64);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jbyte *pb = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, bools, NULL);
    jint *pi = (jint *)(*env)->GetPrimitiveArrayCritical(env, ints, NULL);
    jlong *pl = (jlong *)(*env)->GetPrimitiveArrayCritical(env, longs, NULL);
    jdouble *pd = (jdouble *)(*env)->GetPrimitiveArrayCritical(env, doubles, NULL);
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens, NULL);

    bench_message_t *arr = (bench_message_t *)enc;
    const uint8_t *sp = (const uint8_t *)ps;
    size_t off = 0;
    for (size_t i = 0; i < cnt; i++) {
        arr[i].f_bool = (uint8_t)(pb[2 * i] ? 1 : 0);
        arr[i].f_int32 = (int32_t)pi[2 * i];
        arr[i].f_int64 = (int64_t)pl[i];
        arr[i].f_float64 = (double)pd[i];
        uint64_t l1 = (uint64_t)(uint32_t)psl[2 * i];
        arr[i].f_string.ptr = l1 ? sp + off : NULL;
        arr[i].f_string.len = l1;
        off += (size_t)l1;
        arr[i].f_bool_2 = (uint8_t)(pb[2 * i + 1] ? 1 : 0);
        arr[i].f_int32_2 = (int32_t)pi[2 * i + 1];
        uint64_t l2 = (uint64_t)(uint32_t)psl[2 * i + 1];
        arr[i].f_string_2.ptr = l2 ? sp + off : NULL;
        arr[i].f_string_2.len = l2;
        off += (size_t)l2;
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_message_batch(arr, cnt, out, g_out.cap, NULL, &res);

    (*env)->ReleasePrimitiveArrayCritical(env, strLens, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, doubles, pd, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, longs, pl, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, ints, pi, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, bools, pb, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeMessageBatch", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeMessage(
    JNIEnv *env, jclass cls,
    jboolean batch, jbyteArray wire,
    jbyteArray outBools, jintArray outInts, jlongArray outLongs, jdoubleArray outDoubles) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capItems = (*env)->GetArrayLength(env, outLongs);
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 4 + 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jbyte *pb = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, outBools, NULL);
    jint *pi = (jint *)(*env)->GetPrimitiveArrayCritical(env, outInts, NULL);
    jlong *pl = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outLongs, NULL);
    jdouble *pd = (jdouble *)(*env)->GetPrimitiveArrayCritical(env, outDoubles, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    jint rc = -1;

    if (!batch) {
        bench_message_t m;
        err = kiln_asm_decode_bench_message(w, (size_t)wlen, &m, &arena, NULL, &res);
        if (err == KILN_OK) {
            if (capItems < 1) {
                rc = -2;
            } else {
                pb[0] = (jbyte)(m.f_bool ? 1 : 0);
                pb[1] = (jbyte)(m.f_bool_2 ? 1 : 0);
                pi[0] = m.f_int32;
                pi[1] = m.f_int32_2;
                store_str_off(w, m.f_string, &pi[2]);
                store_str_off(w, m.f_string_2, &pi[4]);
                pl[0] = m.f_int64;
                pd[0] = m.f_float64;
                rc = 1;
            }
        }
    } else {
        bench_message_t *arr = NULL;
        size_t cnt = 0;
        err = kiln_asm_decode_bench_message_batch(w, (size_t)wlen, &arr, &cnt, &arena, NULL, &res);
        if (err == KILN_OK) {
            if ((jsize)cnt > capItems) {
                rc = -(jint)cnt - 16; /* signal caller to grow scratch */
            } else {
                for (size_t i = 0; i < cnt; i++) {
                    pb[2 * i] = (jbyte)(arr[i].f_bool ? 1 : 0);
                    pb[2 * i + 1] = (jbyte)(arr[i].f_bool_2 ? 1 : 0);
                    pi[6 * i + 0] = arr[i].f_int32;
                    pi[6 * i + 1] = arr[i].f_int32_2;
                    store_str_off(w, arr[i].f_string, &pi[6 * i + 2]);
                    store_str_off(w, arr[i].f_string_2, &pi[6 * i + 4]);
                    pl[i] = arr[i].f_int64;
                    pd[i] = arr[i].f_float64;
                }
                rc = (jint)cnt;
            }
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outDoubles, pd, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outLongs, pl, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outInts, pi, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outBools, pb, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeMessage", (int)err); return -1; }
    return rc;
}

/* ==================== DOCUMENT & NESTED_ROW ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeDocument(
    JNIEnv *env, jclass cls,
    jboolean nested, jboolean batch, jint n,
    jintArray docMeta3n, jintArray itemQtys, jlongArray itemPrices,
    jbyteArray strUtf8, jint strLen, jintArray strLens) {
    (void)cls;
    size_t cnt = (size_t)n;
    jsize totalItems = itemQtys ? (*env)->GetArrayLength(env, itemQtys) : 0;
    size_t headBytes = align16(cnt * sizeof(bench_document_t));
    uint8_t *enc = tls_reserve(&g_enc, headBytes + ((size_t)totalItems + 1) * sizeof(bench_document_document_item_t));
    uint8_t *out = tls_reserve(&g_out, (size_t)strLen + cnt * 48 + (size_t)totalItems * 24 + 64);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jint *pm = (jint *)(*env)->GetPrimitiveArrayCritical(env, docMeta3n, NULL);
    jint *pq = totalItems > 0 ? (jint *)(*env)->GetPrimitiveArrayCritical(env, itemQtys, NULL) : NULL;
    jlong *pp = totalItems > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, itemPrices, NULL) : NULL;
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens, NULL);

    bench_document_t *arr = (bench_document_t *)enc;
    bench_document_document_item_t *pool = (bench_document_document_item_t *)(enc + headBytes);
    const uint8_t *sp = (const uint8_t *)ps;
    size_t soff = 0, si = 0, ki = 0;

    for (size_t i = 0; i < cnt; i++) {
        uint64_t idl = (uint64_t)(uint32_t)psl[si++];
        arr[i].id.ptr = idl ? sp + soff : NULL;
        arr[i].id.len = idl;
        soff += (size_t)idl;
        arr[i].status = (int32_t)pm[3 * i + 0];
        uint64_t rgl = (uint64_t)(uint32_t)psl[si++];
        arr[i].meta.region.ptr = rgl ? sp + soff : NULL;
        arr[i].meta.region.len = rgl;
        soff += (size_t)rgl;
        arr[i].meta.version = (int32_t)pm[3 * i + 1];
        size_t ic = (size_t)(uint32_t)pm[3 * i + 2];
        arr[i].items.count = (uint64_t)ic;
        arr[i].items.items = ic ? pool : NULL;
        for (size_t j = 0; j < ic; j++) {
            uint64_t skul = (uint64_t)(uint32_t)psl[si++];
            pool[j].sku.ptr = skul ? sp + soff : NULL;
            pool[j].sku.len = skul;
            soff += (size_t)skul;
            pool[j].qty = (int32_t)pq[ki];
            pool[j].price_minor = (int64_t)pp[ki];
            ki++;
        }
        pool += ic;
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err;
    if (nested) {
        err = batch
            ? kiln_asm_encode_bench_nested_row_batch((const bench_nested_row_t *)arr, cnt, out, g_out.cap, NULL, &res)
            : kiln_asm_encode_bench_nested_row((const bench_nested_row_t *)&arr[0], out, g_out.cap, NULL, &res);
    } else {
        err = batch
            ? kiln_asm_encode_bench_document_batch(arr, cnt, out, g_out.cap, NULL, &res)
            : kiln_asm_encode_bench_document(&arr[0], out, g_out.cap, NULL, &res);
    }

    (*env)->ReleasePrimitiveArrayCritical(env, strLens, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    if (pp) (*env)->ReleasePrimitiveArrayCritical(env, itemPrices, pp, JNI_ABORT);
    if (pq) (*env)->ReleasePrimitiveArrayCritical(env, itemQtys, pq, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, docMeta3n, pm, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeDocument", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeDocument(
    JNIEnv *env, jclass cls,
    jboolean nested, jboolean batch, jbyteArray wire,
    jintArray outDocInts7n, jintArray outItemInts3m, jlongArray outItemPrices) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capDocs = (*env)->GetArrayLength(env, outDocInts7n) / 7;
    jsize capItems = (*env)->GetArrayLength(env, outItemPrices);
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 4 + 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jint *pd = (jint *)(*env)->GetPrimitiveArrayCritical(env, outDocInts7n, NULL);
    jint *pi = (jint *)(*env)->GetPrimitiveArrayCritical(env, outItemInts3m, NULL);
    jlong *pp = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outItemPrices, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    kiln_result_t res = {0, 0};
    kiln_err_t err;
    bench_document_t single;
    bench_document_t *arr = &single;
    size_t cnt = 1;

    if (nested) {
        if (batch) {
            bench_nested_row_t *na = NULL;
            err = kiln_asm_decode_bench_nested_row_batch(w, (size_t)wlen, &na, &cnt, &arena, NULL, &res);
            arr = (bench_document_t *)na;
        } else {
            err = kiln_asm_decode_bench_nested_row(w, (size_t)wlen, (bench_nested_row_t *)&single, &arena, NULL, &res);
        }
    } else {
        if (batch) {
            err = kiln_asm_decode_bench_document_batch(w, (size_t)wlen, &arr, &cnt, &arena, NULL, &res);
        } else {
            err = kiln_asm_decode_bench_document(w, (size_t)wlen, &single, &arena, NULL, &res);
        }
    }

    jint rc = -1;
    if (err == KILN_OK) {
        size_t totItems = 0;
        for (size_t i = 0; i < cnt; i++) totItems += (size_t)arr[i].items.count;
        if ((jsize)cnt > capDocs || (jsize)totItems > capItems) {
            rc = -(jint)(cnt > totItems ? cnt : totItems) - 16;
        } else {
            size_t ki = 0;
            for (size_t i = 0; i < cnt; i++) {
                pd[7 * i + 0] = arr[i].status;
                pd[7 * i + 1] = arr[i].meta.version;
                pd[7 * i + 2] = (jint)arr[i].items.count;
                store_str_off(w, arr[i].id, &pd[7 * i + 3]);
                store_str_off(w, arr[i].meta.region, &pd[7 * i + 5]);
                for (uint64_t j = 0; j < arr[i].items.count; j++) {
                    pi[3 * ki + 0] = arr[i].items.items[j].qty;
                    store_str_off(w, arr[i].items.items[j].sku, &pi[3 * ki + 1]);
                    pp[ki] = arr[i].items.items[j].price_minor;
                    ki++;
                }
            }
            rc = (jint)cnt;
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outItemPrices, pp, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outItemInts3m, pi, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outDocInts7n, pd, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeDocument", (int)err); return -1; }
    return rc;
}

/* ==================== TELEMETRY ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeTelemetry(
    JNIEnv *env, jclass cls,
    jboolean batch, jint n, jlongArray ts, jintArray counts2n, jdoubleArray vals,
    jbyteArray strUtf8, jint strLen, jintArray strLens) {
    (void)cls;
    size_t cnt = (size_t)n;
    jsize totalVals = vals ? (*env)->GetArrayLength(env, vals) : 0;
    jsize totalStrs = (*env)->GetArrayLength(env, strLens);
    size_t headBytes = align16(cnt * sizeof(bench_telemetry_t));
    uint8_t *enc = tls_reserve(&g_enc, headBytes + ((size_t)totalStrs + 1) * sizeof(kiln_str_t));
    uint8_t *out = tls_reserve(&g_out, (size_t)strLen + cnt * 32 + (size_t)totalStrs * 8 + (size_t)totalVals * 8 + 64);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jlong *pts = (jlong *)(*env)->GetPrimitiveArrayCritical(env, ts, NULL);
    jint *pc = (jint *)(*env)->GetPrimitiveArrayCritical(env, counts2n, NULL);
    jdouble *pv = totalVals > 0 ? (jdouble *)(*env)->GetPrimitiveArrayCritical(env, vals, NULL) : NULL;
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens, NULL);

    bench_telemetry_t *arr = (bench_telemetry_t *)enc;
    kiln_str_t *tpool = (kiln_str_t *)(enc + headBytes);
    const uint8_t *sp = (const uint8_t *)ps;
    size_t soff = 0, si = 0, vi = 0;

    for (size_t i = 0; i < cnt; i++) {
        uint64_t sl = (uint64_t)(uint32_t)psl[si++];
        arr[i].source.ptr = sl ? sp + soff : NULL;
        arr[i].source.len = sl;
        soff += (size_t)sl;
        arr[i].ts = (int64_t)pts[i];
        size_t nt = (size_t)(uint32_t)pc[2 * i + 0];
        size_t nv = (size_t)(uint32_t)pc[2 * i + 1];
        arr[i].tags.count = (uint64_t)nt;
        arr[i].tags.items = nt ? tpool : NULL;
        for (size_t j = 0; j < nt; j++) {
            uint64_t tl = (uint64_t)(uint32_t)psl[si++];
            tpool[j].ptr = tl ? sp + soff : NULL;
            tpool[j].len = tl;
            soff += (size_t)tl;
        }
        tpool += nt;
        arr[i].values.count = (uint64_t)nv;
        arr[i].values.items = nv ? (double *)(pv + vi) : NULL;
        vi += nv;
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_telemetry_batch(arr, cnt, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_telemetry(&arr[0], out, g_out.cap, NULL, &res);

    (*env)->ReleasePrimitiveArrayCritical(env, strLens, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    if (pv) (*env)->ReleasePrimitiveArrayCritical(env, vals, pv, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, counts2n, pc, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, ts, pts, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeTelemetry", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeTelemetry(
    JNIEnv *env, jclass cls,
    jboolean batch, jbyteArray wire,
    jlongArray outTs, jintArray outCounts2n, jintArray outStrOffLen, jdoubleArray outVals) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capDocs = (*env)->GetArrayLength(env, outTs);
    jsize capStrs = (*env)->GetArrayLength(env, outStrOffLen) / 2;
    jsize capVals = (*env)->GetArrayLength(env, outVals);
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 4 + 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jlong *pts = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outTs, NULL);
    jint *pc = (jint *)(*env)->GetPrimitiveArrayCritical(env, outCounts2n, NULL);
    jint *ps = (jint *)(*env)->GetPrimitiveArrayCritical(env, outStrOffLen, NULL);
    jdouble *pv = (jdouble *)(*env)->GetPrimitiveArrayCritical(env, outVals, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    kiln_result_t res = {0, 0};
    bench_telemetry_t single;
    bench_telemetry_t *arr = &single;
    size_t cnt = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_telemetry_batch(w, (size_t)wlen, &arr, &cnt, &arena, NULL, &res)
        : kiln_asm_decode_bench_telemetry(w, (size_t)wlen, &single, &arena, NULL, &res);

    jint rc = -1;
    if (err == KILN_OK) {
        size_t totStrs = cnt, totVals = 0;
        for (size_t i = 0; i < cnt; i++) {
            totStrs += (size_t)arr[i].tags.count;
            totVals += (size_t)arr[i].values.count;
        }
        if ((jsize)cnt > capDocs || (jsize)totStrs > capStrs || (jsize)totVals > capVals) {
            size_t mx = cnt > totStrs ? cnt : totStrs;
            if (totVals > mx) mx = totVals;
            rc = -(jint)mx - 16;
        } else {
            size_t si = 0, vi = 0;
            for (size_t i = 0; i < cnt; i++) {
                pts[i] = arr[i].ts;
                pc[2 * i + 0] = (jint)arr[i].tags.count;
                pc[2 * i + 1] = (jint)arr[i].values.count;
                store_str_off(w, arr[i].source, &ps[2 * si]);
                si++;
                for (uint64_t j = 0; j < arr[i].tags.count; j++) {
                    store_str_off(w, arr[i].tags.items[j], &ps[2 * si]);
                    si++;
                }
                if (arr[i].values.count > 0) {
                    memcpy(pv + vi, arr[i].values.items, (size_t)arr[i].values.count * sizeof(double));
                    vi += (size_t)arr[i].values.count;
                }
            }
            rc = (jint)cnt;
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outVals, pv, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outStrOffLen, ps, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outCounts2n, pc, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outTs, pts, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeTelemetry", (int)err); return -1; }
    return rc;
}

/* ==================== STRINGS ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeStrings(
    JNIEnv *env, jclass cls,
    jboolean batch, jint n, jintArray counts,
    jbyteArray strUtf8, jint strLen, jintArray strLens) {
    (void)cls;
    size_t cnt = (size_t)n;
    jsize totalStrs = (*env)->GetArrayLength(env, strLens);
    size_t headBytes = align16(cnt * sizeof(bench_strings_t));
    uint8_t *enc = tls_reserve(&g_enc, headBytes + ((size_t)totalStrs + 1) * sizeof(kiln_str_t));
    uint8_t *out = tls_reserve(&g_out, (size_t)strLen + cnt * 8 + (size_t)totalStrs * 8 + 64);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jint *pc = (jint *)(*env)->GetPrimitiveArrayCritical(env, counts, NULL);
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens, NULL);

    bench_strings_t *arr = (bench_strings_t *)enc;
    kiln_str_t *pool = (kiln_str_t *)(enc + headBytes);
    const uint8_t *sp = (const uint8_t *)ps;
    size_t soff = 0, si = 0;

    for (size_t i = 0; i < cnt; i++) {
        size_t m = (size_t)(uint32_t)pc[i];
        arr[i].items.count = (uint64_t)m;
        arr[i].items.items = m ? pool : NULL;
        for (size_t j = 0; j < m; j++) {
            uint64_t l = (uint64_t)(uint32_t)psl[si++];
            pool[j].ptr = l ? sp + soff : NULL;
            pool[j].len = l;
            soff += (size_t)l;
        }
        pool += m;
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_strings_batch(arr, cnt, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_strings(&arr[0], out, g_out.cap, NULL, &res);

    (*env)->ReleasePrimitiveArrayCritical(env, strLens, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, counts, pc, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeStrings", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeStrings(
    JNIEnv *env, jclass cls,
    jboolean batch, jbyteArray wire, jintArray outCounts, jintArray outStrOffLen) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capDocs = (*env)->GetArrayLength(env, outCounts);
    jsize capStrs = (*env)->GetArrayLength(env, outStrOffLen) / 2;
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 4 + 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jint *pc = (jint *)(*env)->GetPrimitiveArrayCritical(env, outCounts, NULL);
    jint *ps = (jint *)(*env)->GetPrimitiveArrayCritical(env, outStrOffLen, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    kiln_result_t res = {0, 0};
    bench_strings_t single;
    bench_strings_t *arr = &single;
    size_t cnt = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_strings_batch(w, (size_t)wlen, &arr, &cnt, &arena, NULL, &res)
        : kiln_asm_decode_bench_strings(w, (size_t)wlen, &single, &arena, NULL, &res);

    jint rc = -1;
    if (err == KILN_OK) {
        size_t tot = 0;
        for (size_t i = 0; i < cnt; i++) tot += (size_t)arr[i].items.count;
        if ((jsize)cnt > capDocs || (jsize)tot > capStrs) {
            rc = -(jint)(cnt > tot ? cnt : tot) - 16;
        } else {
            size_t si = 0;
            for (size_t i = 0; i < cnt; i++) {
                pc[i] = (jint)arr[i].items.count;
                for (uint64_t j = 0; j < arr[i].items.count; j++) {
                    store_str_off(w, arr[i].items.items[j], &ps[2 * si]);
                    si++;
                }
            }
            rc = (jint)cnt;
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outStrOffLen, ps, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outCounts, pc, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeStrings", (int)err); return -1; }
    return rc;
}

/* ==================== EVENT ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeEvent(
    JNIEnv *env, jclass cls,
    jboolean batch, jint n, jlongArray occurredAt, jintArray attrCounts,
    jbyteArray strUtf8, jint strLen, jintArray strLens) {
    (void)cls;
    size_t cnt = (size_t)n;
    jsize totalStrs = (*env)->GetArrayLength(env, strLens);
    size_t headBytes = align16(cnt * sizeof(bench_event_t));
    size_t maxAttrs = (size_t)totalStrs / 2 + 1;
    uint8_t *enc = tls_reserve(&g_enc, headBytes + maxAttrs * sizeof(bench_event_event_attr_t));
    uint8_t *out = tls_reserve(&g_out, (size_t)strLen + cnt * 32 + maxAttrs * 16 + 64);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jlong *pt = (jlong *)(*env)->GetPrimitiveArrayCritical(env, occurredAt, NULL);
    jint *pc = (jint *)(*env)->GetPrimitiveArrayCritical(env, attrCounts, NULL);
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens, NULL);

    bench_event_t *arr = (bench_event_t *)enc;
    bench_event_event_attr_t *pool = (bench_event_event_attr_t *)(enc + headBytes);
    const uint8_t *sp = (const uint8_t *)ps;
    size_t soff = 0, si = 0;

    for (size_t i = 0; i < cnt; i++) {
        uint64_t l0 = (uint64_t)(uint32_t)psl[si++];
        arr[i].event_id.ptr = l0 ? sp + soff : NULL; arr[i].event_id.len = l0; soff += (size_t)l0;
        uint64_t l1 = (uint64_t)(uint32_t)psl[si++];
        arr[i].event_type.ptr = l1 ? sp + soff : NULL; arr[i].event_type.len = l1; soff += (size_t)l1;
        arr[i].occurred_at = (int64_t)pt[i];
        uint64_t l2 = (uint64_t)(uint32_t)psl[si++];
        arr[i].producer.ptr = l2 ? sp + soff : NULL; arr[i].producer.len = l2; soff += (size_t)l2;
        size_t na = (size_t)(uint32_t)pc[i];
        arr[i].attrs.count = (uint64_t)na;
        arr[i].attrs.items = na ? pool : NULL;
        for (size_t j = 0; j < na; j++) {
            uint64_t lk = (uint64_t)(uint32_t)psl[si++];
            pool[j].key.ptr = lk ? sp + soff : NULL; pool[j].key.len = lk; soff += (size_t)lk;
            uint64_t lv = (uint64_t)(uint32_t)psl[si++];
            pool[j].value.ptr = lv ? sp + soff : NULL; pool[j].value.len = lv; soff += (size_t)lv;
        }
        pool += na;
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_event_batch(arr, cnt, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_event(&arr[0], out, g_out.cap, NULL, &res);

    (*env)->ReleasePrimitiveArrayCritical(env, strLens, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, attrCounts, pc, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, occurredAt, pt, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeEvent", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeEvent(
    JNIEnv *env, jclass cls,
    jboolean batch, jbyteArray wire,
    jlongArray outOccurredAt, jintArray outAttrCounts, jintArray outStrOffLen) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capDocs = (*env)->GetArrayLength(env, outOccurredAt);
    jsize capStrs = (*env)->GetArrayLength(env, outStrOffLen) / 2;
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 4 + 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jlong *pt = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outOccurredAt, NULL);
    jint *pc = (jint *)(*env)->GetPrimitiveArrayCritical(env, outAttrCounts, NULL);
    jint *ps = (jint *)(*env)->GetPrimitiveArrayCritical(env, outStrOffLen, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    kiln_result_t res = {0, 0};
    bench_event_t single;
    bench_event_t *arr = &single;
    size_t cnt = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_event_batch(w, (size_t)wlen, &arr, &cnt, &arena, NULL, &res)
        : kiln_asm_decode_bench_event(w, (size_t)wlen, &single, &arena, NULL, &res);

    jint rc = -1;
    if (err == KILN_OK) {
        size_t totStrs = 3 * cnt;
        for (size_t i = 0; i < cnt; i++) totStrs += 2 * (size_t)arr[i].attrs.count;
        if ((jsize)cnt > capDocs || (jsize)totStrs > capStrs) {
            rc = -(jint)(cnt > totStrs ? cnt : totStrs) - 16;
        } else {
            size_t si = 0;
            for (size_t i = 0; i < cnt; i++) {
                pt[i] = arr[i].occurred_at;
                pc[i] = (jint)arr[i].attrs.count;
                store_str_off(w, arr[i].event_id, &ps[2 * si++]);
                store_str_off(w, arr[i].event_type, &ps[2 * si++]);
                store_str_off(w, arr[i].producer, &ps[2 * si++]);
                for (uint64_t j = 0; j < arr[i].attrs.count; j++) {
                    store_str_off(w, arr[i].attrs.items[j].key, &ps[2 * si++]);
                    store_str_off(w, arr[i].attrs.items[j].value, &ps[2 * si++]);
                }
            }
            rc = (jint)cnt;
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outStrOffLen, ps, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outAttrCounts, pc, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outOccurredAt, pt, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeEvent", (int)err); return -1; }
    return rc;
}

/* ==================== SIGNAL ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeSignal(
    JNIEnv *env, jclass cls,
    jboolean batch, jint n,
    jlongArray longs3n, jintArray ints3n,
    jlongArray legIds, jintArray legInts2m,
    jbyteArray strUtf8, jint strLen, jintArray strLens2n) {
    (void)cls;
    size_t cnt = (size_t)n;
    jsize totalLegs = legIds ? (*env)->GetArrayLength(env, legIds) : 0;
    size_t headBytes = align16(cnt * sizeof(bench_signal_t));
    uint8_t *enc = tls_reserve(&g_enc, headBytes + ((size_t)totalLegs + 1) * sizeof(bench_signal_signal_leg_t));
    uint8_t *out = tls_reserve(&g_out, (size_t)strLen + cnt * 64 + (size_t)totalLegs * 16 + 64);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jlong *pl = (jlong *)(*env)->GetPrimitiveArrayCritical(env, longs3n, NULL);
    jint *pi = (jint *)(*env)->GetPrimitiveArrayCritical(env, ints3n, NULL);
    jlong *plid = totalLegs > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, legIds, NULL) : NULL;
    jint *pli = totalLegs > 0 ? (jint *)(*env)->GetPrimitiveArrayCritical(env, legInts2m, NULL) : NULL;
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens2n, NULL);

    bench_signal_t *arr = (bench_signal_t *)enc;
    bench_signal_signal_leg_t *pool = (bench_signal_signal_leg_t *)(enc + headBytes);
    const uint8_t *sp = (const uint8_t *)ps;
    size_t soff = 0, ki = 0;

    for (size_t i = 0; i < cnt; i++) {
        arr[i].seq = (int64_t)pl[3 * i + 0];
        arr[i].ts = (int64_t)pl[3 * i + 1];
        arr[i].price_mantissa = (int64_t)pl[3 * i + 2];
        arr[i].qty = (int32_t)pi[3 * i + 0];
        arr[i].flags = (int32_t)pi[3 * i + 1];
        uint64_t l0 = (uint64_t)(uint32_t)psl[2 * i + 0];
        arr[i].symbol.ptr = l0 ? sp + soff : NULL; arr[i].symbol.len = l0; soff += (size_t)l0;
        uint64_t l1 = (uint64_t)(uint32_t)psl[2 * i + 1];
        arr[i].venue.ptr = l1 ? sp + soff : NULL; arr[i].venue.len = l1; soff += (size_t)l1;
        size_t nl = (size_t)(uint32_t)pi[3 * i + 2];
        arr[i].legs.count = (uint64_t)nl;
        arr[i].legs.items = nl ? pool : NULL;
        for (size_t j = 0; j < nl; j++) {
            pool[j].leg_id = (int64_t)plid[ki];
            pool[j].leg_qty = (int32_t)pli[2 * ki + 0];
            pool[j].leg_pad = (int32_t)pli[2 * ki + 1];
            ki++;
        }
        pool += nl;
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err = batch
        ? kiln_asm_encode_bench_signal_batch(arr, cnt, out, g_out.cap, NULL, &res)
        : kiln_asm_encode_bench_signal(&arr[0], out, g_out.cap, NULL, &res);

    (*env)->ReleasePrimitiveArrayCritical(env, strLens2n, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    if (pli) (*env)->ReleasePrimitiveArrayCritical(env, legInts2m, pli, JNI_ABORT);
    if (plid) (*env)->ReleasePrimitiveArrayCritical(env, legIds, plid, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, ints3n, pi, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, longs3n, pl, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeSignal", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeSignal(
    JNIEnv *env, jclass cls,
    jboolean batch, jbyteArray wire,
    jlongArray outLongs3n, jintArray outInts7n,
    jlongArray outLegIds, jintArray outLegInts2m) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capDocs = (*env)->GetArrayLength(env, outLongs3n) / 3;
    jsize capLegs = (*env)->GetArrayLength(env, outLegIds);
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 4 + 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jlong *pl = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outLongs3n, NULL);
    jint *pi = (jint *)(*env)->GetPrimitiveArrayCritical(env, outInts7n, NULL);
    jlong *plid = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outLegIds, NULL);
    jint *pli = (jint *)(*env)->GetPrimitiveArrayCritical(env, outLegInts2m, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    kiln_result_t res = {0, 0};
    bench_signal_t single;
    bench_signal_t *arr = &single;
    size_t cnt = 1;
    kiln_err_t err = batch
        ? kiln_asm_decode_bench_signal_batch(w, (size_t)wlen, &arr, &cnt, &arena, NULL, &res)
        : kiln_asm_decode_bench_signal(w, (size_t)wlen, &single, &arena, NULL, &res);

    jint rc = -1;
    if (err == KILN_OK) {
        size_t totLegs = 0;
        for (size_t i = 0; i < cnt; i++) totLegs += (size_t)arr[i].legs.count;
        if ((jsize)cnt > capDocs || (jsize)totLegs > capLegs) {
            rc = -(jint)(cnt > totLegs ? cnt : totLegs) - 16;
        } else {
            size_t ki = 0;
            for (size_t i = 0; i < cnt; i++) {
                pl[3 * i + 0] = arr[i].seq;
                pl[3 * i + 1] = arr[i].ts;
                pl[3 * i + 2] = arr[i].price_mantissa;
                pi[7 * i + 0] = arr[i].qty;
                pi[7 * i + 1] = arr[i].flags;
                pi[7 * i + 2] = (jint)arr[i].legs.count;
                store_str_off(w, arr[i].symbol, &pi[7 * i + 3]);
                store_str_off(w, arr[i].venue, &pi[7 * i + 5]);
                for (uint64_t j = 0; j < arr[i].legs.count; j++) {
                    plid[ki] = arr[i].legs.items[j].leg_id;
                    pli[2 * ki + 0] = arr[i].legs.items[j].leg_qty;
                    pli[2 * ki + 1] = arr[i].legs.items[j].leg_pad;
                    ki++;
                }
            }
            rc = (jint)cnt;
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outLegInts2m, pli, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outLegIds, plid, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outInts7n, pi, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outLongs3n, pl, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeSignal", (int)err); return -1; }
    return rc;
}

/* ==================== TABLE_COLUMNS & TABLE_PROJECT ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeTableColumns(
    JNIEnv *env, jclass cls,
    jint n, jdoubleArray floats16n, jlongArray ints4n,
    jbyteArray strUtf8, jint strLen, jintArray strLens2n) {
    (void)cls;
    size_t cnt = (size_t)n;
    uint8_t *enc = tls_reserve(&g_enc, 2 * cnt * sizeof(kiln_str_t) + 64);
    uint8_t *out = tls_reserve(&g_out, cnt * (16 * 8 + 4 * 8 + 16) + (size_t)strLen + 256);
    if (!enc || !out) { throw_err(env, "oom", -1); return NULL; }

    jdouble *pf = (jdouble *)(*env)->GetPrimitiveArrayCritical(env, floats16n, NULL);
    jlong *pi = (jlong *)(*env)->GetPrimitiveArrayCritical(env, ints4n, NULL);
    jbyte *ps = strLen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, strUtf8, NULL) : NULL;
    jint *psl = (jint *)(*env)->GetPrimitiveArrayCritical(env, strLens2n, NULL);

    kiln_str_t *s0 = (kiln_str_t *)enc;
    kiln_str_t *s1 = s0 + cnt;
    const uint8_t *sp = (const uint8_t *)ps;
    size_t soff = 0;
    for (size_t r = 0; r < cnt; r++) {
        uint64_t l0 = (uint64_t)(uint32_t)psl[r];
        s0[r].ptr = l0 ? sp + soff : NULL; s0[r].len = l0; soff += (size_t)l0;
    }
    for (size_t r = 0; r < cnt; r++) {
        uint64_t l1 = (uint64_t)(uint32_t)psl[cnt + r];
        s1[r].ptr = l1 ? sp + soff : NULL; s1[r].len = l1; soff += (size_t)l1;
    }

    bench_table_columns_t tc;
    bench_table_columns_list_f64_t *fcols = &tc.f_float_0;
    bench_table_columns_list_i64_t *icols = &tc.f_int_0;
    for (int c = 0; c < 16; c++) {
        fcols[c].items = (double *)(pf + (size_t)c * cnt);
        fcols[c].count = (uint64_t)cnt;
    }
    for (int c = 0; c < 4; c++) {
        icols[c].items = (int64_t *)(pi + (size_t)c * cnt);
        icols[c].count = (uint64_t)cnt;
    }
    tc.f_str_0.items = s0; tc.f_str_0.count = (uint64_t)cnt;
    tc.f_str_1.items = s1; tc.f_str_1.count = (uint64_t)cnt;

    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_table_columns(&tc, out, g_out.cap, NULL, &res);

    (*env)->ReleasePrimitiveArrayCritical(env, strLens2n, psl, JNI_ABORT);
    if (ps) (*env)->ReleasePrimitiveArrayCritical(env, strUtf8, ps, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, ints4n, pi, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, floats16n, pf, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeTableColumns", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeTableColumns(
    JNIEnv *env, jclass cls,
    jbyteArray wire, jdoubleArray outFloats16n, jlongArray outInts4n, jintArray outStrOffLen4n) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    jsize capRows = (*env)->GetArrayLength(env, outInts4n) / 4;
    uint8_t *abuf = tls_reserve(&g_arena, (size_t)wlen * 2 + 262144);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    jdouble *pf = (jdouble *)(*env)->GetPrimitiveArrayCritical(env, outFloats16n, NULL);
    jlong *pi = (jlong *)(*env)->GetPrimitiveArrayCritical(env, outInts4n, NULL);
    jint *ps = (jint *)(*env)->GetPrimitiveArrayCritical(env, outStrOffLen4n, NULL);

    const uint8_t *w = (const uint8_t *)pw;
    bench_table_columns_t tc;
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_bench_table_columns(w, (size_t)wlen, &tc, &arena, NULL, &res);

    jint rc = -1;
    if (err == KILN_OK) {
        size_t n = (size_t)tc.f_float_0.count;
        if ((jsize)n > capRows) {
            rc = -(jint)n - 16;
        } else {
            const bench_table_columns_list_f64_t *fcols = &tc.f_float_0;
            const bench_table_columns_list_i64_t *icols = &tc.f_int_0;
            for (int c = 0; c < 16; c++) {
                if (n > 0) memcpy(pf + (size_t)c * n, fcols[c].items, n * sizeof(double));
            }
            for (int c = 0; c < 4; c++) {
                if (n > 0) memcpy(pi + (size_t)c * n, icols[c].items, n * sizeof(int64_t));
            }
            for (size_t r = 0; r < n; r++) {
                store_str_off(w, tc.f_str_0.items[r], &ps[2 * r]);
                store_str_off(w, tc.f_str_1.items[r], &ps[2 * (n + r)]);
            }
            rc = (jint)n;
        }
    }

    (*env)->ReleasePrimitiveArrayCritical(env, outStrOffLen4n, ps, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outInts4n, pi, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, outFloats16n, pf, 0);
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeTableColumns", (int)err); return -1; }
    return rc;
}

JNIEXPORT jdoubleArray JNICALL Java_benchmark_serializers_KilnAsmJni_decodeTableProject(
    JNIEnv *env, jclass cls, jbyteArray wire) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    uint8_t *abuf = tls_reserve(&g_arena, 65536);
    if (!abuf) { throw_err(env, "oom", -1); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    kiln_read_opts_t opts = {0, 0, 0, KILN_OPT_EMBEDDED};
    bench_table_project_t proj;
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_bench_table_project(
        (const uint8_t *)pw, (size_t)wlen, &proj, &arena, &opts, &res);

    size_t n = (err == KILN_OK) ? (size_t)proj.f_float_0.count : 0;
    size_t nbytes = n * sizeof(double);
    uint8_t *tmp = (err == KILN_OK && nbytes > 0) ? tls_reserve(&g_out, nbytes) : NULL;
    if (err == KILN_OK && nbytes > 0 && tmp) {
        memcpy(tmp, proj.f_float_0.items, nbytes);
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeTableProject", (int)err); return NULL; }
    jdoubleArray out = (*env)->NewDoubleArray(env, (jsize)n);
    if (!out) return NULL;
    if (n > 0) (*env)->SetDoubleArrayRegion(env, out, 0, (jsize)n, (const jdouble *)tmp);
    return out;
}

/* ==================== TENSOR / TENSOR_VIEW / PROMPT / SHARD / REQUEST ==================== */

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeTensor(
    JNIEnv *env, jclass cls, jint rows, jint cols, jfloatArray values) {
    (void)cls;
    size_t nbytes = (size_t)rows * (size_t)cols * sizeof(float);
    uint8_t *out = tls_reserve(&g_out, nbytes + 512);
    if (!out) { throw_err(env, "oom", -1); return NULL; }

    jfloat *pv = nbytes > 0 ? (jfloat *)(*env)->GetPrimitiveArrayCritical(env, values, NULL) : NULL;
    kiln_tensor_t t;
    set_tensor_2d(&t, KILN_DTYPE_F32, (uint64_t)rows, (uint64_t)cols, pv, nbytes);
    kiln_tensor_dir_t dir = {&t, 1, 0, 2, 2};
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);

    if (pv) (*env)->ReleasePrimitiveArrayCritical(env, values, pv, JNI_ABORT);
    if (err != KILN_OK) { throw_err(env, "encodeTensor", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jfloatArray JNICALL Java_benchmark_serializers_KilnAsmJni_decodeTensor(
    JNIEnv *env, jclass cls, jbyteArray wire, jintArray outShape2) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    uint8_t *abuf = tls_reserve(&g_arena, 65536);
    if (!abuf) { throw_err(env, "oom", -1); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    kiln_tensor_dir_t dir;
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)pw, (size_t)wlen, &dir, &arena, &opts, &res);

    jint shape[2] = {0, 0};
    size_t dataOff = 0, dataLen = 0;
    if (err == KILN_OK) {
        if (dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2) {
            err = KILN_ERR_TYPE;
        } else {
            shape[0] = (jint)dir.items[0].shape[0];
            shape[1] = (jint)dir.items[0].shape[1];
            dataLen = (size_t)dir.items[0].data_len;
            dataOff = dataLen > 0 ? (size_t)(dir.items[0].data - (const uint8_t *)pw) : 0;
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeTensor", (int)err); return NULL; }
    (*env)->SetIntArrayRegion(env, outShape2, 0, 2, shape);
    size_t n = dataLen / sizeof(float);
    jfloatArray out = (*env)->NewFloatArray(env, (jsize)n);
    if (!out) return NULL;
    if (dataLen > 0) {
        jbyte *pw2 = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
        jfloat *po = (jfloat *)(*env)->GetPrimitiveArrayCritical(env, out, NULL);
        memcpy(po, (const uint8_t *)pw2 + dataOff, dataLen);
        (*env)->ReleasePrimitiveArrayCritical(env, out, po, 0);
        (*env)->ReleasePrimitiveArrayCritical(env, wire, pw2, JNI_ABORT);
    }
    return out;
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeTensorView(
    JNIEnv *env, jclass cls, jbyteArray wire, jintArray outMeta4) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    uint8_t *abuf = tls_reserve(&g_arena, 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    kiln_tensor_dir_t dir;
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)pw, (size_t)wlen, &dir, &arena, &opts, &res);

    jint meta[4] = {0, 0, 0, 0};
    if (err == KILN_OK) {
        if (dir.count != 1 || dir.items[0].dtype != KILN_DTYPE_F32 || dir.items[0].rank != 2) {
            err = KILN_ERR_TYPE;
        } else {
            meta[0] = (jint)dir.items[0].shape[0];
            meta[1] = (jint)dir.items[0].shape[1];
            meta[2] = dir.items[0].data_len > 0 ? (jint)(dir.items[0].data - (const uint8_t *)pw) : 0;
            meta[3] = (jint)dir.items[0].data_len;
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeTensorView", (int)err); return -1; }
    (*env)->SetIntArrayRegion(env, outMeta4, 0, 4, meta);
    return 0;
}

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodePrompt(
    JNIEnv *env, jclass cls, jint batch, jint seq,
    jlongArray ids, jlongArray mask, jlongArray pos) {
    (void)cls;
    size_t nbytes = (size_t)batch * (size_t)seq * sizeof(int64_t);
    uint8_t *out = tls_reserve(&g_out, nbytes * 3 + 1024);
    if (!out) { throw_err(env, "oom", -1); return NULL; }

    jlong *p0 = nbytes > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, ids, NULL) : NULL;
    jlong *p1 = nbytes > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, mask, NULL) : NULL;
    jlong *p2 = nbytes > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, pos, NULL) : NULL;

    kiln_tensor_t ts[3];
    set_tensor_2d(&ts[0], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p0, nbytes);
    set_tensor_2d(&ts[1], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p1, nbytes);
    set_tensor_2d(&ts[2], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p2, nbytes);
    kiln_tensor_dir_t dir = {ts, 3, 0, 2, 2};
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);

    if (p2) (*env)->ReleasePrimitiveArrayCritical(env, pos, p2, JNI_ABORT);
    if (p1) (*env)->ReleasePrimitiveArrayCritical(env, mask, p1, JNI_ABORT);
    if (p0) (*env)->ReleasePrimitiveArrayCritical(env, ids, p0, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodePrompt", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodePrompt(
    JNIEnv *env, jclass cls, jbyteArray wire, jintArray outMeta2, jobjectArray outArrays3) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    uint8_t *abuf = tls_reserve(&g_arena, 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    kiln_tensor_dir_t dir;
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)pw, (size_t)wlen, &dir, &arena, &opts, &res);

    jint meta[2] = {0, 0};
    size_t offs[3] = {0, 0, 0}, nbytes = 0;
    if (err == KILN_OK) {
        if (dir.count != 3 || dir.items[0].dtype != KILN_DTYPE_I64 || dir.items[0].rank != 2) {
            err = KILN_ERR_TYPE;
        } else {
            meta[0] = (jint)dir.items[0].shape[0];
            meta[1] = (jint)dir.items[0].shape[1];
            nbytes = (size_t)dir.items[0].data_len;
            for (int i = 0; i < 3; i++) {
                offs[i] = nbytes > 0 ? (size_t)(dir.items[i].data - (const uint8_t *)pw) : 0;
            }
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodePrompt", (int)err); return -1; }
    (*env)->SetIntArrayRegion(env, outMeta2, 0, 2, meta);
    size_t n = nbytes / sizeof(int64_t);
    jlongArray arrs[3];
    for (int i = 0; i < 3; i++) {
        arrs[i] = (*env)->NewLongArray(env, (jsize)n);
        if (!arrs[i]) return -1;
    }
    if (nbytes > 0) {
        jbyte *pw2 = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
        for (int i = 0; i < 3; i++) {
            jlong *po = (jlong *)(*env)->GetPrimitiveArrayCritical(env, arrs[i], NULL);
            memcpy(po, (const uint8_t *)pw2 + offs[i], nbytes);
            (*env)->ReleasePrimitiveArrayCritical(env, arrs[i], po, 0);
        }
        (*env)->ReleasePrimitiveArrayCritical(env, wire, pw2, JNI_ABORT);
    }
    for (int i = 0; i < 3; i++) (*env)->SetObjectArrayElement(env, outArrays3, i, arrs[i]);
    return 0;
}

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeShard(
    JNIEnv *env, jclass cls, jint vocab, jint hidden, jint ffn,
    jfloatArray tok, jfloatArray attn, jfloatArray ffnW, jfloatArray norm) {
    (void)cls;
    size_t b0 = (size_t)vocab * (size_t)hidden * sizeof(float);
    size_t b1 = (size_t)hidden * (size_t)hidden * sizeof(float);
    size_t b2 = (size_t)ffn * (size_t)hidden * sizeof(float);
    size_t b3 = (size_t)hidden * sizeof(float);
    uint8_t *out = tls_reserve(&g_out, b0 + b1 + b2 + b3 + 2048);
    if (!out) { throw_err(env, "oom", -1); return NULL; }

    jfloat *p0 = b0 ? (jfloat *)(*env)->GetPrimitiveArrayCritical(env, tok, NULL) : NULL;
    jfloat *p1 = b1 ? (jfloat *)(*env)->GetPrimitiveArrayCritical(env, attn, NULL) : NULL;
    jfloat *p2 = b2 ? (jfloat *)(*env)->GetPrimitiveArrayCritical(env, ffnW, NULL) : NULL;
    jfloat *p3 = b3 ? (jfloat *)(*env)->GetPrimitiveArrayCritical(env, norm, NULL) : NULL;

    kiln_tensor_t ts[4];
    set_tensor_2d(&ts[0], KILN_DTYPE_F32, (uint64_t)vocab, (uint64_t)hidden, p0, b0);
    set_tensor_2d(&ts[1], KILN_DTYPE_F32, (uint64_t)hidden, (uint64_t)hidden, p1, b1);
    set_tensor_2d(&ts[2], KILN_DTYPE_F32, (uint64_t)ffn, (uint64_t)hidden, p2, b2);
    set_tensor_1d(&ts[3], KILN_DTYPE_F32, (uint64_t)hidden, p3, b3);
    kiln_tensor_dir_t dir = {ts, 4, 0, 2, 2};
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_tensors(&dir, out, g_out.cap, &opts, &res);

    if (p3) (*env)->ReleasePrimitiveArrayCritical(env, norm, p3, JNI_ABORT);
    if (p2) (*env)->ReleasePrimitiveArrayCritical(env, ffnW, p2, JNI_ABORT);
    if (p1) (*env)->ReleasePrimitiveArrayCritical(env, attn, p1, JNI_ABORT);
    if (p0) (*env)->ReleasePrimitiveArrayCritical(env, tok, p0, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeShard", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeShard(
    JNIEnv *env, jclass cls, jbyteArray wire, jintArray outDims3, jobjectArray outArrays4) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    uint8_t *abuf = tls_reserve(&g_arena, 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    kiln_tensor_dir_t dir;
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_tensors((const uint8_t *)pw, (size_t)wlen, &dir, &arena, &opts, &res);

    jint dims[3] = {0, 0, 0};
    size_t offs[4] = {0, 0, 0, 0}, lens[4] = {0, 0, 0, 0};
    if (err == KILN_OK) {
        if (dir.count != 4) {
            err = KILN_ERR_TYPE;
        } else {
            dims[0] = (jint)dir.items[0].shape[0];
            dims[1] = (jint)dir.items[0].shape[1];
            dims[2] = (jint)dir.items[2].shape[0];
            for (int i = 0; i < 4; i++) {
                lens[i] = (size_t)dir.items[i].data_len;
                offs[i] = lens[i] > 0 ? (size_t)(dir.items[i].data - (const uint8_t *)pw) : 0;
            }
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeShard", (int)err); return -1; }
    (*env)->SetIntArrayRegion(env, outDims3, 0, 3, dims);
    jfloatArray arrs[4];
    for (int i = 0; i < 4; i++) {
        arrs[i] = (*env)->NewFloatArray(env, (jsize)(lens[i] / sizeof(float)));
        if (!arrs[i]) return -1;
    }
    jbyte *pw2 = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    for (int i = 0; i < 4; i++) {
        if (lens[i] > 0) {
            jfloat *po = (jfloat *)(*env)->GetPrimitiveArrayCritical(env, arrs[i], NULL);
            memcpy(po, (const uint8_t *)pw2 + offs[i], lens[i]);
            (*env)->ReleasePrimitiveArrayCritical(env, arrs[i], po, 0);
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw2, JNI_ABORT);
    for (int i = 0; i < 4; i++) (*env)->SetObjectArrayElement(env, outArrays4, i, arrs[i]);
    return 0;
}

JNIEXPORT jbyteArray JNICALL Java_benchmark_serializers_KilnAsmJni_encodeRequest(
    JNIEnv *env, jclass cls,
    jlong reqId, jbyteArray modelUtf8, jfloat temp,
    jint batch, jint seq, jlongArray ids, jlongArray mask, jlongArray pos) {
    (void)cls;
    jsize mlen = modelUtf8 ? (*env)->GetArrayLength(env, modelUtf8) : 0;
    size_t nbytes = (size_t)batch * (size_t)seq * sizeof(int64_t);
    uint8_t *out = tls_reserve(&g_out, (size_t)mlen + nbytes * 3 + 1024);
    if (!out) { throw_err(env, "oom", -1); return NULL; }

    jbyte *pm = mlen > 0 ? (jbyte *)(*env)->GetPrimitiveArrayCritical(env, modelUtf8, NULL) : NULL;
    jlong *p0 = nbytes > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, ids, NULL) : NULL;
    jlong *p1 = nbytes > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, mask, NULL) : NULL;
    jlong *p2 = nbytes > 0 ? (jlong *)(*env)->GetPrimitiveArrayCritical(env, pos, NULL) : NULL;

    kiln_tensor_t ts[3];
    set_tensor_2d(&ts[0], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p0, nbytes);
    set_tensor_2d(&ts[1], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p1, nbytes);
    set_tensor_2d(&ts[2], KILN_DTYPE_I64, (uint64_t)batch, (uint64_t)seq, p2, nbytes);
    bench_request_t br;
    br.request_id = (int64_t)reqId;
    br.model.ptr = (const uint8_t *)pm;
    br.model.len = (uint64_t)mlen;
    br.temperature = (float)temp;
    br.inputs.items = ts;
    br.inputs.count = 3;
    br.inputs.block_length = 0;
    br.inputs.flags = 2;
    br.inputs.version = 2;

    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_encode_bench_request(&br, out, g_out.cap, &opts, &res);

    if (p2) (*env)->ReleasePrimitiveArrayCritical(env, pos, p2, JNI_ABORT);
    if (p1) (*env)->ReleasePrimitiveArrayCritical(env, mask, p1, JNI_ABORT);
    if (p0) (*env)->ReleasePrimitiveArrayCritical(env, ids, p0, JNI_ABORT);
    if (pm) (*env)->ReleasePrimitiveArrayCritical(env, modelUtf8, pm, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "encodeRequest", (int)err); return NULL; }
    return make_byte_array(env, out, (size_t)res.bytes);
}

JNIEXPORT jint JNICALL Java_benchmark_serializers_KilnAsmJni_decodeRequest(
    JNIEnv *env, jclass cls, jbyteArray wire,
    jlongArray outReqId1, jfloatArray outTemp1, jintArray outMeta4, jobjectArray outArrays3) {
    (void)cls;
    jsize wlen = (*env)->GetArrayLength(env, wire);
    uint8_t *abuf = tls_reserve(&g_arena, 65536);
    if (!abuf) { throw_err(env, "oom", -1); return -1; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    jbyte *pw = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
    bench_request_t br;
    kiln_read_opts_t opts = {KILN_LARGE_CAP, KILN_LARGE_CAP, 0, 0};
    kiln_result_t res = {0, 0};
    kiln_err_t err = kiln_asm_decode_bench_request((const uint8_t *)pw, (size_t)wlen, &br, &arena, &opts, &res);

    jlong reqId = 0;
    jfloat temp = 0.0f;
    jint meta[4] = {0, 0, 0, 0};
    size_t offs[3] = {0, 0, 0}, nbytes = 0;
    if (err == KILN_OK) {
        if (br.inputs.count != 3 || br.inputs.items[0].dtype != KILN_DTYPE_I64 || br.inputs.items[0].rank != 2) {
            err = KILN_ERR_TYPE;
        } else {
            reqId = (jlong)br.request_id;
            temp = (jfloat)br.temperature;
            meta[0] = (jint)br.inputs.items[0].shape[0];
            meta[1] = (jint)br.inputs.items[0].shape[1];
            store_str_off((const uint8_t *)pw, br.model, &meta[2]);
            nbytes = (size_t)br.inputs.items[0].data_len;
            for (int i = 0; i < 3; i++) {
                offs[i] = nbytes > 0 ? (size_t)(br.inputs.items[i].data - (const uint8_t *)pw) : 0;
            }
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, wire, pw, JNI_ABORT);

    if (err != KILN_OK) { throw_err(env, "decodeRequest", (int)err); return -1; }
    (*env)->SetLongArrayRegion(env, outReqId1, 0, 1, &reqId);
    (*env)->SetFloatArrayRegion(env, outTemp1, 0, 1, &temp);
    (*env)->SetIntArrayRegion(env, outMeta4, 0, 4, meta);

    size_t n = nbytes / sizeof(int64_t);
    jlongArray arrs[3];
    for (int i = 0; i < 3; i++) {
        arrs[i] = (*env)->NewLongArray(env, (jsize)n);
        if (!arrs[i]) return -1;
    }
    if (nbytes > 0) {
        jbyte *pw2 = (jbyte *)(*env)->GetPrimitiveArrayCritical(env, wire, NULL);
        for (int i = 0; i < 3; i++) {
            jlong *po = (jlong *)(*env)->GetPrimitiveArrayCritical(env, arrs[i], NULL);
            memcpy(po, (const uint8_t *)pw2 + offs[i], nbytes);
            (*env)->ReleasePrimitiveArrayCritical(env, arrs[i], po, 0);
        }
        (*env)->ReleasePrimitiveArrayCritical(env, wire, pw2, JNI_ABORT);
    }
    for (int i = 0; i < 3; i++) (*env)->SetObjectArrayElement(env, outArrays3, i, arrs[i]);
    return 0;
}

/* ==================== COMPLIANCE (exact JSON decoded output) ==================== */

typedef struct jbuf_t {
    char *p;
    size_t n;
    size_t cap;
} jbuf_t;

static void jb_grow(jbuf_t *jb, size_t extra) {
    if (jb->n + extra + 1 <= jb->cap) return;
    size_t next = jb->cap ? jb->cap * 2 : 1024;
    while (next < jb->n + extra + 1) next *= 2;
    jb->p = (char *)realloc(jb->p, next);
    jb->cap = next;
}

static void jb_str(jbuf_t *jb, const char *s) {
    size_t l = strlen(s);
    jb_grow(jb, l);
    memcpy(jb->p + jb->n, s, l);
    jb->n += l;
    jb->p[jb->n] = '\0';
}

static void jb_u64(jbuf_t *jb, uint64_t v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%" PRIu64, v);
    jb_str(jb, tmp);
}

static void jb_i64(jbuf_t *jb, int64_t v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%" PRId64, v);
    jb_str(jb, tmp);
}

static void jb_json_str(jbuf_t *jb, const uint8_t *s, size_t n) {
    jb_str(jb, "\"");
    for (size_t i = 0; i < n; i++) {
        uint8_t c = s[i];
        if (c == '"' || c == '\\') {
            char esc[3] = {'\\', (char)c, 0};
            jb_str(jb, esc);
        } else if (c < 0x20) {
            char esc[8];
            snprintf(esc, sizeof esc, "\\u%04x", c);
            jb_str(jb, esc);
        } else {
            jb_grow(jb, 1);
            jb->p[jb->n++] = (char)c;
            jb->p[jb->n] = '\0';
        }
    }
    jb_str(jb, "\"");
}

static const char *dtype_json_name(uint16_t d) {
    switch (d) {
        case 1: return "f64"; case 2: return "f32"; case 3: return "f16";
        case 4: return "bf16"; case 5: return "f8e4m3"; case 6: return "f8e5m2";
        case 7: return "bool"; case 8: return "i8"; case 9: return "u8";
        case 10: return "i16"; case 11: return "u16"; case 12: return "i32";
        case 13: return "u32"; case 14: return "i64"; case 15: return "u64";
        case 16: return "i4"; case 17: return "u4"; case 18: return "e2m1";
        case 19: return "e8m0";
        default: return NULL;
    }
}

static void jb_tensor_dir(jbuf_t *jb, const kiln_tensor_dir_t *dir) {
    static const char hex[] = "0123456789abcdef";
    jb_str(jb, "{\"version\":");
    jb_u64(jb, dir->version);
    jb_str(jb, ",\"flags\":[");
    int ff = 0;
    if (dir->flags & 1u) { jb_str(jb, "\"names\""); ff = 1; }
    if (dir->flags & 2u) { if (ff) jb_str(jb, ","); jb_str(jb, "\"le\""); }
    jb_str(jb, "],\"tensors\":[");
    for (uint64_t i = 0; i < dir->count; i++) {
        const kiln_tensor_t *t = &dir->items[i];
        if (i) jb_str(jb, ",");
        jb_str(jb, "{\"name\":");
        if (t->name && t->name_len > 0) jb_json_str(jb, t->name, (size_t)t->name_len);
        else jb_str(jb, "null");
        jb_str(jb, ",\"dtype\":");
        const char *dn = dtype_json_name(t->dtype);
        if (dn) { jb_str(jb, "\""); jb_str(jb, dn); jb_str(jb, "\""); }
        else jb_u64(jb, t->dtype);
        jb_str(jb, ",\"shape\":[");
        for (uint8_t r = 0; r < t->rank; r++) {
            if (r) jb_str(jb, ",");
            jb_u64(jb, t->shape[r]);
        }
        jb_str(jb, "],\"quant_scheme\":");
        jb_u64(jb, t->quant_scheme);
        jb_str(jb, ",\"data_hex\":\"");
        if (t->data_len > 0 && t->data) {
            jb_grow(jb, (size_t)t->data_len * 2);
            for (uint64_t b = 0; b < t->data_len; b++) {
                uint8_t v = t->data[b];
                jb->p[jb->n++] = hex[v >> 4];
                jb->p[jb->n++] = hex[v & 0xF];
            }
            jb->p[jb->n] = '\0';
        }
        jb_str(jb, "\"}");
    }
    jb_str(jb, "],\"block_length\":");
    jb_u64(jb, dir->block_length);
    jb_str(jb, "}");
}

JNIEXPORT jstring JNICALL Java_benchmark_serializers_KilnAsmJni_complianceDecodeJson(
    JNIEnv *env, jclass cls, jbyteArray wire, jint schemaTag) {
    (void)cls;
    jsize wlen = wire ? (*env)->GetArrayLength(env, wire) : 0;
    uint8_t *abuf = tls_reserve(&g_arena, 1 << 20);
    if (!abuf) { throw_err(env, "oom", -1); return NULL; }
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, g_arena.cap);

    uint8_t *copy = wlen > 0 ? tls_reserve(&g_out, (size_t)wlen) : NULL;
    if (wlen > 0) {
        if (!copy) { throw_err(env, "oom", -1); return NULL; }
        (*env)->GetByteArrayRegion(env, wire, 0, wlen, (jbyte *)copy);
    }

    kiln_result_t res = {0, 0};
    kiln_err_t err = KILN_ERR_FRAME;
    jbuf_t jb = {NULL, 0, 0};

    switch (schemaTag) {
        case 0: {
            kiln_tensor_dir_t dir;
            err = kiln_asm_decode_tensors(copy, (size_t)wlen, &dir, &arena, NULL, &res);
            if (err == KILN_OK) jb_tensor_dir(&jb, &dir);
            break;
        }
        case 1: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors_framed(copy, (size_t)wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "{\"hash\":");
                jb_u64(&jb, res.hash);
                jb_str(&jb, ",\"id\":");
                jb_i64(&jb, v.id);
                jb_str(&jb, ",\"batch\":");
                jb_tensor_dir(&jb, &v.batch);
                jb_str(&jb, "}");
            }
            break;
        }
        case 2: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors(copy, (size_t)wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "{\"id\":");
                jb_i64(&jb, v.id);
                jb_str(&jb, ",\"batch\":");
                jb_tensor_dir(&jb, &v.batch);
                jb_str(&jb, "}");
            }
            break;
        }
        case 3: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_f32(copy, (size_t)wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    float fv;
                    memcpy(&fv, raw + i * 4, 4);
                    if (i) jb_str(&jb, ",");
                    char tmp[64];
                    snprintf(tmp, sizeof tmp, "%.9g", (double)fv);
                    jb_str(&jb, tmp);
                }
                jb_str(&jb, "]");
            }
            break;
        }
        case 4: {
            kiln_str_t *items = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_str(copy, (size_t)wlen, &items, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    if (i) jb_str(&jb, ",");
                    jb_json_str(&jb, items[i].ptr, (size_t)items[i].len);
                }
                jb_str(&jb, "]");
            }
            break;
        }
        case 5: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_i64_struct(copy, (size_t)wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                jb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    int64_t iv;
                    memcpy(&iv, raw + i * 8, 8);
                    if (i) jb_str(&jb, ",");
                    jb_str(&jb, "{\"a\":");
                    jb_i64(&jb, iv);
                    jb_str(&jb, "}");
                }
                jb_str(&jb, "]");
            }
            break;
        }
        default:
            err = KILN_ERR_SCHEMA;
            break;
    }

    if (err != KILN_OK) {
        free(jb.p);
        throw_err(env, "compliance", (int)err);
        return NULL;
    }
    jstring ret = (*env)->NewStringUTF(env, jb.p ? jb.p : "null");
    free(jb.p);
    return ret;
}
