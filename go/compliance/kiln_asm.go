package main

/*
#cgo CFLAGS: -O3 -Wall -Wextra -I${SRCDIR}/../../build/kiln-asm/include
#cgo LDFLAGS: ${SRCDIR}/../../build/kiln-asm/libkiln_asm_bench.a
#include "kiln_asm_bench.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct go_jbuf_t {
    char *p;
    size_t n;
    size_t cap;
} go_jbuf_t;

static void gjb_grow(go_jbuf_t *jb, size_t extra) {
    if (jb->n + extra + 1 <= jb->cap) return;
    size_t next = jb->cap ? jb->cap * 2 : 1024;
    while (next < jb->n + extra + 1) next *= 2;
    jb->p = (char *)realloc(jb->p, next);
    jb->cap = next;
}

static void gjb_str(go_jbuf_t *jb, const char *s) {
    size_t l = strlen(s);
    gjb_grow(jb, l);
    memcpy(jb->p + jb->n, s, l);
    jb->n += l;
    jb->p[jb->n] = '\0';
}

static void gjb_u64(go_jbuf_t *jb, uint64_t v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%" PRIu64, v);
    gjb_str(jb, tmp);
}

static void gjb_i64(go_jbuf_t *jb, int64_t v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%" PRId64, v);
    gjb_str(jb, tmp);
}

static void gjb_json_str(go_jbuf_t *jb, const uint8_t *s, size_t n) {
    gjb_str(jb, "\"");
    for (size_t i = 0; i < n; i++) {
        uint8_t c = s[i];
        if (c == '"' || c == '\\') {
            char esc[3] = {'\\', (char)c, 0};
            gjb_str(jb, esc);
        } else if (c < 0x20) {
            char esc[8];
            snprintf(esc, sizeof esc, "\\u%04x", c);
            gjb_str(jb, esc);
        } else {
            gjb_grow(jb, 1);
            jb->p[jb->n++] = (char)c;
            jb->p[jb->n] = '\0';
        }
    }
    gjb_str(jb, "\"");
}

static const char *go_dtype_name(uint16_t d) {
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

static void gjb_tensor_dir(go_jbuf_t *jb, const kiln_tensor_dir_t *dir) {
    static const char hex[] = "0123456789abcdef";
    gjb_str(jb, "{\"version\":");
    gjb_u64(jb, dir->version);
    gjb_str(jb, ",\"flags\":[");
    int ff = 0;
    if (dir->flags & 1u) { gjb_str(jb, "\"names\""); ff = 1; }
    if (dir->flags & 2u) { if (ff) gjb_str(jb, ","); gjb_str(jb, "\"le\""); }
    gjb_str(jb, "],\"tensors\":[");
    for (uint64_t i = 0; i < dir->count; i++) {
        const kiln_tensor_t *t = &dir->items[i];
        if (i) gjb_str(jb, ",");
        gjb_str(jb, "{\"name\":");
        if (t->name && t->name_len > 0) gjb_json_str(jb, t->name, (size_t)t->name_len);
        else gjb_str(jb, "null");
        gjb_str(jb, ",\"dtype\":");
        const char *dn = go_dtype_name(t->dtype);
        if (dn) { gjb_str(jb, "\""); gjb_str(jb, dn); gjb_str(jb, "\""); }
        else gjb_u64(jb, t->dtype);
        gjb_str(jb, ",\"shape\":[");
        for (uint8_t r = 0; r < t->rank; r++) {
            if (r) gjb_str(jb, ",");
            gjb_u64(jb, t->shape[r]);
        }
        gjb_str(jb, "],\"quant_scheme\":");
        gjb_u64(jb, t->quant_scheme);
        gjb_str(jb, ",\"data_hex\":\"");
        if (t->data_len > 0 && t->data) {
            gjb_grow(jb, (size_t)t->data_len * 2);
            for (uint64_t b = 0; b < t->data_len; b++) {
                uint8_t v = t->data[b];
                jb->p[jb->n++] = hex[v >> 4];
                jb->p[jb->n++] = hex[v & 0xF];
            }
            jb->p[jb->n] = '\0';
        }
        gjb_str(jb, "\"}");
    }
    gjb_str(jb, "],\"block_length\":");
    gjb_u64(jb, dir->block_length);
    gjb_str(jb, "}");
}

static int go_kiln_compliance_decode(const uint8_t *wire, size_t wlen, int tag, char **out_json) {
    *out_json = NULL;
    uint8_t *abuf = (uint8_t *)malloc(1u << 20);
    if (!abuf) return -1;
    kiln_arena_t arena;
    kiln_arena_init(&arena, abuf, 1u << 20);
    kiln_result_t res = {0, 0};
    kiln_err_t err = KILN_ERR_FRAME;
    go_jbuf_t jb = {NULL, 0, 0};

    switch (tag) {
        case 0: {
            kiln_tensor_dir_t dir;
            err = kiln_asm_decode_tensors(wire, wlen, &dir, &arena, NULL, &res);
            if (err == KILN_OK) gjb_tensor_dir(&jb, &dir);
            break;
        }
        case 1: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors_framed(wire, wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                gjb_str(&jb, "{\"hash\":");
                gjb_u64(&jb, res.hash);
                gjb_str(&jb, ",\"id\":");
                gjb_i64(&jb, v.id);
                gjb_str(&jb, ",\"batch\":");
                gjb_tensor_dir(&jb, &v.batch);
                gjb_str(&jb, "}");
            }
            break;
        }
        case 2: {
            kiln_id_tensors_t v;
            err = kiln_asm_decode_id_tensors(wire, wlen, &v, &arena, NULL, &res);
            if (err == KILN_OK) {
                gjb_str(&jb, "{\"id\":");
                gjb_i64(&jb, v.id);
                gjb_str(&jb, ",\"batch\":");
                gjb_tensor_dir(&jb, &v.batch);
                gjb_str(&jb, "}");
            }
            break;
        }
        case 3: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_f32(wire, wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                gjb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    float fv;
                    memcpy(&fv, raw + i * 4, 4);
                    if (i) gjb_str(&jb, ",");
                    char tmp[64];
                    snprintf(tmp, sizeof tmp, "%.9g", (double)fv);
                    gjb_str(&jb, tmp);
                }
                gjb_str(&jb, "]");
            }
            break;
        }
        case 4: {
            kiln_str_t *items = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_str(wire, wlen, &items, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                gjb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    if (i) gjb_str(&jb, ",");
                    gjb_json_str(&jb, items[i].ptr, (size_t)items[i].len);
                }
                gjb_str(&jb, "]");
            }
            break;
        }
        case 5: {
            const uint8_t *raw = NULL;
            size_t cnt = 0;
            err = kiln_asm_decode_list_i64_struct(wire, wlen, &raw, &cnt, &arena, NULL, &res);
            if (err == KILN_OK) {
                gjb_str(&jb, "[");
                for (size_t i = 0; i < cnt; i++) {
                    int64_t iv;
                    memcpy(&iv, raw + i * 8, 8);
                    if (i) gjb_str(&jb, ",");
                    gjb_str(&jb, "{\"a\":");
                    gjb_i64(&jb, iv);
                    gjb_str(&jb, "}");
                }
                gjb_str(&jb, "]");
            }
            break;
        }
        default:
            err = KILN_ERR_SCHEMA;
            break;
    }

    free(abuf);
    if (err != KILN_OK) {
        free(jb.p);
        return (int)err;
    }
    *out_json = jb.p;
    return 0;
}

static const char *go_kiln_asm_ver(void) {
    return kiln_asm_version();
}
*/
import "C"

import (
	"encoding/json"
	"fmt"
	"unsafe"
)

func kilnAsmVersion() string {
	return C.GoString(C.go_kiln_asm_ver())
}

func decodeKilnAsm(b []byte, schema string) (any, error) {
	tag := 0
	switch schema {
	case "", "tensor-v2":
		tag = 0
	case "frame":
		tag = 1
	default:
		var obj struct {
			Type    string `json:"type"`
			Element string `json:"element"`
		}
		if err := json.Unmarshal([]byte(schema), &obj); err != nil {
			return nil, fmt.Errorf("gld-kiln-asm: unsupported schema %q", schema)
		}
		switch obj.Type {
		case "struct":
			tag = 2
		case "list":
			switch obj.Element {
			case "f32":
				tag = 3
			case "str":
				tag = 4
			case "struct{a:i64}":
				tag = 5
			default:
				return nil, fmt.Errorf("gld-kiln-asm: unsupported list element %q", obj.Element)
			}
		default:
			return nil, fmt.Errorf("gld-kiln-asm: unsupported schema type %q", obj.Type)
		}
	}

	var ptr *C.uint8_t
	if len(b) > 0 {
		ptr = (*C.uint8_t)(unsafe.Pointer(&b[0]))
	}
	var outJSON *C.char
	rc := C.go_kiln_compliance_decode(ptr, C.size_t(len(b)), C.int(tag), &outJSON)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: decode error %d", int(rc))
	}
	if outJSON == nil {
		return nil, nil
	}
	defer C.free(unsafe.Pointer(outJSON))
	js := C.GoString(outJSON)
	var v any
	if err := json.Unmarshal([]byte(js), &v); err != nil {
		return nil, fmt.Errorf("gld-kiln-asm: json parse: %w", err)
	}
	return v, nil
}
