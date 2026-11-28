/* C11 helpers for Fortran gld-kiln-asm integration (Tier 1 ISO_C_BINDING). */
#include "kiln_asm_bench.h"
#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* Verify C-ABI struct sizes expected by ser_kiln_asm.f90 bind(C) types. */
_Static_assert(sizeof(kiln_arena_t) == 24, "kiln_arena_t");
_Static_assert(sizeof(kiln_read_opts_t) == 24, "kiln_read_opts_t");
_Static_assert(sizeof(kiln_result_t) == 16, "kiln_result_t");
_Static_assert(sizeof(kiln_str_t) == 16, "kiln_str_t");
_Static_assert(sizeof(kiln_tensor_t) == 144, "kiln_tensor_t");
_Static_assert(sizeof(kiln_tensor_dir_t) == 32, "kiln_tensor_dir_t");
_Static_assert(sizeof(bench_message_t) == 64, "bench_message_t");
_Static_assert(sizeof(bench_document_document_meta_t) == 24, "bench_document_document_meta_t");
_Static_assert(sizeof(bench_document_document_item_t) == 32, "bench_document_document_item_t");
_Static_assert(sizeof(bench_document_t) == 64, "bench_document_t");
_Static_assert(sizeof(bench_telemetry_t) == 56, "bench_telemetry_t");
_Static_assert(sizeof(bench_strings_t) == 16, "bench_strings_t");
_Static_assert(sizeof(bench_event_event_attr_t) == 32, "bench_event_event_attr_t");
_Static_assert(sizeof(bench_event_t) == 72, "bench_event_t");

void kiln_f_memcpy(void *dst, const void *src, size_t n) {
    if (n > 0) memcpy(dst, src, n);
}

void kiln_f_ptr_add(const void *base, size_t offset, const void **out) {
    *out = (const uint8_t *)base + offset;
}

/* Compliance probe for compliance/data/kiln/v2.json (46 vectors).
 * Tag values packed by fortran/scripts/compliance_report.py:
 *   0 = tensor-v2
 *   1 = frame (id:i64, batch:tensors framed KLN0)
 *   2 = struct{id:i64, batch:tensors}
 *   3 = list<f32>
 *   4 = list<str>
 *   5 = list<struct{a:i64}>
 * Returns 1 if accepted (KILN_OK), 0 if rejected.
 */
int32_t kiln_f_compliance_probe(uint8_t tag, const uint8_t *data, size_t len) {
    static uint8_t arena_mem[1 << 20];
    kiln_arena_t arena;
    kiln_result_t res;
    kiln_err_t err = KILN_ERR_FRAME;

    kiln_arena_init(&arena, arena_mem, sizeof arena_mem);
    switch (tag) {
        case 0: {
            kiln_tensor_dir_t dir;
            err = kiln_asm_decode_tensors(data, len, &dir, &arena, NULL, &res);
            break;
        }
        case 1: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors_framed(data, len, &v, &arena, NULL, &res);
            break;
        }
        case 2: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors(data, len, &v, &arena, NULL, &res);
            break;
        }
        case 3: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_f32(data, len, &raw, &cnt, &arena, NULL, &res);
            break;
        }
        case 4: {
            kiln_str_t *items = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_str(data, len, &items, &cnt, &arena, NULL, &res);
            break;
        }
        case 5: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_i64_struct(data, len, &raw, &cnt, &arena, NULL, &res);
            break;
        }
        default:
            return 0;
    }
    return err == KILN_OK ? 1 : 0;
}
