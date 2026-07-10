package serializers

import (
	"fmt"
	"reflect"
	"io"
	"sync"

	"github.com/hamba/avro/v2"

	"serializer-benchmark-go/model"
)

// hambaAvro — modern, fast Apache Avro for Go (codegen-free struct binding).
// Recommended: parse schema once (cached), avro.Marshal/Unmarshal with frozen API.
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
func (s *hambaAvro) StreamMode() StreamMode { return StreamAdapted }
func (s *hambaAvro) NativeKind() NativeKind { return NativeSchema }
func (s *hambaAvro) Supports(n string) bool {
	switch n {
	case "message", "document", "telemetry", "strings", "event",
		"Person", "Integer", "SimpleObject", "StringArray", "Telemetry", "EDI_835", "ObjectGraph":
		return true
	default:
		return DefaultSupports(n)
	}
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
	return AdaptedSerializeStream(s, fx, w)
}

func (s *hambaAvro) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
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
	case "Person":
		raw = `{
			"type":"record","name":"Person","fields":[
				{"name":"first_name","type":"string"},
				{"name":"last_name","type":"string"},
				{"name":"age","type":"int"},
				{"name":"gender","type":"int"},
				{"name":"passport","type":["null",{
					"type":"record","name":"Passport","fields":[
						{"name":"number","type":"string"},
						{"name":"authority","type":"string"},
						{"name":"expiration_date","type":"string"}
					]
				}],"default":null},
				{"name":"police_records","type":{"type":"array","items":{
					"type":"record","name":"PoliceRecord","fields":[
						{"name":"id","type":"int"},
						{"name":"crime_code","type":"string"}
					]
				}}}
			]}`
	case "Integer":
		raw = `{"type":"record","name":"IntegerValue","fields":[{"name":"value","type":"int"}]}`
	case "SimpleObject":
		raw = `{"type":"record","name":"SimpleObject","fields":[
			{"name":"id","type":"int"},
			{"name":"name","type":"string"},
			{"name":"timestamp","type":"string"},
			{"name":"is_active","type":"boolean"}
		]}`
	case "StringArray":
		raw = `{"type":"record","name":"StringArrayObject","fields":[
			{"name":"items","type":{"type":"array","items":"string"}}
		]}`
	case "Telemetry":
		raw = `{"type":"record","name":"TelemetryData","fields":[
			{"name":"id","type":"string"},
			{"name":"data_source","type":"string"},
			{"name":"time_stamp","type":"string"},
			{"name":"param1","type":"int"},
			{"name":"param2","type":"int"},
			{"name":"measurements","type":{"type":"array","items":"double"}},
			{"name":"associated_problem_id","type":"int"},
			{"name":"associated_log_id","type":"int"},
			{"name":"was_processed","type":"boolean"}
		]}`
	case "EDI_835":
		raw = `{"type":"record","name":"Edi835","fields":[
			{"name":"payer_name","type":"string"},
			{"name":"payee_name","type":"string"},
			{"name":"payment_date","type":"string"},
			{"name":"total_actual_amount","type":"double"},
			{"name":"transaction_control_number","type":"string"},
			{"name":"claims","type":{"type":"array","items":{
				"type":"record","name":"Claim","fields":[
					{"name":"claim_id","type":"string"},
					{"name":"patient_name","type":"string"},
					{"name":"total_charge","type":"double"},
					{"name":"payment_amount","type":"double"},
					{"name":"lines","type":{"type":"array","items":{
						"type":"record","name":"ServiceLine","fields":[
							{"name":"service_code","type":"string"},
							{"name":"charge_amount","type":"double"},
							{"name":"adjudicated_amount","type":"double"}
						]
					}}}
				]
			}}}
		]}`
	case "ObjectGraph":
		raw = `{"type":"record","name":"ObjectGraph","fields":[
			{"name":"root","type":"int"},
			{"name":"nodes","type":{"type":"array","items":{
				"type":"record","name":"GraphNodeData","fields":[
					{"name":"name","type":"string"},
					{"name":"parent","type":"int"},
					{"name":"related","type":"int"},
					{"name":"children","type":{"type":"array","items":"int"}}
				]
			}}}
		]}`
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
