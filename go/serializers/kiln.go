package serializers

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"reflect"

	"github.com/leo-gan/gld-kiln-go"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// gldKiln is Kiln wire v2 (positional, little-endian, no field names).
// Schemas are package-level. Prepare converts values to maps (untimed).
// The timed path is Append into one reused buffer and Decode.
// tensor_view decode returns a byte view of the float payload and does not copy it.
// ToDomain rebuilds domain structs. Stream is adapted: the API is byte slices.
// https://github.com/leo-gan/gld-kiln-go
type gldKiln struct {
	schema *kiln.Schema
	native any
	buf    []byte
	writer *kiln.Writer
	encFn  func() ([]byte, error)
	decFn  func([]byte) (any, error)
	direct bool
	proto  any
	fxName string
	batch  bool
	borrow bool
}

// tensorView is the borrowed tensor_view decode. Payload aliases the encoded bytes.
type tensorView struct {
	Rows    int32
	Cols    int32
	Payload []byte
}

func newGldKiln() *gldKiln { return &gldKiln{writer: kiln.NewWriter(4096)} }

func (s *gldKiln) Name() string { return "gld-kiln" }

func (s *gldKiln) Version() string        { return kiln.Version }
func (s *gldKiln) StreamMode() StreamMode { return StreamAdapted }
func (s *gldKiln) NativeKind() NativeKind { return NativeSchema }
func (s *gldKiln) Supports(n string) bool {
	switch n {
	case "message", "document", "telemetry", "strings", "event",
		"tensor", "tensor_view", "prompt", "shard", "request":
		return true
	default:
		return false
	}
}

func (s *gldKiln) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.fxName = fx.Name
	s.batch = isSlice(fx.Value)
	s.borrow = !s.batch && fx.Name == "tensor_view"
	s.direct = false
	s.encFn = nil
	s.decFn = nil
	if s.writer == nil {
		s.writer = kiln.NewWriter(4096)
	}
	if s.bindDirectSuite(fx) {
		s.direct = true
		return nil
	}
	sch := kilnSchemaFor(fx.Name, s.batch)
	if sch == nil {
		return fmt.Errorf("gld-kiln: no schema for %s", fx.Name)
	}
	s.schema = sch
	native, err := toKilnNative(fx.Value)
	if err != nil {
		return err
	}
	s.native = native
	if s.buf == nil {
		s.buf = make([]byte, 0, 4096)
	}
	return nil
}

func (s *gldKiln) SerializeBytes(_ model.Fixture) ([]byte, error) {
	if s.direct {
		return s.encFn()
	}
	var err error
	s.buf, err = kiln.Append(s.buf[:0], s.schema, s.native)
	if err != nil {
		return nil, err
	}
	return s.buf, nil
}

func (s *gldKiln) DeserializeBytes(buf []byte) (any, error) {
	if s.direct {
		return s.decFn(buf)
	}
	if s.borrow {
		return borrowTensor(buf)
	}
	return kiln.Decode(s.schema, buf, kiln.Options{})
}

func (s *gldKiln) ToDomain(decoded any) (any, error) {
	if s.direct {
		return decoded, nil
	}
	return fromKilnNative(s.fxName, s.batch, decoded, s.proto)
}

func (s *gldKiln) bindDirectSuite(fx model.Fixture) bool {
	w := s.writer
	switch v := fx.Value.(type) {
	case modelv2.Message:
		row := v
		s.encFn = func() ([]byte, error) {
			w.Reset(34 + len(row.FString) + len(row.FString2))
			if err := writeKilnMessage(w, &row); err != nil {
				return nil, err
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			var out modelv2.Message
			if err := readKilnMessage(&r, &out); err != nil {
				return nil, err
			}
			return out, r.Finish()
		}
		return true
	case []modelv2.Message:
		rows := v
		s.encFn = func() ([]byte, error) {
			need := 4
			for i := range rows {
				need += 34 + len(rows[i].FString) + len(rows[i].FString2)
			}
			w.Reset(need)
			if err := w.PutCount(len(rows)); err != nil {
				return nil, err
			}
			for i := range rows {
				if err := writeKilnMessage(w, &rows[i]); err != nil {
					return nil, err
				}
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			n, err := r.Count(34)
			if err != nil {
				return nil, err
			}
			out := make([]modelv2.Message, n)
			for i := range out {
				if err := readKilnMessage(&r, &out[i]); err != nil {
					return nil, err
				}
			}
			return out, r.Finish()
		}
		return true
	case modelv2.Document:
		row := v
		s.encFn = func() ([]byte, error) {
			w.Reset(sizeKilnDocument(&row))
			if err := writeKilnDocument(w, &row); err != nil {
				return nil, err
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			var out modelv2.Document
			if err := readKilnDocument(&r, &out); err != nil {
				return nil, err
			}
			return out, r.Finish()
		}
		return true
	case []modelv2.Document:
		rows := v
		s.encFn = func() ([]byte, error) {
			need := 4
			for i := range rows {
				need += sizeKilnDocument(&rows[i])
			}
			w.Reset(need)
			if err := w.PutCount(len(rows)); err != nil {
				return nil, err
			}
			for i := range rows {
				if err := writeKilnDocument(w, &rows[i]); err != nil {
					return nil, err
				}
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			n, err := r.Count(20)
			if err != nil {
				return nil, err
			}
			out := make([]modelv2.Document, n)
			for i := range out {
				if err := readKilnDocument(&r, &out[i]); err != nil {
					return nil, err
				}
			}
			return out, r.Finish()
		}
		return true
	case modelv2.Telemetry:
		row := v
		s.encFn = func() ([]byte, error) {
			w.Reset(sizeKilnTelemetry(&row))
			if err := writeKilnTelemetry(w, &row); err != nil {
				return nil, err
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			var out modelv2.Telemetry
			if err := readKilnTelemetry(&r, &out); err != nil {
				return nil, err
			}
			return out, r.Finish()
		}
		return true
	case []modelv2.Telemetry:
		rows := v
		s.encFn = func() ([]byte, error) {
			need := 4
			for i := range rows {
				need += sizeKilnTelemetry(&rows[i])
			}
			w.Reset(need)
			if err := w.PutCount(len(rows)); err != nil {
				return nil, err
			}
			for i := range rows {
				if err := writeKilnTelemetry(w, &rows[i]); err != nil {
					return nil, err
				}
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			n, err := r.Count(20)
			if err != nil {
				return nil, err
			}
			out := make([]modelv2.Telemetry, n)
			for i := range out {
				if err := readKilnTelemetry(&r, &out[i]); err != nil {
					return nil, err
				}
			}
			return out, r.Finish()
		}
		return true
	case modelv2.Strings:
		row := v
		s.encFn = func() ([]byte, error) {
			w.Reset(sizeKilnStrings(&row))
			if err := writeKilnStrings(w, &row); err != nil {
				return nil, err
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			var out modelv2.Strings
			if err := readKilnStrings(&r, &out); err != nil {
				return nil, err
			}
			return out, r.Finish()
		}
		return true
	case []modelv2.Strings:
		rows := v
		s.encFn = func() ([]byte, error) {
			need := 4
			for i := range rows {
				need += sizeKilnStrings(&rows[i])
			}
			w.Reset(need)
			if err := w.PutCount(len(rows)); err != nil {
				return nil, err
			}
			for i := range rows {
				if err := writeKilnStrings(w, &rows[i]); err != nil {
					return nil, err
				}
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			n, err := r.Count(4)
			if err != nil {
				return nil, err
			}
			out := make([]modelv2.Strings, n)
			for i := range out {
				if err := readKilnStrings(&r, &out[i]); err != nil {
					return nil, err
				}
			}
			return out, r.Finish()
		}
		return true
	case modelv2.Event:
		row := v
		s.encFn = func() ([]byte, error) {
			w.Reset(sizeKilnEvent(&row))
			if err := writeKilnEvent(w, &row); err != nil {
				return nil, err
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			var out modelv2.Event
			if err := readKilnEvent(&r, &out); err != nil {
				return nil, err
			}
			return out, r.Finish()
		}
		return true
	case []modelv2.Event:
		rows := v
		s.encFn = func() ([]byte, error) {
			need := 4
			for i := range rows {
				need += sizeKilnEvent(&rows[i])
			}
			w.Reset(need)
			if err := w.PutCount(len(rows)); err != nil {
				return nil, err
			}
			for i := range rows {
				if err := writeKilnEvent(w, &rows[i]); err != nil {
					return nil, err
				}
			}
			return w.Bytes(), nil
		}
		s.decFn = func(buf []byte) (any, error) {
			r := kiln.NewReader(buf, kiln.Options{})
			n, err := r.Count(24)
			if err != nil {
				return nil, err
			}
			out := make([]modelv2.Event, n)
			for i := range out {
				if err := readKilnEvent(&r, &out[i]); err != nil {
					return nil, err
				}
			}
			return out, r.Finish()
		}
		return true
	default:
		return false
	}
}

func sizeKilnDocument(d *modelv2.Document) int {
	n := 20 + len(d.ID) + len(d.Meta.Region)
	for i := range d.Items {
		n += 16 + len(d.Items[i].SKU)
	}
	return n
}

func sizeKilnTelemetry(t *modelv2.Telemetry) int {
	n := 20 + len(t.Source) + len(t.Values)*8
	for i := range t.Tags {
		n += 4 + len(t.Tags[i])
	}
	return n
}

func sizeKilnStrings(s *modelv2.Strings) int {
	n := 4
	for i := range s.Items {
		n += 4 + len(s.Items[i])
	}
	return n
}

func sizeKilnEvent(e *modelv2.Event) int {
	n := 24 + len(e.EventID) + len(e.EventType) + len(e.Producer)
	for i := range e.Attrs {
		n += 8 + len(e.Attrs[i].Key) + len(e.Attrs[i].Value)
	}
	return n
}

func writeKilnMessage(w *kiln.Writer, m *modelv2.Message) error {
	w.PutBool(m.FBool)
	w.PutI32(m.FInt32)
	w.PutI64(m.FInt64)
	w.PutF64(m.FFloat64)
	if err := w.PutString(m.FString); err != nil {
		return err
	}
	w.PutBool(m.FBool2)
	w.PutI32(m.FInt32_2)
	return w.PutString(m.FString2)
}

func readKilnMessage(r *kiln.Reader, out *modelv2.Message) error {
	var err error
	if out.FBool, err = r.Bool(); err != nil {
		return err
	}
	if out.FInt32, err = r.I32(); err != nil {
		return err
	}
	if out.FInt64, err = r.I64(); err != nil {
		return err
	}
	if out.FFloat64, err = r.F64(); err != nil {
		return err
	}
	if out.FString, err = r.String(); err != nil {
		return err
	}
	if out.FBool2, err = r.Bool(); err != nil {
		return err
	}
	if out.FInt32_2, err = r.I32(); err != nil {
		return err
	}
	out.FString2, err = r.String()
	return err
}

func writeKilnDocument(w *kiln.Writer, d *modelv2.Document) error {
	if err := w.PutString(d.ID); err != nil {
		return err
	}
	w.PutI32(d.Status)
	if err := w.PutString(d.Meta.Region); err != nil {
		return err
	}
	w.PutI32(d.Meta.Version)
	if err := w.PutCount(len(d.Items)); err != nil {
		return err
	}
	for i := range d.Items {
		if err := w.PutString(d.Items[i].SKU); err != nil {
			return err
		}
		w.PutI32(d.Items[i].Qty)
		w.PutI64(d.Items[i].PriceMinor)
	}
	return nil
}

func readKilnDocument(r *kiln.Reader, out *modelv2.Document) error {
	var err error
	if out.ID, err = r.String(); err != nil {
		return err
	}
	if out.Status, err = r.I32(); err != nil {
		return err
	}
	if out.Meta.Region, err = r.String(); err != nil {
		return err
	}
	if out.Meta.Version, err = r.I32(); err != nil {
		return err
	}
	n, err := r.Count(16)
	if err != nil {
		return err
	}
	items := make([]modelv2.DocumentItem, n)
	for i := range items {
		if items[i].SKU, err = r.String(); err != nil {
			return err
		}
		if items[i].Qty, err = r.I32(); err != nil {
			return err
		}
		if items[i].PriceMinor, err = r.I64(); err != nil {
			return err
		}
	}
	out.Items = items
	return nil
}

func writeKilnTelemetry(w *kiln.Writer, t *modelv2.Telemetry) error {
	if err := w.PutString(t.Source); err != nil {
		return err
	}
	w.PutI64(t.TS)
	if err := w.PutCount(len(t.Tags)); err != nil {
		return err
	}
	for i := range t.Tags {
		if err := w.PutString(t.Tags[i]); err != nil {
			return err
		}
	}
	return w.PutF64s(t.Values)
}

func readKilnTelemetry(r *kiln.Reader, out *modelv2.Telemetry) error {
	var err error
	if out.Source, err = r.String(); err != nil {
		return err
	}
	if out.TS, err = r.I64(); err != nil {
		return err
	}
	nt, err := r.Count(4)
	if err != nil {
		return err
	}
	tags := make([]string, nt)
	for i := range tags {
		if tags[i], err = r.String(); err != nil {
			return err
		}
	}
	out.Tags = tags
	out.Values, err = r.F64s()
	return err
}

func writeKilnStrings(w *kiln.Writer, s *modelv2.Strings) error {
	if err := w.PutCount(len(s.Items)); err != nil {
		return err
	}
	for i := range s.Items {
		if err := w.PutString(s.Items[i]); err != nil {
			return err
		}
	}
	return nil
}

func readKilnStrings(r *kiln.Reader, out *modelv2.Strings) error {
	n, err := r.Count(4)
	if err != nil {
		return err
	}
	items := make([]string, n)
	for i := range items {
		if items[i], err = r.String(); err != nil {
			return err
		}
	}
	out.Items = items
	return nil
}

func writeKilnEvent(w *kiln.Writer, e *modelv2.Event) error {
	if err := w.PutString(e.EventID); err != nil {
		return err
	}
	if err := w.PutString(e.EventType); err != nil {
		return err
	}
	w.PutI64(e.OccurredAt)
	if err := w.PutString(e.Producer); err != nil {
		return err
	}
	if err := w.PutCount(len(e.Attrs)); err != nil {
		return err
	}
	for i := range e.Attrs {
		if err := w.PutString(e.Attrs[i].Key); err != nil {
			return err
		}
		if err := w.PutString(e.Attrs[i].Value); err != nil {
			return err
		}
	}
	return nil
}

func readKilnEvent(r *kiln.Reader, out *modelv2.Event) error {
	var err error
	if out.EventID, err = r.String(); err != nil {
		return err
	}
	if out.EventType, err = r.String(); err != nil {
		return err
	}
	if out.OccurredAt, err = r.I64(); err != nil {
		return err
	}
	if out.Producer, err = r.String(); err != nil {
		return err
	}
	n, err := r.Count(8)
	if err != nil {
		return err
	}
	attrs := make([]modelv2.EventAttr, n)
	for i := range attrs {
		if attrs[i].Key, err = r.String(); err != nil {
			return err
		}
		if attrs[i].Value, err = r.String(); err != nil {
			return err
		}
	}
	out.Attrs = attrs
	return nil
}

func (s *gldKiln) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *gldKiln) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

var (
	kilnBool = kiln.Prim(kiln.KindBool)
	kilnI32  = kiln.Prim(kiln.KindI32)
	kilnI64  = kiln.Prim(kiln.KindI64)
	kilnF32  = kiln.Prim(kiln.KindF32)
	kilnF64  = kiln.Prim(kiln.KindF64)
	kilnStr  = kiln.Prim(kiln.KindStr)

	kilnSchMessage = kiln.StructOf(
		kiln.Field{Name: "f_bool", Type: kilnBool},
		kiln.Field{Name: "f_int32", Type: kilnI32},
		kiln.Field{Name: "f_int64", Type: kilnI64},
		kiln.Field{Name: "f_float64", Type: kilnF64},
		kiln.Field{Name: "f_string", Type: kilnStr},
		kiln.Field{Name: "f_bool_2", Type: kilnBool},
		kiln.Field{Name: "f_int32_2", Type: kilnI32},
		kiln.Field{Name: "f_string_2", Type: kilnStr},
	)
	kilnSchDocument = kiln.StructOf(
		kiln.Field{Name: "id", Type: kilnStr},
		kiln.Field{Name: "status", Type: kilnI32},
		kiln.Field{Name: "meta", Type: kiln.StructOf(
			kiln.Field{Name: "region", Type: kilnStr},
			kiln.Field{Name: "version", Type: kilnI32},
		)},
		kiln.Field{Name: "items", Type: kiln.ListOf(kiln.StructOf(
			kiln.Field{Name: "sku", Type: kilnStr},
			kiln.Field{Name: "qty", Type: kilnI32},
			kiln.Field{Name: "price_minor", Type: kilnI64},
		))},
	)
	kilnSchTelemetry = kiln.StructOf(
		kiln.Field{Name: "source", Type: kilnStr},
		kiln.Field{Name: "ts", Type: kilnI64},
		kiln.Field{Name: "tags", Type: kiln.ListOf(kilnStr)},
		kiln.Field{Name: "values", Type: kiln.ListOf(kilnF64)},
	)
	kilnSchStrings = kiln.StructOf(
		kiln.Field{Name: "items", Type: kiln.ListOf(kilnStr)},
	)
	kilnSchEvent = kiln.StructOf(
		kiln.Field{Name: "event_id", Type: kilnStr},
		kiln.Field{Name: "event_type", Type: kilnStr},
		kiln.Field{Name: "occurred_at", Type: kilnI64},
		kiln.Field{Name: "producer", Type: kilnStr},
		kiln.Field{Name: "attrs", Type: kiln.ListOf(kiln.StructOf(
			kiln.Field{Name: "key", Type: kilnStr},
			kiln.Field{Name: "value", Type: kilnStr},
		))},
	)

	kilnSchMessageList   = kiln.ListOf(kilnSchMessage)
	kilnSchDocumentList  = kiln.ListOf(kilnSchDocument)
	kilnSchTelemetryList = kiln.ListOf(kilnSchTelemetry)
	kilnSchStringsList   = kiln.ListOf(kilnSchStrings)
	kilnSchEventList     = kiln.ListOf(kilnSchEvent)

	// Same field order as Mojo TensorValue, PromptValue, ShardValue, RequestValue.
	kilnSchTensor = kiln.StructOf(
		kiln.Field{Name: "rows", Type: kilnI32},
		kiln.Field{Name: "cols", Type: kilnI32},
		kiln.Field{Name: "values", Type: kiln.ListOf(kilnF32)},
	)
	kilnSchPrompt = kiln.StructOf(
		kiln.Field{Name: "batch", Type: kilnI32},
		kiln.Field{Name: "seq", Type: kilnI32},
		kiln.Field{Name: "input_ids", Type: kiln.ListOf(kilnI64)},
		kiln.Field{Name: "attention_mask", Type: kiln.ListOf(kilnI64)},
		kiln.Field{Name: "position_ids", Type: kiln.ListOf(kilnI64)},
	)
	kilnSchShard = kiln.StructOf(
		kiln.Field{Name: "vocab", Type: kilnI32},
		kiln.Field{Name: "hidden", Type: kilnI32},
		kiln.Field{Name: "ffn", Type: kilnI32},
		kiln.Field{Name: "tok_emb", Type: kiln.ListOf(kilnF32)},
		kiln.Field{Name: "attn", Type: kiln.ListOf(kilnF32)},
		kiln.Field{Name: "ffn_weight", Type: kiln.ListOf(kilnF32)},
		kiln.Field{Name: "norm", Type: kiln.ListOf(kilnF32)},
	)
	kilnSchRequest = kiln.StructOf(
		kiln.Field{Name: "request_id", Type: kilnI64},
		kiln.Field{Name: "model", Type: kilnStr},
		kiln.Field{Name: "temperature", Type: kilnF32},
		kiln.Field{Name: "inputs", Type: kilnSchPrompt},
	)
)

func kilnSchemaFor(name string, batch bool) *kiln.Schema {
	switch name {
	case "message":
		if batch {
			return kilnSchMessageList
		}
		return kilnSchMessage
	case "document":
		if batch {
			return kilnSchDocumentList
		}
		return kilnSchDocument
	case "telemetry":
		if batch {
			return kilnSchTelemetryList
		}
		return kilnSchTelemetry
	case "strings":
		if batch {
			return kilnSchStringsList
		}
		return kilnSchStrings
	case "event":
		if batch {
			return kilnSchEventList
		}
		return kilnSchEvent
	case "tensor", "tensor_view":
		return kilnSchTensor
	case "prompt":
		return kilnSchPrompt
	case "shard":
		return kilnSchShard
	case "request":
		return kilnSchRequest
	default:
		return nil
	}
}

// borrowTensor reads rows, cols, and a view of the float payload. It does not copy.
func borrowTensor(buf []byte) (tensorView, error) {
	rows, rest, err := kiln.TakeI32(buf)
	if err != nil {
		return tensorView{}, err
	}
	cols, rest, err := kiln.TakeI32(rest)
	if err != nil {
		return tensorView{}, err
	}
	n, rest, err := kiln.TakeU32(rest)
	if err != nil {
		return tensorView{}, err
	}
	if uint64(n)*4 != uint64(len(rest)) {
		return tensorView{}, fmt.Errorf("gld-kiln: tensor_view length")
	}
	return tensorView{Rows: rows, Cols: cols, Payload: rest}, nil
}

func tensorFromView(v tensorView) (modelv2.Tensor, error) {
	n := len(v.Payload) / 4
	vals := make([]float32, n)
	for i := range vals {
		vals[i] = math.Float32frombits(binary.LittleEndian.Uint32(v.Payload[i*4:]))
	}
	return modelv2.Tensor{Rows: v.Rows, Cols: v.Cols, Values: vals}, nil
}

func toKilnNative(v any) (any, error) {
	if v == nil {
		return nil, fmt.Errorf("gld-kiln: nil value")
	}
	rv := reflect.ValueOf(v)
	if rv.Kind() == reflect.Slice {
		out := make([]any, rv.Len())
		for i := 0; i < rv.Len(); i++ {
			n, err := toKilnNative(rv.Index(i).Interface())
			if err != nil {
				return nil, err
			}
			out[i] = n
		}
		return out, nil
	}
	switch t := v.(type) {
	case modelv2.Message:
		return map[string]any{
			"f_bool": t.FBool, "f_int32": t.FInt32, "f_int64": t.FInt64,
			"f_float64": t.FFloat64, "f_string": t.FString, "f_bool_2": t.FBool2,
			"f_int32_2": t.FInt32_2, "f_string_2": t.FString2,
		}, nil
	case modelv2.Document:
		items := make([]any, len(t.Items))
		for i, it := range t.Items {
			items[i] = map[string]any{
				"sku": it.SKU, "qty": it.Qty, "price_minor": it.PriceMinor,
			}
		}
		return map[string]any{
			"id": t.ID, "status": t.Status,
			"meta":  map[string]any{"region": t.Meta.Region, "version": t.Meta.Version},
			"items": items,
		}, nil
	case modelv2.Telemetry:
		tags := make([]any, len(t.Tags))
		for i, x := range t.Tags {
			tags[i] = x
		}
		return map[string]any{
			"source": t.Source, "ts": t.TS, "tags": tags, "values": t.Values,
		}, nil
	case modelv2.Strings:
		items := make([]any, len(t.Items))
		for i, x := range t.Items {
			items[i] = x
		}
		return map[string]any{"items": items}, nil
	case modelv2.Event:
		attrs := make([]any, len(t.Attrs))
		for i, a := range t.Attrs {
			attrs[i] = map[string]any{"key": a.Key, "value": a.Value}
		}
		return map[string]any{
			"event_id": t.EventID, "event_type": t.EventType,
			"occurred_at": t.OccurredAt, "producer": t.Producer, "attrs": attrs,
		}, nil
	case modelv2.Tensor:
		return map[string]any{
			"rows": t.Rows, "cols": t.Cols, "values": t.Values,
		}, nil
	case modelv2.Prompt:
		return kilnPromptMap(t), nil
	case modelv2.Shard:
		return map[string]any{
			"vocab": t.Vocab, "hidden": t.Hidden, "ffn": t.FFN,
			"tok_emb": t.TokEmb, "attn": t.Attn, "ffn_weight": t.FFNWeight, "norm": t.Norm,
		}, nil
	case modelv2.Request:
		return map[string]any{
			"request_id": t.RequestID, "model": t.Model, "temperature": t.Temperature,
			"inputs": kilnPromptMap(t.Inputs),
		}, nil
	default:
		return nil, fmt.Errorf("gld-kiln: unsupported type %T", v)
	}
}

func kilnPromptMap(p modelv2.Prompt) map[string]any {
	return map[string]any{
		"batch": p.Batch, "seq": p.Seq,
		"input_ids":      p.InputIDs,
		"attention_mask": p.AttentionMask,
		"position_ids":   p.PositionIDs,
	}
}

func fromKilnNative(typeID string, batch bool, decoded, proto any) (any, error) {
	if view, ok := decoded.(tensorView); ok {
		return tensorFromView(view)
	}
	if batch {
		arr, ok := decoded.([]any)
		if !ok {
			return nil, fmt.Errorf("gld-kiln: expected []any batch, got %T", decoded)
		}
		pt := reflect.TypeOf(proto)
		if pt == nil || pt.Kind() != reflect.Slice {
			return nil, fmt.Errorf("gld-kiln: proto not slice: %T", proto)
		}
		out := reflect.MakeSlice(pt, len(arr), len(arr))
		for i, el := range arr {
			dom, err := fromKilnOne(typeID, el)
			if err != nil {
				return nil, err
			}
			out.Index(i).Set(reflect.ValueOf(dom))
		}
		return out.Interface(), nil
	}
	return fromKilnOne(typeID, decoded)
}

func kilnMap(v any) (map[string]any, error) {
	m, ok := v.(map[string]any)
	if !ok || m == nil {
		return nil, fmt.Errorf("gld-kiln: expected struct map, got %T", v)
	}
	return m, nil
}

func takeKilnBool(v any) (bool, error) {
	b, ok := v.(bool)
	if !ok {
		return false, fmt.Errorf("gld-kiln: expected bool, got %T", v)
	}
	return b, nil
}

func takeKilnI32(v any) (int32, error) {
	n, ok := v.(int32)
	if !ok {
		return 0, fmt.Errorf("gld-kiln: expected int32, got %T", v)
	}
	return n, nil
}

func takeKilnI64(v any) (int64, error) {
	n, ok := v.(int64)
	if !ok {
		return 0, fmt.Errorf("gld-kiln: expected int64, got %T", v)
	}
	return n, nil
}

func takeKilnF64(v any) (float64, error) {
	n, ok := v.(float64)
	if !ok {
		return 0, fmt.Errorf("gld-kiln: expected float64, got %T", v)
	}
	return n, nil
}

func takeKilnStr(v any) (string, error) {
	s, ok := v.(string)
	if !ok {
		return "", fmt.Errorf("gld-kiln: expected string, got %T", v)
	}
	return s, nil
}

func kilnStrings(v any) ([]string, error) {
	raw, ok := v.([]any)
	if !ok {
		return nil, fmt.Errorf("gld-kiln: expected []any strings, got %T", v)
	}
	out := make([]string, len(raw))
	for i, el := range raw {
		s, err := takeKilnStr(el)
		if err != nil {
			return nil, err
		}
		out[i] = s
	}
	return out, nil
}

func takeKilnF32(v any) (float32, error) {
	n, ok := v.(float32)
	if !ok {
		return 0, fmt.Errorf("gld-kiln: expected float32, got %T", v)
	}
	return n, nil
}

func kilnF32s(v any) ([]float32, error) {
	switch raw := v.(type) {
	case []float32:
		return raw, nil
	case []any:
		out := make([]float32, len(raw))
		for i, el := range raw {
			n, err := takeKilnF32(el)
			if err != nil {
				return nil, err
			}
			out[i] = n
		}
		return out, nil
	default:
		return nil, fmt.Errorf("gld-kiln: expected float32 list, got %T", v)
	}
}

func kilnI64s(v any) ([]int64, error) {
	switch raw := v.(type) {
	case []int64:
		return raw, nil
	case []any:
		out := make([]int64, len(raw))
		for i, el := range raw {
			n, err := takeKilnI64(el)
			if err != nil {
				return nil, err
			}
			out[i] = n
		}
		return out, nil
	default:
		return nil, fmt.Errorf("gld-kiln: expected int64 list, got %T", v)
	}
}

func kilnPrompt(v any) (modelv2.Prompt, error) {
	m, err := kilnMap(v)
	if err != nil {
		return modelv2.Prompt{}, err
	}
	batch, err := takeKilnI32(m["batch"])
	if err != nil {
		return modelv2.Prompt{}, err
	}
	seq, err := takeKilnI32(m["seq"])
	if err != nil {
		return modelv2.Prompt{}, err
	}
	input, err := kilnI64s(m["input_ids"])
	if err != nil {
		return modelv2.Prompt{}, err
	}
	mask, err := kilnI64s(m["attention_mask"])
	if err != nil {
		return modelv2.Prompt{}, err
	}
	pos, err := kilnI64s(m["position_ids"])
	if err != nil {
		return modelv2.Prompt{}, err
	}
	return modelv2.Prompt{
		Batch: batch, Seq: seq,
		InputIDs: input, AttentionMask: mask, PositionIDs: pos,
	}, nil
}

func kilnF64s(v any) ([]float64, error) {
	switch raw := v.(type) {
	case []float64:
		return raw, nil
	case []any:
		out := make([]float64, len(raw))
		for i, el := range raw {
			n, err := takeKilnF64(el)
			if err != nil {
				return nil, err
			}
			out[i] = n
		}
		return out, nil
	default:
		return nil, fmt.Errorf("gld-kiln: expected float64 list, got %T", v)
	}
}

func fromKilnOne(typeID string, decoded any) (any, error) {
	m, err := kilnMap(decoded)
	if err != nil {
		return nil, err
	}
	switch typeID {
	case "message":
		fBool, err := takeKilnBool(m["f_bool"])
		if err != nil {
			return nil, err
		}
		fInt32, err := takeKilnI32(m["f_int32"])
		if err != nil {
			return nil, err
		}
		fInt64, err := takeKilnI64(m["f_int64"])
		if err != nil {
			return nil, err
		}
		fFloat, err := takeKilnF64(m["f_float64"])
		if err != nil {
			return nil, err
		}
		fString, err := takeKilnStr(m["f_string"])
		if err != nil {
			return nil, err
		}
		fBool2, err := takeKilnBool(m["f_bool_2"])
		if err != nil {
			return nil, err
		}
		fInt32_2, err := takeKilnI32(m["f_int32_2"])
		if err != nil {
			return nil, err
		}
		fString2, err := takeKilnStr(m["f_string_2"])
		if err != nil {
			return nil, err
		}
		return modelv2.Message{
			FBool: fBool, FInt32: fInt32, FInt64: fInt64, FFloat64: fFloat,
			FString: fString, FBool2: fBool2, FInt32_2: fInt32_2, FString2: fString2,
		}, nil
	case "document":
		id, err := takeKilnStr(m["id"])
		if err != nil {
			return nil, err
		}
		status, err := takeKilnI32(m["status"])
		if err != nil {
			return nil, err
		}
		meta, err := kilnMap(m["meta"])
		if err != nil {
			return nil, err
		}
		region, err := takeKilnStr(meta["region"])
		if err != nil {
			return nil, err
		}
		version, err := takeKilnI32(meta["version"])
		if err != nil {
			return nil, err
		}
		rawItems, ok := m["items"].([]any)
		if !ok {
			return nil, fmt.Errorf("gld-kiln: expected document items []any, got %T", m["items"])
		}
		items := make([]modelv2.DocumentItem, len(rawItems))
		for i, it := range rawItems {
			im, err := kilnMap(it)
			if err != nil {
				return nil, err
			}
			sku, err := takeKilnStr(im["sku"])
			if err != nil {
				return nil, err
			}
			qty, err := takeKilnI32(im["qty"])
			if err != nil {
				return nil, err
			}
			price, err := takeKilnI64(im["price_minor"])
			if err != nil {
				return nil, err
			}
			items[i] = modelv2.DocumentItem{SKU: sku, Qty: qty, PriceMinor: price}
		}
		return modelv2.Document{
			ID: id, Status: status,
			Meta:  modelv2.DocumentMeta{Region: region, Version: version},
			Items: items,
		}, nil
	case "telemetry":
		source, err := takeKilnStr(m["source"])
		if err != nil {
			return nil, err
		}
		ts, err := takeKilnI64(m["ts"])
		if err != nil {
			return nil, err
		}
		tags, err := kilnStrings(m["tags"])
		if err != nil {
			return nil, err
		}
		vals, err := kilnF64s(m["values"])
		if err != nil {
			return nil, err
		}
		return modelv2.Telemetry{Source: source, TS: ts, Tags: tags, Values: vals}, nil
	case "strings":
		items, err := kilnStrings(m["items"])
		if err != nil {
			return nil, err
		}
		return modelv2.Strings{Items: items}, nil
	case "event":
		eventID, err := takeKilnStr(m["event_id"])
		if err != nil {
			return nil, err
		}
		eventType, err := takeKilnStr(m["event_type"])
		if err != nil {
			return nil, err
		}
		occurred, err := takeKilnI64(m["occurred_at"])
		if err != nil {
			return nil, err
		}
		producer, err := takeKilnStr(m["producer"])
		if err != nil {
			return nil, err
		}
		rawAttrs, ok := m["attrs"].([]any)
		if !ok {
			return nil, fmt.Errorf("gld-kiln: expected event attrs []any, got %T", m["attrs"])
		}
		attrs := make([]modelv2.EventAttr, len(rawAttrs))
		for i, a := range rawAttrs {
			am, err := kilnMap(a)
			if err != nil {
				return nil, err
			}
			key, err := takeKilnStr(am["key"])
			if err != nil {
				return nil, err
			}
			val, err := takeKilnStr(am["value"])
			if err != nil {
				return nil, err
			}
			attrs[i] = modelv2.EventAttr{Key: key, Value: val}
		}
		return modelv2.Event{
			EventID: eventID, EventType: eventType, OccurredAt: occurred,
			Producer: producer, Attrs: attrs,
		}, nil
	case "tensor", "tensor_view":
		rows, err := takeKilnI32(m["rows"])
		if err != nil {
			return nil, err
		}
		cols, err := takeKilnI32(m["cols"])
		if err != nil {
			return nil, err
		}
		vals, err := kilnF32s(m["values"])
		if err != nil {
			return nil, err
		}
		return modelv2.Tensor{Rows: rows, Cols: cols, Values: vals}, nil
	case "prompt":
		return kilnPrompt(m)
	case "shard":
		vocab, err := takeKilnI32(m["vocab"])
		if err != nil {
			return nil, err
		}
		hidden, err := takeKilnI32(m["hidden"])
		if err != nil {
			return nil, err
		}
		ffn, err := takeKilnI32(m["ffn"])
		if err != nil {
			return nil, err
		}
		tok, err := kilnF32s(m["tok_emb"])
		if err != nil {
			return nil, err
		}
		attn, err := kilnF32s(m["attn"])
		if err != nil {
			return nil, err
		}
		ffnW, err := kilnF32s(m["ffn_weight"])
		if err != nil {
			return nil, err
		}
		norm, err := kilnF32s(m["norm"])
		if err != nil {
			return nil, err
		}
		return modelv2.Shard{
			Vocab: vocab, Hidden: hidden, FFN: ffn,
			TokEmb: tok, Attn: attn, FFNWeight: ffnW, Norm: norm,
		}, nil
	case "request":
		id, err := takeKilnI64(m["request_id"])
		if err != nil {
			return nil, err
		}
		modelName, err := takeKilnStr(m["model"])
		if err != nil {
			return nil, err
		}
		temp, err := takeKilnF32(m["temperature"])
		if err != nil {
			return nil, err
		}
		inputs, err := kilnPrompt(m["inputs"])
		if err != nil {
			return nil, err
		}
		return modelv2.Request{
			RequestID: id, Model: modelName, Temperature: temp, Inputs: inputs,
		}, nil
	default:
		return nil, fmt.Errorf("gld-kiln: unsupported type_id %s", typeID)
	}
}
