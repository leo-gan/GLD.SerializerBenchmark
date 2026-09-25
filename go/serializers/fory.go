package serializers

import (
	"io"
	"reflect"

	"github.com/apache/fory/go/fory"
	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

type forySerializer struct {
	fory  *fory.Fory
	proto any
	value any
}

func newFory() *forySerializer {
	f := fory.New(fory.WithXlang(false), fory.WithRefTracking(false))
	for i, value := range []any{
		modelv2.Message{}, modelv2.DocumentMeta{}, modelv2.DocumentItem{}, modelv2.Document{},
		modelv2.Telemetry{}, modelv2.Strings{}, modelv2.EventAttr{}, modelv2.Event{},
	} {
		if err := f.RegisterStruct(value, uint32(i+1)); err != nil {
			panic(err)
		}
	}
	return &forySerializer{fory: f}
}

func (s *forySerializer) Name() string           { return "fory" }
func (s *forySerializer) Version() string        { return ModuleVersion("github.com/apache/fory/go/fory") }
func (s *forySerializer) StreamMode() StreamMode { return StreamAdapted }
func (s *forySerializer) NativeKind() NativeKind { return NativeReflect }
func (s *forySerializer) Supports(n string) bool { return DefaultSupports(n) }
func (s *forySerializer) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.value = fx.Value
	// Fory's native struct API takes pointers. Materialize that view untimed.
	if v := reflect.ValueOf(fx.Value); v.Kind() == reflect.Struct {
		p := reflect.New(v.Type())
		p.Elem().Set(v)
		s.value = p.Interface()
	}
	data, err := s.SerializeBytes(fx)
	if err != nil {
		return err
	}
	_, err = s.DeserializeBytes(data)
	return err
}
func (s *forySerializer) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.fory.Serialize(s.value)
}
func (s *forySerializer) DeserializeBytes(data []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.fory.Deserialize(data, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
func (s *forySerializer) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}
func (s *forySerializer) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}
