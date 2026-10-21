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

func newGldKiln() *gldKiln { return &gldKiln{} }

func (s *gldKiln) Name() string { return "gld-kiln" }

// Version is the Git tag. The tag is 0.2.0, not v0.2.0, so build info is a pseudo-version.
func (s *gldKiln) Version() string        { return "0.2.0" }
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
	var err error
	s.buf, err = kiln.Append(s.buf[:0], s.schema, s.native)
	if err != nil {
		return nil, err
	}
	return s.buf, nil
}

func (s *gldKiln) DeserializeBytes(buf []byte) (any, error) {
	if s.borrow {
		return borrowTensor(buf)
	}
	return kiln.Decode(s.schema, buf, kiln.Options{})
}

func (s *gldKiln) ToDomain(decoded any) (any, error) {
	return fromKilnNative(s.fxName, s.batch, decoded, s.proto)
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
