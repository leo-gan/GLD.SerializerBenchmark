package serializers

import (
	"encoding/json"
	"io"
	"reflect"

	"go.mongodb.org/mongo-driver/bson"

	"serializer-benchmark-go/model"
)

// mongoBSON — official MongoDB BSON codec.
// Values are JSON-normalized first so field names match struct `json` tags (Data Model v2).
// Top-level arrays are wrapped as {items: [...]} (BSON document root required).
type mongoBSON struct {
	proto any
	wrap  bool
}

func newMongoBSON() *mongoBSON { return &mongoBSON{} }

func (s *mongoBSON) Name() string           { return "mongo-bson" }
func (s *mongoBSON) Version() string        { return ModuleVersion("go.mongodb.org/mongo-driver") }
func (s *mongoBSON) StreamMode() StreamMode { return StreamAdapted }
func (s *mongoBSON) NativeKind() NativeKind { return NativeReflect }
func (s *mongoBSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *mongoBSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.wrap = false
	if fx.Value != nil {
		rv := reflect.ValueOf(fx.Value)
		if rv.Kind() == reflect.Slice || rv.Kind() == reflect.Array {
			s.wrap = true
		}
	}
	return nil
}

func toJSONMap(v any) (any, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var m any
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	return m, nil
}

func (s *mongoBSON) SerializeBytes(fx model.Fixture) ([]byte, error) {
	m, err := toJSONMap(fx.Value)
	if err != nil {
		return nil, err
	}
	if s.wrap {
		m = bson.M{"items": m}
	}
	return bson.Marshal(m)
}

func (s *mongoBSON) DeserializeBytes(buf []byte) (any, error) {
	var intermediate any
	if s.wrap {
		var m bson.M
		if err := bson.Unmarshal(buf, &m); err != nil {
			return nil, err
		}
		intermediate = m["items"]
	} else {
		var m bson.M
		if err := bson.Unmarshal(buf, &m); err != nil {
			return nil, err
		}
		intermediate = m
	}
	raw, err := json.Marshal(intermediate)
	if err != nil {
		return intermediate, nil
	}
	dst := model.NewEmptyPtr(s.proto)
	if err := json.Unmarshal(raw, dst); err != nil {
		return intermediate, nil
	}
	return model.Deref(dst), nil
}

func (s *mongoBSON) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *mongoBSON) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}
