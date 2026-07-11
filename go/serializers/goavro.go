package serializers

import (
	"fmt"
	"io"
	"reflect"
	"sync"

	"github.com/linkedin/goavro/v2"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// linkedInGoavro — LinkedIn goavro (classic Kafka/Avro path; map-native API).
// Recommended (README): NewCodec once per schema; BinaryFromNative / NativeFromBinary
// with map[string]any records (not goavro.Record). Codec is concurrent-safe.
// Domain struct ↔ map conversion is untimed (prepare / ToDomain).
// https://github.com/linkedin/goavro
//
// Note: LinkedIn's own README prefers hamba/avro for greenfield high-throughput;
// goavro remains the reference map-based implementation widely deployed with
// Confluent Schema Registry stacks.
type linkedInGoavro struct {
	codec  *goavro.Codec
	native any // prepared map / []any for encode
	proto  any // domain prototype for ToDomain / empty target
	fxName string
	batch  bool
}

var (
	goavroCodecMu    sync.Mutex
	goavroCodecCache = map[string]*goavro.Codec{}
)

func newLinkedInGoavro() *linkedInGoavro { return &linkedInGoavro{} }

func (s *linkedInGoavro) Name() string           { return "linkedin/goavro" }
func (s *linkedInGoavro) Version() string        { return ModuleVersion("github.com/linkedin/goavro/v2") }
func (s *linkedInGoavro) StreamMode() StreamMode { return StreamAdapted }
func (s *linkedInGoavro) NativeKind() NativeKind { return NativeSchema }
func (s *linkedInGoavro) Supports(n string) bool {
	switch n {
	case "message", "document", "telemetry", "strings", "event",
		"Person", "Integer", "SimpleObject", "StringArray", "Telemetry", "EDI_835", "ObjectGraph":
		return true
	default:
		return DefaultSupports(n)
	}
}

func (s *linkedInGoavro) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.fxName = fx.Name
	s.batch = isSlice(fx.Value)

	// Reuse the same logical Avro schema JSON as hamba/avro (schemaFor).
	sch, err := schemaFor(fx.Name)
	if err != nil {
		return err
	}
	schemaJSON := sch.String()
	cacheKey := fx.Name
	if s.batch {
		schemaJSON = `{"type":"array","items":` + schemaJSON + `}`
		cacheKey = fx.Name + "#array"
	}
	codec, err := goavroCodec(cacheKey, schemaJSON)
	if err != nil {
		return err
	}
	s.codec = codec

	// Untimed domain → native map / []any
	s.native, err = toGoavroNative(fx.Value)
	return err
}

func goavroCodec(key, schemaJSON string) (*goavro.Codec, error) {
	goavroCodecMu.Lock()
	defer goavroCodecMu.Unlock()
	if c, ok := goavroCodecCache[key]; ok {
		return c, nil
	}
	c, err := goavro.NewCodec(schemaJSON)
	if err != nil {
		return nil, fmt.Errorf("goavro NewCodec: %w", err)
	}
	goavroCodecCache[key] = c
	return c, nil
}

func (s *linkedInGoavro) SerializeBytes(_ model.Fixture) ([]byte, error) {
	// BinaryFromNative(nil, native) is the recommended one-shot binary encode.
	return s.codec.BinaryFromNative(nil, s.native)
}

func (s *linkedInGoavro) DeserializeBytes(buf []byte) (any, error) {
	// Timed path ends at native map/slice — domain conversion via ToDomain.
	native, _, err := s.codec.NativeFromBinary(buf)
	if err != nil {
		return nil, err
	}
	return native, nil
}

// ToDomain converts goavro native maps back to suite structs (untimed fidelity path).
func (s *linkedInGoavro) ToDomain(decoded any) (any, error) {
	return fromGoavroNative(s.fxName, s.batch, decoded, s.proto)
}

func (s *linkedInGoavro) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *linkedInGoavro) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

// --- domain ↔ goavro native (map[string]any / []any) ---

func toGoavroNative(v any) (any, error) {
	if v == nil {
		return nil, nil
	}
	rv := reflect.ValueOf(v)
	if rv.Kind() == reflect.Slice {
		out := make([]any, rv.Len())
		for i := 0; i < rv.Len(); i++ {
			n, err := toGoavroNative(rv.Index(i).Interface())
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
			"f_bool": t.FBool, "f_int32": int32(t.FInt32), "f_int64": t.FInt64,
			"f_float64": t.FFloat64, "f_string": t.FString, "f_bool_2": t.FBool2,
			"f_int32_2": int32(t.FInt32_2), "f_string_2": t.FString2,
		}, nil
	case modelv2.Document:
		items := make([]any, len(t.Items))
		for i, it := range t.Items {
			items[i] = map[string]any{
				"sku": it.SKU, "qty": int32(it.Qty), "price_minor": it.PriceMinor,
			}
		}
		return map[string]any{
			"id": t.ID, "status": int32(t.Status),
			"meta": map[string]any{"region": t.Meta.Region, "version": int32(t.Meta.Version)},
			"items": items,
		}, nil
	case modelv2.Telemetry:
		tags := make([]any, len(t.Tags))
		for i, x := range t.Tags {
			tags[i] = x
		}
		vals := make([]any, len(t.Values))
		for i, x := range t.Values {
			vals[i] = x
		}
		return map[string]any{"source": t.Source, "ts": t.TS, "tags": tags, "values": vals}, nil
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
	case model.Person:
		var pass any
		if t.Passport != nil {
			pass = map[string]any{
				"Passport": map[string]any{
					"number": t.Passport.Number, "authority": t.Passport.Authority,
					"expiration_date": t.Passport.ExpirationDate,
				},
			}
		} else {
			pass = nil // goavro accepts nil for null branch of union
		}
		recs := make([]any, len(t.PoliceRecords))
		for i, r := range t.PoliceRecords {
			recs[i] = map[string]any{"id": int32(r.ID), "crime_code": r.CrimeCode}
		}
		return map[string]any{
			"first_name": t.FirstName, "last_name": t.LastName,
			"age": int32(t.Age), "gender": int32(t.Gender),
			"passport": pass, "police_records": recs,
		}, nil
	case model.ObjectGraph:
		nodes := make([]any, len(t.Nodes))
		for i, n := range t.Nodes {
			ch := make([]any, len(n.Children))
			for j, c := range n.Children {
				ch[j] = int32(c)
			}
			nodes[i] = map[string]any{
				"name": n.Name, "parent": int32(n.Parent),
				"related": int32(n.Related), "children": ch,
			}
		}
		return map[string]any{"root": int32(t.Root), "nodes": nodes}, nil
	default:
		return nil, fmt.Errorf("goavro: unsupported type %T", v)
	}
}

func fromGoavroNative(typeID string, batch bool, decoded, proto any) (any, error) {
	if batch {
		arr, ok := decoded.([]any)
		if !ok {
			return nil, fmt.Errorf("goavro: expected []any batch, got %T", decoded)
		}
		// Build typed slice matching proto
		pt := reflect.TypeOf(proto)
		if pt.Kind() != reflect.Slice {
			return nil, fmt.Errorf("goavro: proto not slice: %T", proto)
		}
		out := reflect.MakeSlice(pt, len(arr), len(arr))
		for i, el := range arr {
			dom, err := fromGoavroOne(typeID, el)
			if err != nil {
				return nil, err
			}
			out.Index(i).Set(reflect.ValueOf(dom))
		}
		return out.Interface(), nil
	}
	return fromGoavroOne(typeID, decoded)
}

func asInt32(v any) int32 {
	switch n := v.(type) {
	case int32:
		return n
	case int:
		return int32(n)
	case int64:
		return int32(n)
	case float64:
		return int32(n)
	default:
		return 0
	}
}

func asInt64(v any) int64 {
	switch n := v.(type) {
	case int64:
		return n
	case int:
		return int64(n)
	case int32:
		return int64(n)
	case float64:
		return int64(n)
	default:
		return 0
	}
}

func asFloat64(v any) float64 {
	switch n := v.(type) {
	case float64:
		return n
	case float32:
		return float64(n)
	case int:
		return float64(n)
	case int64:
		return float64(n)
	default:
		return 0
	}
}

func asString(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func asBool(v any) bool {
	if b, ok := v.(bool); ok {
		return b
	}
	return false
}

func asMap(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	// goavro may return map[string]interface{}
	if m, ok := v.(map[string]interface{}); ok {
		return m
	}
	return nil
}

func fromGoavroOne(typeID string, decoded any) (any, error) {
	m := asMap(decoded)
	if m == nil {
		return nil, fmt.Errorf("goavro: expected map record, got %T", decoded)
	}
	switch typeID {
	case "message":
		return modelv2.Message{
			FBool: asBool(m["f_bool"]), FInt32: asInt32(m["f_int32"]),
			FInt64: asInt64(m["f_int64"]), FFloat64: asFloat64(m["f_float64"]),
			FString: asString(m["f_string"]), FBool2: asBool(m["f_bool_2"]),
			FInt32_2: asInt32(m["f_int32_2"]), FString2: asString(m["f_string_2"]),
		}, nil
	case "document":
		meta := asMap(m["meta"])
		var items []modelv2.DocumentItem
		if raw, ok := m["items"].([]any); ok {
			items = make([]modelv2.DocumentItem, len(raw))
			for i, it := range raw {
				im := asMap(it)
				items[i] = modelv2.DocumentItem{
					SKU: asString(im["sku"]), Qty: asInt32(im["qty"]), PriceMinor: asInt64(im["price_minor"]),
				}
			}
		}
		return modelv2.Document{
			ID: asString(m["id"]), Status: asInt32(m["status"]),
			Meta: modelv2.DocumentMeta{
				Region: asString(meta["region"]), Version: asInt32(meta["version"]),
			},
			Items: items,
		}, nil
	case "telemetry":
		var tags []string
		if raw, ok := m["tags"].([]any); ok {
			tags = make([]string, len(raw))
			for i, t := range raw {
				tags[i] = asString(t)
			}
		}
		var vals []float64
		if raw, ok := m["values"].([]any); ok {
			vals = make([]float64, len(raw))
			for i, t := range raw {
				vals[i] = asFloat64(t)
			}
		}
		return modelv2.Telemetry{
			Source: asString(m["source"]), TS: asInt64(m["ts"]), Tags: tags, Values: vals,
		}, nil
	case "strings":
		var items []string
		if raw, ok := m["items"].([]any); ok {
			items = make([]string, len(raw))
			for i, t := range raw {
				items[i] = asString(t)
			}
		}
		return modelv2.Strings{Items: items}, nil
	case "event":
		var attrs []modelv2.EventAttr
		if raw, ok := m["attrs"].([]any); ok {
			attrs = make([]modelv2.EventAttr, len(raw))
			for i, a := range raw {
				am := asMap(a)
				attrs[i] = modelv2.EventAttr{Key: asString(am["key"]), Value: asString(am["value"])}
			}
		}
		return modelv2.Event{
			EventID: asString(m["event_id"]), EventType: asString(m["event_type"]),
			OccurredAt: asInt64(m["occurred_at"]), Producer: asString(m["producer"]), Attrs: attrs,
		}, nil
	case "Person":
		var pass *model.Passport
		if pv := m["passport"]; pv != nil {
			pm := asMap(pv)
			// Union: {"Passport": {...}} or already unwrapped map
			if inner := asMap(pm["Passport"]); inner != nil {
				pm = inner
			}
			if pm != nil {
				pass = &model.Passport{
					Number: asString(pm["number"]), Authority: asString(pm["authority"]),
					ExpirationDate: asString(pm["expiration_date"]),
				}
			}
		}
		var recs []model.PoliceRecord
		if raw, ok := m["police_records"].([]any); ok {
			recs = make([]model.PoliceRecord, len(raw))
			for i, r := range raw {
				rm := asMap(r)
				recs[i] = model.PoliceRecord{ID: asInt32(rm["id"]), CrimeCode: asString(rm["crime_code"])}
			}
		}
		return model.Person{
			FirstName: asString(m["first_name"]), LastName: asString(m["last_name"]),
			Age: asInt32(m["age"]), Gender: model.Gender(asInt32(m["gender"])),
			Passport: pass, PoliceRecords: recs,
		}, nil
	case "ObjectGraph":
		var nodes []model.GraphNodeData
		if raw, ok := m["nodes"].([]any); ok {
			nodes = make([]model.GraphNodeData, len(raw))
			for i, n := range raw {
				nm := asMap(n)
				var ch []int32
				if cr, ok := nm["children"].([]any); ok {
					ch = make([]int32, len(cr))
					for j, c := range cr {
						ch[j] = asInt32(c)
					}
				}
				nodes[i] = model.GraphNodeData{
					Name: asString(nm["name"]), Parent: asInt32(nm["parent"]),
					Related: asInt32(nm["related"]), Children: ch,
				}
			}
		}
		return model.ObjectGraph{Root: asInt32(m["root"]), Nodes: nodes}, nil
	default:
		return nil, fmt.Errorf("goavro: unsupported type_id %s", typeID)
	}
}
