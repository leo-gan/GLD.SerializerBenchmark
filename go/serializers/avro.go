package serializers

import (
	"fmt"
	"io"
	"reflect"
	"sync"

	"github.com/hamba/avro/v2"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// hambaAvro — modern, fast Apache Avro for Go (codegen-free struct binding).
// Recommended: parse schema once (cached); API.Marshal/Unmarshal for bytes;
// API.NewEncoder / NewDecoder for streams (schema-bound, Flush on Encode).
// https://github.com/hamba/avro
type hambaAvro struct {
	proto  any
	schema avro.Schema
	api    avro.API
	fxName string
}

// Package-level schema cache — Parse is not free; Prepare must not re-parse.
var (
	avroSchemaMu    sync.Mutex
	avroSchemaCache = map[string]avro.Schema{}
	avroAPI         = avro.Config{}.Freeze()
)

func newHambaAvro() *hambaAvro {
	return &hambaAvro{api: avroAPI}
}

func (s *hambaAvro) Name() string           { return "hamba/avro" }
func (s *hambaAvro) Version() string        { return ModuleVersion("github.com/hamba/avro/v2") }
func (s *hambaAvro) StreamMode() StreamMode { return StreamNative }
func (s *hambaAvro) NativeKind() NativeKind { return NativeSchema }
func (s *hambaAvro) Supports(n string) bool {
	return modelv2.IsV2TypeName(n)
}

func (s *hambaAvro) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.fxName = fx.Name
	sch, err := schemaFor(fx.Name)
	if err != nil {
		return err
	}
	// Batch N>1: array of records
	if isSlice(fx.Value) {
		raw := `{"type":"array","items":` + sch.String() + `}`
		sch, err = avro.Parse(raw)
		if err != nil {
			return err
		}
	}
	s.schema = sch
	return nil
}

func isSlice(v any) bool {
	if v == nil {
		return false
	}
	switch reflect.TypeOf(v).Kind() {
	case reflect.Slice, reflect.Array:
		return true
	default:
		return false
	}
}

func (s *hambaAvro) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.api.Marshal(s.schema, fx.Value)
}

func (s *hambaAvro) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.api.Unmarshal(s.schema, buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *hambaAvro) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	enc := s.api.NewEncoder(s.schema, cw)
	if err := enc.Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *hambaAvro) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	dec := s.api.NewDecoder(s.schema, r)
	if err := dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

// Schemas use field names matching avro struct tags on data types.
// Parsed schemas are cached for the process lifetime.
func schemaFor(name string) (avro.Schema, error) {
	avroSchemaMu.Lock()
	defer avroSchemaMu.Unlock()
	if sch, ok := avroSchemaCache[name]; ok {
		return sch, nil
	}
	var raw string
	switch name {
	// Data Model v2 type_ids (JSON field names match model/v2 struct tags)
	case "message":
		raw = `{"type":"record","name":"Message","fields":[
			{"name":"f_bool","type":"boolean"},{"name":"f_int32","type":"int"},
			{"name":"f_int64","type":"long"},{"name":"f_float64","type":"double"},
			{"name":"f_string","type":"string"},{"name":"f_bool_2","type":"boolean"},
			{"name":"f_int32_2","type":"int"},{"name":"f_string_2","type":"string"}
		]}`
	case "document":
		raw = `{"type":"record","name":"Document","fields":[
			{"name":"id","type":"string"},{"name":"status","type":"int"},
			{"name":"meta","type":{"type":"record","name":"DocumentMeta","fields":[
				{"name":"region","type":"string"},{"name":"version","type":"int"}
			]}},
			{"name":"items","type":{"type":"array","items":{"type":"record","name":"DocumentItem","fields":[
				{"name":"sku","type":"string"},{"name":"qty","type":"int"},{"name":"price_minor","type":"long"}
			]}}}
		]}`
	case "telemetry":
		raw = `{"type":"record","name":"TelemetryV2","fields":[
			{"name":"source","type":"string"},{"name":"ts","type":"long"},
			{"name":"tags","type":{"type":"array","items":"string"}},
			{"name":"values","type":{"type":"array","items":"double"}}
		]}`
	case "strings":
		raw = `{"type":"record","name":"Strings","fields":[
			{"name":"items","type":{"type":"array","items":"string"}}
		]}`
	case "event":
		raw = `{"type":"record","name":"Event","fields":[
			{"name":"event_id","type":"string"},{"name":"event_type","type":"string"},
			{"name":"occurred_at","type":"long"},{"name":"producer","type":"string"},
			{"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":[
				{"name":"key","type":"string"},{"name":"value","type":"string"}
			]}}}
		]}`
	default:
		return nil, fmt.Errorf("avro: no schema for %s", name)
	}
	sch, err := avro.Parse(raw)
	if err != nil {
		return nil, err
	}
	avroSchemaCache[name] = sch
	return sch, nil
}
