package serializers

import (
	"fmt"
	"io"
	"reflect"

	"github.com/pelletier/go-toml/v2"

	"serializer-benchmark-go/model"
)

// pelletierTOML — modern TOML v1 library (BurntSushi/toml successor ecosystem).
// Recommended: toml.Marshal / Unmarshal; NewEncoder/NewDecoder for streams.
// Batch (N>1): TOML forbids array-of-tables as document root — wrap as
// { items = [...] } untimed in prepare so timed path stays pure codec I/O.
// https://github.com/pelletier/go-toml
type pelletierTOML struct {
	proto     any
	batch     bool
	wrapped   any          // prepared root for encode
	batchType reflect.Type // untimed: StructOf for {items} decode target
}

func newPelletierTOML() *pelletierTOML { return &pelletierTOML{} }

func (s *pelletierTOML) Name() string           { return "pelletier/go-toml" }
func (s *pelletierTOML) Version() string        { return ModuleVersion("github.com/pelletier/go-toml/v2") }
func (s *pelletierTOML) StreamMode() StreamMode { return StreamNative }
func (s *pelletierTOML) NativeKind() NativeKind { return NativeReflect }
func (s *pelletierTOML) Supports(n string) bool { return DefaultSupports(n) }

func (s *pelletierTOML) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.batchType = nil
	rv := reflect.ValueOf(fx.Value)
	s.batch = rv.IsValid() && (rv.Kind() == reflect.Slice || rv.Kind() == reflect.Array)
	if s.batch {
		// Build a typed wrapper value: struct{ Items []T } (untimed StructOf).
		st := reflect.StructOf([]reflect.StructField{{
			Name: "Items",
			Type: reflect.TypeOf(fx.Value),
			Tag:  `toml:"items"`,
		}})
		s.batchType = st
		wrap := reflect.New(st).Elem()
		wrap.Field(0).Set(rv)
		s.wrapped = wrap.Interface()
	} else {
		s.wrapped = fx.Value
	}
	return nil
}

func (s *pelletierTOML) SerializeBytes(_ model.Fixture) ([]byte, error) {
	return toml.Marshal(s.wrapped)
}

func (s *pelletierTOML) DeserializeBytes(buf []byte) (any, error) {
	if s.batch {
		if s.batchType == nil {
			return nil, fmt.Errorf("toml: batchType not prepared")
		}
		wrap := reflect.New(s.batchType).Interface()
		if err := toml.Unmarshal(buf, wrap); err != nil {
			return nil, err
		}
		return itemsFromTomlBatch(wrap), nil
	}
	dst := model.NewEmptyPtr(s.proto)
	if err := toml.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *pelletierTOML) SerializeStream(_ model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := toml.NewEncoder(cw).Encode(s.wrapped); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *pelletierTOML) DeserializeStream(r io.Reader) (any, error) {
	if s.batch {
		if s.batchType == nil {
			return nil, fmt.Errorf("toml: batchType not prepared")
		}
		wrap := reflect.New(s.batchType).Interface()
		if err := toml.NewDecoder(r).Decode(wrap); err != nil {
			return nil, err
		}
		return itemsFromTomlBatch(wrap), nil
	}
	dst := model.NewEmptyPtr(s.proto)
	if err := toml.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func itemsFromTomlBatch(wrap any) any {
	rv := reflect.ValueOf(wrap)
	if rv.Kind() == reflect.Pointer {
		rv = rv.Elem()
	}
	return rv.FieldByName("Items").Interface()
}
