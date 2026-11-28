package serializers

/*
#cgo CFLAGS: -O3 -Wall -Wextra -I${SRCDIR}/../../build/kiln-asm/include
#cgo LDFLAGS: ${SRCDIR}/../../build/kiln-asm/libkiln_asm_bench.a
#include "kiln_asm_c.h"
*/
import "C"

import (
	"fmt"
	"io"
	"runtime"
	"unsafe"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// gldKilnAsm delegates Kiln wire v2 encoding and decoding to the shared C/assembly
// library build/kiln-asm/libkiln_asm_bench.a via flat-pointer cgo bridges.
// Full RFC 3629 UTF-8 validation is always active; tensor_view borrows the encoded bytes.
type gldKilnAsm struct {
	ctx *C.go_kiln_ctx_t

	fxName string
	batch  bool
	value  any

	// Reusable scratch buffers (zero steady-state heap allocations for encode/decode staging).
	out     []byte
	strBuf  []byte
	bBuf    []uint8
	i32Buf  []int32
	i32Buf2 []int32
	u32Buf  []uint32
	u32Buf2 []uint32
	u32Buf3 []uint32
	u32Buf4 []uint32
	i64Buf  []int64
	i64Buf2 []int64
	f64Buf  []float64
}

func newGldKilnAsm() *gldKilnAsm {
	s := &gldKilnAsm{
		ctx: C.go_kiln_ctx_new(),
		out: make([]byte, 0, 4096),
	}
	runtime.SetFinalizer(s, func(x *gldKilnAsm) {
		if x.ctx != nil {
			C.go_kiln_ctx_free(x.ctx)
			x.ctx = nil
		}
	})
	return s
}

func (s *gldKilnAsm) Name() string           { return "gld-kiln-asm" }
func (s *gldKilnAsm) Version() string        { return C.GoString(C.go_kiln_version()) }
func (s *gldKilnAsm) StreamMode() StreamMode { return StreamAdapted }
func (s *gldKilnAsm) NativeKind() NativeKind { return NativeSchema }

func (s *gldKilnAsm) Supports(n string) bool {
	switch n {
	case "message", "document", "telemetry", "strings", "event",
		"table", "table_project", "nested_table", "signal",
		"tensor", "tensor_view", "prompt", "shard", "request":
		return true
	default:
		return false
	}
}

func (s *gldKilnAsm) Prepare(fx model.Fixture) error {
	if !s.Supports(fx.Name) {
		return fmt.Errorf("gld-kiln-asm: unsupported fixture %s", fx.Name)
	}
	s.fxName = fx.Name
	s.batch = isSlice(fx.Value)
	s.value = fx.Value
	return nil
}

func (s *gldKilnAsm) ToDomain(decoded any) (any, error) {
	if view, ok := decoded.(tensorView); ok {
		return tensorFromView(view)
	}
	return decoded, nil
}

func (s *gldKilnAsm) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *gldKilnAsm) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

// ---------- pointer / slice helpers ----------

func u8Ptr(b []byte) *C.uint8_t {
	if len(b) == 0 {
		return nil
	}
	return (*C.uint8_t)(unsafe.Pointer(&b[0]))
}

func strPtr(s string) *C.uint8_t {
	if len(s) == 0 {
		return nil
	}
	return (*C.uint8_t)(unsafe.Pointer(unsafe.StringData(s)))
}

func i32Ptr(s []int32) *C.int32_t {
	if len(s) == 0 {
		return nil
	}
	return (*C.int32_t)(unsafe.Pointer(&s[0]))
}

func u32Ptr(s []uint32) *C.uint32_t {
	if len(s) == 0 {
		return nil
	}
	return (*C.uint32_t)(unsafe.Pointer(&s[0]))
}

func i64Ptr(s []int64) *C.int64_t {
	if len(s) == 0 {
		return nil
	}
	return (*C.int64_t)(unsafe.Pointer(&s[0]))
}

func f32Ptr(s []float32) *C.float {
	if len(s) == 0 {
		return nil
	}
	return (*C.float)(unsafe.Pointer(&s[0]))
}

func f64Ptr(s []float64) *C.double {
	if len(s) == 0 {
		return nil
	}
	return (*C.double)(unsafe.Pointer(&s[0]))
}

func ensureU8(buf []uint8, n int) []uint8 {
	if cap(buf) < n {
		return make([]uint8, n)
	}
	return buf[:n]
}

func ensureI32(buf []int32, n int) []int32 {
	if cap(buf) < n {
		return make([]int32, n)
	}
	return buf[:n]
}

func ensureU32(buf []uint32, n int) []uint32 {
	if cap(buf) < n {
		return make([]uint32, n)
	}
	return buf[:n]
}

func ensureI64(buf []int64, n int) []int64 {
	if cap(buf) < n {
		return make([]int64, n)
	}
	return buf[:n]
}

func ensureF64(buf []float64, n int) []float64 {
	if cap(buf) < n {
		return make([]float64, n)
	}
	return buf[:n]
}

func (s *gldKilnAsm) copyOut(n C.size_t) []byte {
	ln := int(n)
	if cap(s.out) < ln {
		s.out = make([]byte, ln)
	} else {
		s.out = s.out[:ln]
	}
	if ln > 0 {
		src := unsafe.Slice((*byte)(unsafe.Pointer(C.go_kiln_ctx_out_ptr(s.ctx))), ln)
		copy(s.out, src)
	}
	return s.out
}

func boolU8(b bool) C.uint8_t {
	if b {
		return 1
	}
	return 0
}

func cBool(b bool) C.int {
	if b {
		return 1
	}
	return 0
}

func spanString(data []byte, off, ln uint32) string {
	if ln == 0 {
		return ""
	}
	return string(data[off : off+ln])
}

func copyF32FromWire(data []byte, off, nbytes C.size_t) []float32 {
	n := int(nbytes) / 4
	out := make([]float32, n)
	if n > 0 {
		dst := unsafe.Slice((*byte)(unsafe.Pointer(&out[0])), int(nbytes))
		copy(dst, data[int(off):int(off)+int(nbytes)])
	}
	return out
}

func copyI64FromWire(data []byte, off, nbytes C.size_t) []int64 {
	n := int(nbytes) / 8
	out := make([]int64, n)
	if n > 0 {
		dst := unsafe.Slice((*byte)(unsafe.Pointer(&out[0])), int(nbytes))
		copy(dst, data[int(off):int(off)+int(nbytes)])
	}
	return out
}

// ---------- SerializeBytes ----------

func (s *gldKilnAsm) SerializeBytes(fx model.Fixture) ([]byte, error) {
	val := fx.Value
	if val == nil {
		val = s.value
	}
	switch s.fxName {
	case "message":
		return s.encodeMessage(val)
	case "document":
		return s.encodeDocument(val, false)
	case "nested_table":
		return s.encodeNested(val)
	case "telemetry":
		return s.encodeTelemetry(val)
	case "strings":
		return s.encodeStrings(val)
	case "event":
		return s.encodeEvent(val)
	case "table", "table_project":
		return s.encodeTable(val)
	case "signal":
		return s.encodeSignal(val)
	case "tensor", "tensor_view":
		return s.encodeTensor(val.(modelv2.Tensor))
	case "prompt":
		return s.encodePrompt(val.(modelv2.Prompt))
	case "shard":
		return s.encodeShard(val.(modelv2.Shard))
	case "request":
		return s.encodeRequest(val.(modelv2.Request))
	default:
		return nil, fmt.Errorf("gld-kiln-asm: unsupported encode %s", s.fxName)
	}
}

func (s *gldKilnAsm) encodeMessage(val any) ([]byte, error) {
	var outLen C.size_t
	if !s.batch {
		m := val.(modelv2.Message)
		rc := C.go_kiln_encode_message(
			s.ctx,
			boolU8(m.FBool), C.int32_t(m.FInt32), C.int64_t(m.FInt64), C.double(m.FFloat64),
			strPtr(m.FString), C.size_t(len(m.FString)),
			boolU8(m.FBool2), C.int32_t(m.FInt32_2),
			strPtr(m.FString2), C.size_t(len(m.FString2)),
			&outLen,
		)
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: encode message err=%d", int(rc))
		}
		return s.copyOut(outLen), nil
	}

	rows := val.([]modelv2.Message)
	n := len(rows)
	s.bBuf = ensureU8(s.bBuf, 2*n)
	s.i32Buf = ensureI32(s.i32Buf, 2*n)
	s.i64Buf = ensureI64(s.i64Buf, n)
	s.f64Buf = ensureF64(s.f64Buf, n)
	s.u32Buf = ensureU32(s.u32Buf, 2*n)
	s.strBuf = s.strBuf[:0]
	for i := range rows {
		r := &rows[i]
		if r.FBool {
			s.bBuf[2*i] = 1
		} else {
			s.bBuf[2*i] = 0
		}
		if r.FBool2 {
			s.bBuf[2*i+1] = 1
		} else {
			s.bBuf[2*i+1] = 0
		}
		s.i32Buf[2*i] = r.FInt32
		s.i32Buf[2*i+1] = r.FInt32_2
		s.i64Buf[i] = r.FInt64
		s.f64Buf[i] = r.FFloat64
		s.u32Buf[2*i] = uint32(len(r.FString))
		s.strBuf = append(s.strBuf, r.FString...)
		s.u32Buf[2*i+1] = uint32(len(r.FString2))
		s.strBuf = append(s.strBuf, r.FString2...)
	}
	rc := C.go_kiln_encode_message_batch(
		s.ctx, C.size_t(n),
		u8Ptr(s.bBuf), i32Ptr(s.i32Buf), i64Ptr(s.i64Buf), f64Ptr(s.f64Buf),
		u8Ptr(s.strBuf), u32Ptr(s.u32Buf),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode message batch err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeDocument(val any, isNested bool) ([]byte, error) {
	var rows []modelv2.Document
	if !s.batch {
		rows = []modelv2.Document{val.(modelv2.Document)}
	} else {
		rows = val.([]modelv2.Document)
	}
	n := len(rows)
	totalItems := 0
	for i := range rows {
		totalItems += len(rows[i].Items)
	}
	s.i32Buf = ensureI32(s.i32Buf, 2*n)
	s.u32Buf = ensureU32(s.u32Buf, n)
	s.i32Buf2 = ensureI32(s.i32Buf2, totalItems)
	s.i64Buf = ensureI64(s.i64Buf, totalItems)
	s.u32Buf2 = ensureU32(s.u32Buf2, 2*n+totalItems)
	s.strBuf = s.strBuf[:0]

	sl := 0
	ip := 0
	for i := range rows {
		d := &rows[i]
		s.i32Buf[2*i] = d.Status
		s.i32Buf[2*i+1] = d.Meta.Version
		s.u32Buf[i] = uint32(len(d.Items))
		s.u32Buf2[sl] = uint32(len(d.ID))
		sl++
		s.strBuf = append(s.strBuf, d.ID...)
		s.u32Buf2[sl] = uint32(len(d.Meta.Region))
		sl++
		s.strBuf = append(s.strBuf, d.Meta.Region...)
		for j := range d.Items {
			it := &d.Items[j]
			s.u32Buf2[sl] = uint32(len(it.SKU))
			sl++
			s.strBuf = append(s.strBuf, it.SKU...)
			s.i32Buf2[ip] = it.Qty
			s.i64Buf[ip] = it.PriceMinor
			ip++
		}
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_document(
		s.ctx, cBool(isNested), cBool(s.batch), C.size_t(n),
		i32Ptr(s.i32Buf), u32Ptr(s.u32Buf),
		i32Ptr(s.i32Buf2), i64Ptr(s.i64Buf),
		u8Ptr(s.strBuf), u32Ptr(s.u32Buf2),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode document err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeNested(val any) ([]byte, error) {
	var rows []modelv2.NestedRow
	if !s.batch {
		rows = []modelv2.NestedRow{val.(modelv2.NestedRow)}
	} else {
		rows = val.([]modelv2.NestedRow)
	}
	n := len(rows)
	totalItems := 0
	for i := range rows {
		totalItems += len(rows[i].Items)
	}
	s.i32Buf = ensureI32(s.i32Buf, 2*n)
	s.u32Buf = ensureU32(s.u32Buf, n)
	s.i32Buf2 = ensureI32(s.i32Buf2, totalItems)
	s.i64Buf = ensureI64(s.i64Buf, totalItems)
	s.u32Buf2 = ensureU32(s.u32Buf2, 2*n+totalItems)
	s.strBuf = s.strBuf[:0]

	sl := 0
	ip := 0
	for i := range rows {
		d := &rows[i]
		s.i32Buf[2*i] = d.Status
		s.i32Buf[2*i+1] = d.Meta.Version
		s.u32Buf[i] = uint32(len(d.Items))
		s.u32Buf2[sl] = uint32(len(d.ID))
		sl++
		s.strBuf = append(s.strBuf, d.ID...)
		s.u32Buf2[sl] = uint32(len(d.Meta.Region))
		sl++
		s.strBuf = append(s.strBuf, d.Meta.Region...)
		for j := range d.Items {
			it := &d.Items[j]
			s.u32Buf2[sl] = uint32(len(it.SKU))
			sl++
			s.strBuf = append(s.strBuf, it.SKU...)
			s.i32Buf2[ip] = it.Qty
			s.i64Buf[ip] = it.PriceMinor
			ip++
		}
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_document(
		s.ctx, 1, cBool(s.batch), C.size_t(n),
		i32Ptr(s.i32Buf), u32Ptr(s.u32Buf),
		i32Ptr(s.i32Buf2), i64Ptr(s.i64Buf),
		u8Ptr(s.strBuf), u32Ptr(s.u32Buf2),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode nested_table err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeTelemetry(val any) ([]byte, error) {
	var rows []modelv2.Telemetry
	if !s.batch {
		rows = []modelv2.Telemetry{val.(modelv2.Telemetry)}
	} else {
		rows = val.([]modelv2.Telemetry)
	}
	n := len(rows)
	totalTags, totalVals := 0, 0
	for i := range rows {
		totalTags += len(rows[i].Tags)
		totalVals += len(rows[i].Values)
	}
	s.i64Buf = ensureI64(s.i64Buf, n)
	s.u32Buf = ensureU32(s.u32Buf, n)
	s.u32Buf2 = ensureU32(s.u32Buf2, n)
	s.f64Buf = ensureF64(s.f64Buf, totalVals)
	s.u32Buf3 = ensureU32(s.u32Buf3, n+totalTags)
	s.strBuf = s.strBuf[:0]

	sl := 0
	vp := 0
	for i := range rows {
		r := &rows[i]
		s.i64Buf[i] = r.TS
		s.u32Buf[i] = uint32(len(r.Tags))
		s.u32Buf2[i] = uint32(len(r.Values))
		s.u32Buf3[sl] = uint32(len(r.Source))
		sl++
		s.strBuf = append(s.strBuf, r.Source...)
		for _, tg := range r.Tags {
			s.u32Buf3[sl] = uint32(len(tg))
			sl++
			s.strBuf = append(s.strBuf, tg...)
		}
		copy(s.f64Buf[vp:], r.Values)
		vp += len(r.Values)
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_telemetry(
		s.ctx, cBool(s.batch), C.size_t(n),
		i64Ptr(s.i64Buf), u32Ptr(s.u32Buf), u32Ptr(s.u32Buf2),
		f64Ptr(s.f64Buf), u8Ptr(s.strBuf), u32Ptr(s.u32Buf3),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode telemetry err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeStrings(val any) ([]byte, error) {
	var rows []modelv2.Strings
	if !s.batch {
		rows = []modelv2.Strings{val.(modelv2.Strings)}
	} else {
		rows = val.([]modelv2.Strings)
	}
	n := len(rows)
	total := 0
	for i := range rows {
		total += len(rows[i].Items)
	}
	s.u32Buf = ensureU32(s.u32Buf, n)
	s.u32Buf2 = ensureU32(s.u32Buf2, total)
	s.strBuf = s.strBuf[:0]

	pos := 0
	for i := range rows {
		items := rows[i].Items
		s.u32Buf[i] = uint32(len(items))
		for _, it := range items {
			s.u32Buf2[pos] = uint32(len(it))
			pos++
			s.strBuf = append(s.strBuf, it...)
		}
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_strings(
		s.ctx, cBool(s.batch), C.size_t(n),
		u32Ptr(s.u32Buf), u8Ptr(s.strBuf), u32Ptr(s.u32Buf2),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode strings err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeEvent(val any) ([]byte, error) {
	var rows []modelv2.Event
	if !s.batch {
		rows = []modelv2.Event{val.(modelv2.Event)}
	} else {
		rows = val.([]modelv2.Event)
	}
	n := len(rows)
	totalAttrs := 0
	for i := range rows {
		totalAttrs += len(rows[i].Attrs)
	}
	s.i64Buf = ensureI64(s.i64Buf, n)
	s.u32Buf = ensureU32(s.u32Buf, n)
	s.u32Buf2 = ensureU32(s.u32Buf2, 3*n+2*totalAttrs)
	s.strBuf = s.strBuf[:0]

	sl := 0
	for i := range rows {
		e := &rows[i]
		s.i64Buf[i] = e.OccurredAt
		s.u32Buf[i] = uint32(len(e.Attrs))
		s.u32Buf2[sl] = uint32(len(e.EventID))
		sl++
		s.strBuf = append(s.strBuf, e.EventID...)
		s.u32Buf2[sl] = uint32(len(e.EventType))
		sl++
		s.strBuf = append(s.strBuf, e.EventType...)
		s.u32Buf2[sl] = uint32(len(e.Producer))
		sl++
		s.strBuf = append(s.strBuf, e.Producer...)
		for j := range e.Attrs {
			a := &e.Attrs[j]
			s.u32Buf2[sl] = uint32(len(a.Key))
			sl++
			s.strBuf = append(s.strBuf, a.Key...)
			s.u32Buf2[sl] = uint32(len(a.Value))
			sl++
			s.strBuf = append(s.strBuf, a.Value...)
		}
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_event(
		s.ctx, cBool(s.batch), C.size_t(n),
		i64Ptr(s.i64Buf), u32Ptr(s.u32Buf),
		u8Ptr(s.strBuf), u32Ptr(s.u32Buf2),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode event err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeTable(val any) ([]byte, error) {
	var rows []modelv2.TableRow
	if !s.batch {
		rows = []modelv2.TableRow{val.(modelv2.TableRow)}
	} else {
		rows = val.([]modelv2.TableRow)
	}
	n := len(rows)
	s.f64Buf = ensureF64(s.f64Buf, 16*n)
	s.i64Buf = ensureI64(s.i64Buf, 4*n)
	s.u32Buf = ensureU32(s.u32Buf, 2*n)
	s.strBuf = s.strBuf[:0]

	// Transpose rows -> column-major on the clock.
	f := s.f64Buf
	iv := s.i64Buf
	for r := range rows {
		row := &rows[r]
		f[0*n+r] = row.FFloat0
		f[1*n+r] = row.FFloat1
		f[2*n+r] = row.FFloat2
		f[3*n+r] = row.FFloat3
		f[4*n+r] = row.FFloat4
		f[5*n+r] = row.FFloat5
		f[6*n+r] = row.FFloat6
		f[7*n+r] = row.FFloat7
		f[8*n+r] = row.FFloat8
		f[9*n+r] = row.FFloat9
		f[10*n+r] = row.FFloat10
		f[11*n+r] = row.FFloat11
		f[12*n+r] = row.FFloat12
		f[13*n+r] = row.FFloat13
		f[14*n+r] = row.FFloat14
		f[15*n+r] = row.FFloat15
		iv[0*n+r] = row.FInt0
		iv[1*n+r] = row.FInt1
		iv[2*n+r] = row.FInt2
		iv[3*n+r] = row.FInt3
	}
	for r := range rows {
		st := rows[r].FStr0
		s.u32Buf[r] = uint32(len(st))
		s.strBuf = append(s.strBuf, st...)
	}
	for r := range rows {
		st := rows[r].FStr1
		s.u32Buf[n+r] = uint32(len(st))
		s.strBuf = append(s.strBuf, st...)
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_table(
		s.ctx, C.size_t(n),
		f64Ptr(s.f64Buf), i64Ptr(s.i64Buf),
		u8Ptr(s.strBuf), u32Ptr(s.u32Buf),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode table err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeSignal(val any) ([]byte, error) {
	var rows []modelv2.Signal
	if !s.batch {
		rows = []modelv2.Signal{val.(modelv2.Signal)}
	} else {
		rows = val.([]modelv2.Signal)
	}
	n := len(rows)
	totalLegs := 0
	for i := range rows {
		totalLegs += len(rows[i].Legs)
	}
	s.i64Buf = ensureI64(s.i64Buf, 3*n)
	s.i32Buf = ensureI32(s.i32Buf, 2*n)
	s.u32Buf = ensureU32(s.u32Buf, n)
	s.i64Buf2 = ensureI64(s.i64Buf2, totalLegs)
	s.i32Buf2 = ensureI32(s.i32Buf2, 2*totalLegs)
	s.u32Buf2 = ensureU32(s.u32Buf2, 2*n)
	s.strBuf = s.strBuf[:0]

	lp := 0
	for i := range rows {
		sg := &rows[i]
		s.i64Buf[3*i+0] = sg.Seq
		s.i64Buf[3*i+1] = sg.TS
		s.i64Buf[3*i+2] = sg.PriceMantissa
		s.i32Buf[2*i+0] = sg.Qty
		s.i32Buf[2*i+1] = sg.Flags
		s.u32Buf[i] = uint32(len(sg.Legs))
		s.u32Buf2[2*i+0] = uint32(len(sg.Symbol))
		s.strBuf = append(s.strBuf, sg.Symbol...)
		s.u32Buf2[2*i+1] = uint32(len(sg.Venue))
		s.strBuf = append(s.strBuf, sg.Venue...)
		for j := range sg.Legs {
			lg := &sg.Legs[j]
			s.i64Buf2[lp] = lg.LegID
			s.i32Buf2[2*lp+0] = lg.LegQty
			s.i32Buf2[2*lp+1] = lg.LegPad
			lp++
		}
	}
	var outLen C.size_t
	rc := C.go_kiln_encode_signal(
		s.ctx, cBool(s.batch), C.size_t(n),
		i64Ptr(s.i64Buf), i32Ptr(s.i32Buf), u32Ptr(s.u32Buf),
		i64Ptr(s.i64Buf2), i32Ptr(s.i32Buf2),
		u8Ptr(s.strBuf), u32Ptr(s.u32Buf2),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode signal err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeTensor(t modelv2.Tensor) ([]byte, error) {
	var outLen C.size_t
	rc := C.go_kiln_encode_tensor(
		s.ctx, C.int32_t(t.Rows), C.int32_t(t.Cols),
		f32Ptr(t.Values), C.size_t(len(t.Values)), &outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode tensor err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodePrompt(p modelv2.Prompt) ([]byte, error) {
	var outLen C.size_t
	rc := C.go_kiln_encode_prompt(
		s.ctx, C.int32_t(p.Batch), C.int32_t(p.Seq),
		i64Ptr(p.InputIDs), i64Ptr(p.AttentionMask), i64Ptr(p.PositionIDs),
		C.size_t(len(p.InputIDs)), &outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode prompt err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeShard(sh modelv2.Shard) ([]byte, error) {
	var outLen C.size_t
	rc := C.go_kiln_encode_shard(
		s.ctx, C.int32_t(sh.Vocab), C.int32_t(sh.Hidden), C.int32_t(sh.FFN),
		f32Ptr(sh.TokEmb), C.size_t(len(sh.TokEmb)),
		f32Ptr(sh.Attn), C.size_t(len(sh.Attn)),
		f32Ptr(sh.FFNWeight), C.size_t(len(sh.FFNWeight)),
		f32Ptr(sh.Norm), C.size_t(len(sh.Norm)),
		&outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode shard err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

func (s *gldKilnAsm) encodeRequest(req modelv2.Request) ([]byte, error) {
	var outLen C.size_t
	rc := C.go_kiln_encode_request(
		s.ctx, C.int64_t(req.RequestID), strPtr(req.Model), C.size_t(len(req.Model)),
		C.float(req.Temperature), C.int32_t(req.Inputs.Batch), C.int32_t(req.Inputs.Seq),
		i64Ptr(req.Inputs.InputIDs), i64Ptr(req.Inputs.AttentionMask), i64Ptr(req.Inputs.PositionIDs),
		C.size_t(len(req.Inputs.InputIDs)), &outLen,
	)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: encode request err=%d", int(rc))
	}
	return s.copyOut(outLen), nil
}

// ---------- DeserializeBytes ----------

func (s *gldKilnAsm) DeserializeBytes(data []byte) (any, error) {
	switch s.fxName {
	case "message":
		return s.decodeMessage(data)
	case "document":
		return s.decodeDocument(data)
	case "nested_table":
		return s.decodeNested(data)
	case "telemetry":
		return s.decodeTelemetry(data)
	case "strings":
		return s.decodeStrings(data)
	case "event":
		return s.decodeEvent(data)
	case "table":
		return s.decodeTable(data)
	case "table_project":
		return s.decodeTableProject(data)
	case "signal":
		return s.decodeSignal(data)
	case "tensor":
		return s.decodeTensor(data, false)
	case "tensor_view":
		return s.decodeTensor(data, true)
	case "prompt":
		return s.decodePrompt(data)
	case "shard":
		return s.decodeShard(data)
	case "request":
		return s.decodeRequest(data)
	default:
		return nil, fmt.Errorf("gld-kiln-asm: unsupported decode %s", s.fxName)
	}
}

func (s *gldKilnAsm) decodeMessage(data []byte) (any, error) {
	capItems := 1
	if s.batch {
		capItems = len(s.i64Buf)
		if capItems < 16 {
			capItems = 16
		}
	}
	var outCnt C.size_t
	for {
		s.bBuf = ensureU8(s.bBuf, 2*capItems)
		s.i32Buf = ensureI32(s.i32Buf, 6*capItems)
		s.i64Buf = ensureI64(s.i64Buf, capItems)
		s.f64Buf = ensureF64(s.f64Buf, capItems)
		rc := C.go_kiln_decode_message(
			s.ctx, cBool(s.batch), u8Ptr(data), C.size_t(len(data)),
			u8Ptr(s.bBuf), i32Ptr(s.i32Buf), i64Ptr(s.i64Buf), f64Ptr(s.f64Buf),
			C.size_t(capItems), &outCnt,
		)
		if rc == -2 {
			capItems = int(outCnt)
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode message err=%d", int(rc))
		}
		break
	}
	n := int(outCnt)
	if !s.batch {
		return modelv2.Message{
			FBool:    s.bBuf[0] != 0,
			FInt32:   s.i32Buf[0],
			FInt64:   s.i64Buf[0],
			FFloat64: s.f64Buf[0],
			FString:  spanString(data, uint32(s.i32Buf[2]), uint32(s.i32Buf[3])),
			FBool2:   s.bBuf[1] != 0,
			FInt32_2: s.i32Buf[1],
			FString2: spanString(data, uint32(s.i32Buf[4]), uint32(s.i32Buf[5])),
		}, nil
	}
	out := make([]modelv2.Message, n)
	for i := 0; i < n; i++ {
		out[i] = modelv2.Message{
			FBool:    s.bBuf[2*i] != 0,
			FInt32:   s.i32Buf[6*i+0],
			FInt64:   s.i64Buf[i],
			FFloat64: s.f64Buf[i],
			FString:  spanString(data, uint32(s.i32Buf[6*i+2]), uint32(s.i32Buf[6*i+3])),
			FBool2:   s.bBuf[2*i+1] != 0,
			FInt32_2: s.i32Buf[6*i+1],
			FString2: spanString(data, uint32(s.i32Buf[6*i+4]), uint32(s.i32Buf[6*i+5])),
		}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeDocBuffers(data []byte, isNested bool) (int, error) {
	capDocs := len(s.u32Buf)
	if capDocs < 16 {
		capDocs = 16
	}
	capItems := len(s.i64Buf)
	if capItems < 64 {
		capItems = 64
	}
	var outDocs, outItems C.size_t
	for {
		s.i32Buf = ensureI32(s.i32Buf, 2*capDocs)
		s.u32Buf = ensureU32(s.u32Buf, capDocs)
		s.u32Buf2 = ensureU32(s.u32Buf2, 4*capDocs)
		s.i32Buf2 = ensureI32(s.i32Buf2, capItems)
		s.i64Buf = ensureI64(s.i64Buf, capItems)
		s.u32Buf3 = ensureU32(s.u32Buf3, 2*capItems)
		rc := C.go_kiln_decode_document(
			s.ctx, cBool(isNested), cBool(s.batch), u8Ptr(data), C.size_t(len(data)),
			i32Ptr(s.i32Buf), u32Ptr(s.u32Buf), u32Ptr(s.u32Buf2), C.size_t(capDocs),
			i32Ptr(s.i32Buf2), i64Ptr(s.i64Buf), u32Ptr(s.u32Buf3), C.size_t(capItems),
			&outDocs, &outItems,
		)
		if rc == -2 {
			if int(outDocs) > capDocs {
				capDocs = int(outDocs)
			}
			if int(outItems) > capItems {
				capItems = int(outItems)
			}
			continue
		}
		if rc != 0 {
			return 0, fmt.Errorf("gld-kiln-asm: decode document err=%d", int(rc))
		}
		return int(outDocs), nil
	}
}

func (s *gldKilnAsm) decodeDocument(data []byte) (any, error) {
	nDocs, err := s.decodeDocBuffers(data, false)
	if err != nil {
		return nil, err
	}
	if !s.batch {
		ic := int(s.u32Buf[0])
		items := make([]modelv2.DocumentItem, ic)
		for j := 0; j < ic; j++ {
			items[j] = modelv2.DocumentItem{
				SKU:        spanString(data, s.u32Buf3[2*j], s.u32Buf3[2*j+1]),
				Qty:        s.i32Buf2[j],
				PriceMinor: s.i64Buf[j],
			}
		}
		return modelv2.Document{
			ID:     spanString(data, s.u32Buf2[0], s.u32Buf2[1]),
			Status: s.i32Buf[0],
			Meta: modelv2.DocumentMeta{
				Region:  spanString(data, s.u32Buf2[2], s.u32Buf2[3]),
				Version: s.i32Buf[1],
			},
			Items: items,
		}, nil
	}
	out := make([]modelv2.Document, nDocs)
	ip := 0
	for i := 0; i < nDocs; i++ {
		ic := int(s.u32Buf[i])
		items := make([]modelv2.DocumentItem, ic)
		for j := 0; j < ic; j++ {
			items[j] = modelv2.DocumentItem{
				SKU:        spanString(data, s.u32Buf3[2*ip], s.u32Buf3[2*ip+1]),
				Qty:        s.i32Buf2[ip],
				PriceMinor: s.i64Buf[ip],
			}
			ip++
		}
		out[i] = modelv2.Document{
			ID:     spanString(data, s.u32Buf2[4*i], s.u32Buf2[4*i+1]),
			Status: s.i32Buf[2*i],
			Meta: modelv2.DocumentMeta{
				Region:  spanString(data, s.u32Buf2[4*i+2], s.u32Buf2[4*i+3]),
				Version: s.i32Buf[2*i+1],
			},
			Items: items,
		}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeNested(data []byte) (any, error) {
	nDocs, err := s.decodeDocBuffers(data, true)
	if err != nil {
		return nil, err
	}
	if !s.batch {
		ic := int(s.u32Buf[0])
		items := make([]modelv2.NestedItem, ic)
		for j := 0; j < ic; j++ {
			items[j] = modelv2.NestedItem{
				SKU:        spanString(data, s.u32Buf3[2*j], s.u32Buf3[2*j+1]),
				Qty:        s.i32Buf2[j],
				PriceMinor: s.i64Buf[j],
			}
		}
		return modelv2.NestedRow{
			ID:     spanString(data, s.u32Buf2[0], s.u32Buf2[1]),
			Status: s.i32Buf[0],
			Meta: modelv2.NestedMeta{
				Region:  spanString(data, s.u32Buf2[2], s.u32Buf2[3]),
				Version: s.i32Buf[1],
			},
			Items: items,
		}, nil
	}
	out := make([]modelv2.NestedRow, nDocs)
	ip := 0
	for i := 0; i < nDocs; i++ {
		ic := int(s.u32Buf[i])
		items := make([]modelv2.NestedItem, ic)
		for j := 0; j < ic; j++ {
			items[j] = modelv2.NestedItem{
				SKU:        spanString(data, s.u32Buf3[2*ip], s.u32Buf3[2*ip+1]),
				Qty:        s.i32Buf2[ip],
				PriceMinor: s.i64Buf[ip],
			}
			ip++
		}
		out[i] = modelv2.NestedRow{
			ID:     spanString(data, s.u32Buf2[4*i], s.u32Buf2[4*i+1]),
			Status: s.i32Buf[2*i],
			Meta: modelv2.NestedMeta{
				Region:  spanString(data, s.u32Buf2[4*i+2], s.u32Buf2[4*i+3]),
				Version: s.i32Buf[2*i+1],
			},
			Items: items,
		}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeTelemetry(data []byte) (any, error) {
	capRows := len(s.i64Buf)
	if capRows < 16 {
		capRows = 16
	}
	capTags := len(s.u32Buf4) / 2
	if capTags < 64 {
		capTags = 64
	}
	capVals := len(s.f64Buf)
	if capVals < 64 {
		capVals = 64
	}
	var outRows, outTags, outVals C.size_t
	for {
		s.i64Buf = ensureI64(s.i64Buf, capRows)
		s.u32Buf = ensureU32(s.u32Buf, capRows)
		s.u32Buf2 = ensureU32(s.u32Buf2, capRows)
		s.u32Buf3 = ensureU32(s.u32Buf3, 2*capRows)
		s.u32Buf4 = ensureU32(s.u32Buf4, 2*capTags)
		s.f64Buf = ensureF64(s.f64Buf, capVals)
		rc := C.go_kiln_decode_telemetry(
			s.ctx, cBool(s.batch), u8Ptr(data), C.size_t(len(data)),
			i64Ptr(s.i64Buf), u32Ptr(s.u32Buf), u32Ptr(s.u32Buf2), u32Ptr(s.u32Buf3), C.size_t(capRows),
			u32Ptr(s.u32Buf4), C.size_t(capTags),
			f64Ptr(s.f64Buf), C.size_t(capVals),
			&outRows, &outTags, &outVals,
		)
		if rc == -2 {
			if int(outRows) > capRows {
				capRows = int(outRows)
			}
			if int(outTags) > capTags {
				capTags = int(outTags)
			}
			if int(outVals) > capVals {
				capVals = int(outVals)
			}
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode telemetry err=%d", int(rc))
		}
		break
	}
	n := int(outRows)
	if !s.batch {
		tc := int(s.u32Buf[0])
		vc := int(s.u32Buf2[0])
		tags := make([]string, tc)
		for j := 0; j < tc; j++ {
			tags[j] = spanString(data, s.u32Buf4[2*j], s.u32Buf4[2*j+1])
		}
		vals := make([]float64, vc)
		copy(vals, s.f64Buf[:vc])
		return modelv2.Telemetry{
			Source: spanString(data, s.u32Buf3[0], s.u32Buf3[1]),
			TS:     s.i64Buf[0],
			Tags:   tags,
			Values: vals,
		}, nil
	}
	out := make([]modelv2.Telemetry, n)
	tp, vp := 0, 0
	for i := 0; i < n; i++ {
		tc := int(s.u32Buf[i])
		vc := int(s.u32Buf2[i])
		tags := make([]string, tc)
		for j := 0; j < tc; j++ {
			tags[j] = spanString(data, s.u32Buf4[2*tp], s.u32Buf4[2*tp+1])
			tp++
		}
		vals := make([]float64, vc)
		copy(vals, s.f64Buf[vp:vp+vc])
		vp += vc
		out[i] = modelv2.Telemetry{
			Source: spanString(data, s.u32Buf3[2*i], s.u32Buf3[2*i+1]),
			TS:     s.i64Buf[i],
			Tags:   tags,
			Values: vals,
		}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeStrings(data []byte) (any, error) {
	capRows := len(s.u32Buf)
	if capRows < 16 {
		capRows = 16
	}
	capStrs := len(s.u32Buf2) / 2
	if capStrs < 64 {
		capStrs = 64
	}
	var outRows, outStrs C.size_t
	for {
		s.u32Buf = ensureU32(s.u32Buf, capRows)
		s.u32Buf2 = ensureU32(s.u32Buf2, 2*capStrs)
		rc := C.go_kiln_decode_strings(
			s.ctx, cBool(s.batch), u8Ptr(data), C.size_t(len(data)),
			u32Ptr(s.u32Buf), C.size_t(capRows),
			u32Ptr(s.u32Buf2), C.size_t(capStrs),
			&outRows, &outStrs,
		)
		if rc == -2 {
			if int(outRows) > capRows {
				capRows = int(outRows)
			}
			if int(outStrs) > capStrs {
				capStrs = int(outStrs)
			}
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode strings err=%d", int(rc))
		}
		break
	}
	n := int(outRows)
	if !s.batch {
		ic := int(s.u32Buf[0])
		items := make([]string, ic)
		for j := 0; j < ic; j++ {
			items[j] = spanString(data, s.u32Buf2[2*j], s.u32Buf2[2*j+1])
		}
		return modelv2.Strings{Items: items}, nil
	}
	out := make([]modelv2.Strings, n)
	pos := 0
	for i := 0; i < n; i++ {
		ic := int(s.u32Buf[i])
		items := make([]string, ic)
		for j := 0; j < ic; j++ {
			items[j] = spanString(data, s.u32Buf2[2*pos], s.u32Buf2[2*pos+1])
			pos++
		}
		out[i] = modelv2.Strings{Items: items}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeEvent(data []byte) (any, error) {
	capRows := len(s.i64Buf)
	if capRows < 16 {
		capRows = 16
	}
	capAttrs := len(s.u32Buf3) / 4
	if capAttrs < 64 {
		capAttrs = 64
	}
	var outRows, outAttrs C.size_t
	for {
		s.i64Buf = ensureI64(s.i64Buf, capRows)
		s.u32Buf = ensureU32(s.u32Buf, capRows)
		s.u32Buf2 = ensureU32(s.u32Buf2, 6*capRows)
		s.u32Buf3 = ensureU32(s.u32Buf3, 4*capAttrs)
		rc := C.go_kiln_decode_event(
			s.ctx, cBool(s.batch), u8Ptr(data), C.size_t(len(data)),
			i64Ptr(s.i64Buf), u32Ptr(s.u32Buf), u32Ptr(s.u32Buf2), C.size_t(capRows),
			u32Ptr(s.u32Buf3), C.size_t(capAttrs),
			&outRows, &outAttrs,
		)
		if rc == -2 {
			if int(outRows) > capRows {
				capRows = int(outRows)
			}
			if int(outAttrs) > capAttrs {
				capAttrs = int(outAttrs)
			}
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode event err=%d", int(rc))
		}
		break
	}
	n := int(outRows)
	if !s.batch {
		ac := int(s.u32Buf[0])
		attrs := make([]modelv2.EventAttr, ac)
		for j := 0; j < ac; j++ {
			attrs[j] = modelv2.EventAttr{
				Key:   spanString(data, s.u32Buf3[4*j], s.u32Buf3[4*j+1]),
				Value: spanString(data, s.u32Buf3[4*j+2], s.u32Buf3[4*j+3]),
			}
		}
		return modelv2.Event{
			EventID:    spanString(data, s.u32Buf2[0], s.u32Buf2[1]),
			EventType:  spanString(data, s.u32Buf2[2], s.u32Buf2[3]),
			OccurredAt: s.i64Buf[0],
			Producer:   spanString(data, s.u32Buf2[4], s.u32Buf2[5]),
			Attrs:      attrs,
		}, nil
	}
	out := make([]modelv2.Event, n)
	ap := 0
	for i := 0; i < n; i++ {
		ac := int(s.u32Buf[i])
		attrs := make([]modelv2.EventAttr, ac)
		for j := 0; j < ac; j++ {
			attrs[j] = modelv2.EventAttr{
				Key:   spanString(data, s.u32Buf3[4*ap], s.u32Buf3[4*ap+1]),
				Value: spanString(data, s.u32Buf3[4*ap+2], s.u32Buf3[4*ap+3]),
			}
			ap++
		}
		out[i] = modelv2.Event{
			EventID:    spanString(data, s.u32Buf2[6*i+0], s.u32Buf2[6*i+1]),
			EventType:  spanString(data, s.u32Buf2[6*i+2], s.u32Buf2[6*i+3]),
			OccurredAt: s.i64Buf[i],
			Producer:   spanString(data, s.u32Buf2[6*i+4], s.u32Buf2[6*i+5]),
			Attrs:      attrs,
		}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeTable(data []byte) (any, error) {
	capRows := len(s.f64Buf) / 16
	if capRows < 16 {
		capRows = 16
	}
	var outRows C.size_t
	for {
		s.f64Buf = ensureF64(s.f64Buf, 16*capRows)
		s.i64Buf = ensureI64(s.i64Buf, 4*capRows)
		s.u32Buf = ensureU32(s.u32Buf, 4*capRows)
		rc := C.go_kiln_decode_table(
			s.ctx, u8Ptr(data), C.size_t(len(data)),
			f64Ptr(s.f64Buf), i64Ptr(s.i64Buf), u32Ptr(s.u32Buf),
			C.size_t(capRows), &outRows,
		)
		if rc == -2 {
			capRows = int(outRows)
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode table err=%d", int(rc))
		}
		break
	}
	n := int(outRows)
	f := s.f64Buf
	iv := s.i64Buf
	sp := s.u32Buf
	rows := make([]modelv2.TableRow, n)
	for r := 0; r < n; r++ {
		rows[r] = modelv2.TableRow{
			FFloat0:  f[0*n+r],
			FFloat1:  f[1*n+r],
			FFloat2:  f[2*n+r],
			FFloat3:  f[3*n+r],
			FFloat4:  f[4*n+r],
			FFloat5:  f[5*n+r],
			FFloat6:  f[6*n+r],
			FFloat7:  f[7*n+r],
			FFloat8:  f[8*n+r],
			FFloat9:  f[9*n+r],
			FFloat10: f[10*n+r],
			FFloat11: f[11*n+r],
			FFloat12: f[12*n+r],
			FFloat13: f[13*n+r],
			FFloat14: f[14*n+r],
			FFloat15: f[15*n+r],
			FInt0:    iv[0*n+r],
			FInt1:    iv[1*n+r],
			FInt2:    iv[2*n+r],
			FInt3:    iv[3*n+r],
			FStr0:    spanString(data, sp[4*r+0], sp[4*r+1]),
			FStr1:    spanString(data, sp[4*r+2], sp[4*r+3]),
		}
	}
	if !s.batch {
		if n != 1 {
			return nil, fmt.Errorf("gld-kiln-asm: expected 1 table row, got %d", n)
		}
		return rows[0], nil
	}
	return rows, nil
}

func (s *gldKilnAsm) decodeTableProject(data []byte) (any, error) {
	capRows := len(s.f64Buf)
	if capRows < 16 {
		capRows = 16
	}
	var outRows C.size_t
	for {
		s.f64Buf = ensureF64(s.f64Buf, capRows)
		rc := C.go_kiln_decode_table_project(
			s.ctx, u8Ptr(data), C.size_t(len(data)),
			f64Ptr(s.f64Buf), C.size_t(capRows), &outRows,
		)
		if rc == -2 {
			capRows = int(outRows)
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode table_project err=%d", int(rc))
		}
		break
	}
	n := int(outRows)
	out := make([]float64, n)
	copy(out, s.f64Buf[:n])
	return out, nil
}

func (s *gldKilnAsm) decodeSignal(data []byte) (any, error) {
	capRows := len(s.u32Buf)
	if capRows < 16 {
		capRows = 16
	}
	capLegs := len(s.i64Buf2)
	if capLegs < 64 {
		capLegs = 64
	}
	var outRows, outLegs C.size_t
	for {
		s.i64Buf = ensureI64(s.i64Buf, 3*capRows)
		s.i32Buf = ensureI32(s.i32Buf, 2*capRows)
		s.u32Buf = ensureU32(s.u32Buf, capRows)
		s.u32Buf2 = ensureU32(s.u32Buf2, 4*capRows)
		s.i64Buf2 = ensureI64(s.i64Buf2, capLegs)
		s.i32Buf2 = ensureI32(s.i32Buf2, 2*capLegs)
		rc := C.go_kiln_decode_signal(
			s.ctx, cBool(s.batch), u8Ptr(data), C.size_t(len(data)),
			i64Ptr(s.i64Buf), i32Ptr(s.i32Buf), u32Ptr(s.u32Buf), u32Ptr(s.u32Buf2), C.size_t(capRows),
			i64Ptr(s.i64Buf2), i32Ptr(s.i32Buf2), C.size_t(capLegs),
			&outRows, &outLegs,
		)
		if rc == -2 {
			if int(outRows) > capRows {
				capRows = int(outRows)
			}
			if int(outLegs) > capLegs {
				capLegs = int(outLegs)
			}
			continue
		}
		if rc != 0 {
			return nil, fmt.Errorf("gld-kiln-asm: decode signal err=%d", int(rc))
		}
		break
	}
	n := int(outRows)
	if !s.batch {
		lc := int(s.u32Buf[0])
		legs := make([]modelv2.SignalLeg, lc)
		for j := 0; j < lc; j++ {
			legs[j] = modelv2.SignalLeg{
				LegID:  s.i64Buf2[j],
				LegQty: s.i32Buf2[2*j+0],
				LegPad: s.i32Buf2[2*j+1],
			}
		}
		return modelv2.Signal{
			Seq:           s.i64Buf[0],
			TS:            s.i64Buf[1],
			PriceMantissa: s.i64Buf[2],
			Qty:           s.i32Buf[0],
			Flags:         s.i32Buf[1],
			Symbol:        spanString(data, s.u32Buf2[0], s.u32Buf2[1]),
			Venue:         spanString(data, s.u32Buf2[2], s.u32Buf2[3]),
			Legs:          legs,
		}, nil
	}
	out := make([]modelv2.Signal, n)
	lp := 0
	for i := 0; i < n; i++ {
		lc := int(s.u32Buf[i])
		legs := make([]modelv2.SignalLeg, lc)
		for j := 0; j < lc; j++ {
			legs[j] = modelv2.SignalLeg{
				LegID:  s.i64Buf2[lp],
				LegQty: s.i32Buf2[2*lp+0],
				LegPad: s.i32Buf2[2*lp+1],
			}
			lp++
		}
		out[i] = modelv2.Signal{
			Seq:           s.i64Buf[3*i+0],
			TS:            s.i64Buf[3*i+1],
			PriceMantissa: s.i64Buf[3*i+2],
			Qty:           s.i32Buf[2*i+0],
			Flags:         s.i32Buf[2*i+1],
			Symbol:        spanString(data, s.u32Buf2[4*i+0], s.u32Buf2[4*i+1]),
			Venue:         spanString(data, s.u32Buf2[4*i+2], s.u32Buf2[4*i+3]),
			Legs:          legs,
		}
	}
	return out, nil
}

func (s *gldKilnAsm) decodeTensor(data []byte, borrow bool) (any, error) {
	var rows, cols C.int32_t
	var off, nbytes C.size_t
	rc := C.go_kiln_decode_tensor_meta(
		s.ctx, u8Ptr(data), C.size_t(len(data)),
		&rows, &cols, &off, &nbytes,
	)
	runtime.KeepAlive(s)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: decode tensor err=%d", int(rc))
	}
	if borrow {
		return tensorView{
			Rows:    int32(rows),
			Cols:    int32(cols),
			Payload: data[int(off) : int(off)+int(nbytes)],
		}, nil
	}
	return modelv2.Tensor{
		Rows:   int32(rows),
		Cols:   int32(cols),
		Values: copyF32FromWire(data, off, nbytes),
	}, nil
}

func (s *gldKilnAsm) decodePrompt(data []byte) (any, error) {
	var batch, seq C.int32_t
	var offs [3]C.size_t
	var nbytes C.size_t
	rc := C.go_kiln_decode_prompt_meta(
		s.ctx, u8Ptr(data), C.size_t(len(data)),
		&batch, &seq, &offs[0], &nbytes,
	)
	runtime.KeepAlive(s)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: decode prompt err=%d", int(rc))
	}
	return modelv2.Prompt{
		Batch:         int32(batch),
		Seq:           int32(seq),
		InputIDs:      copyI64FromWire(data, offs[0], nbytes),
		AttentionMask: copyI64FromWire(data, offs[1], nbytes),
		PositionIDs:   copyI64FromWire(data, offs[2], nbytes),
	}, nil
}

func (s *gldKilnAsm) decodeShard(data []byte) (any, error) {
	var vocab, hidden, ffn C.int32_t
	var offs [4]C.size_t
	var nbytes [4]C.size_t
	rc := C.go_kiln_decode_shard_meta(
		s.ctx, u8Ptr(data), C.size_t(len(data)),
		&vocab, &hidden, &ffn, &offs[0], &nbytes[0],
	)
	runtime.KeepAlive(s)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: decode shard err=%d", int(rc))
	}
	return modelv2.Shard{
		Vocab:     int32(vocab),
		Hidden:    int32(hidden),
		FFN:       int32(ffn),
		TokEmb:    copyF32FromWire(data, offs[0], nbytes[0]),
		Attn:      copyF32FromWire(data, offs[1], nbytes[1]),
		FFNWeight: copyF32FromWire(data, offs[2], nbytes[2]),
		Norm:      copyF32FromWire(data, offs[3], nbytes[3]),
	}, nil
}

func (s *gldKilnAsm) decodeRequest(data []byte) (any, error) {
	var reqID C.int64_t
	var modelOff, modelLen C.size_t
	var temp C.float
	var batch, seq C.int32_t
	var offs [3]C.size_t
	var nbytes C.size_t
	rc := C.go_kiln_decode_request_meta(
		s.ctx, u8Ptr(data), C.size_t(len(data)),
		&reqID, &modelOff, &modelLen, &temp, &batch, &seq, &offs[0], &nbytes,
	)
	runtime.KeepAlive(s)
	if rc != 0 {
		return nil, fmt.Errorf("gld-kiln-asm: decode request err=%d", int(rc))
	}
	return modelv2.Request{
		RequestID:   int64(reqID),
		Model:       spanString(data, uint32(modelOff), uint32(modelLen)),
		Temperature: float32(temp),
		Inputs: modelv2.Prompt{
			Batch:         int32(batch),
			Seq:           int32(seq),
			InputIDs:      copyI64FromWire(data, offs[0], nbytes),
			AttentionMask: copyI64FromWire(data, offs[1], nbytes),
			PositionIDs:   copyI64FromWire(data, offs[2], nbytes),
		},
	}, nil
}
