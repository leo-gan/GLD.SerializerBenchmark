package serializers

import (
	"io"

	"go.mongodb.org/mongo-driver/bson"

	"serializer-benchmark-go/model"
)

// mongoBSON — official MongoDB BSON codec.
// Recommended: bson.Marshal / bson.Unmarshal (or bson.MarshalValue for primitives).
// https://pkg.go.dev/go.mongodb.org/mongo-driver/bson
type mongoBSON struct {
	proto any
}

func newMongoBSON() *mongoBSON { return &mongoBSON{} }

func (s *mongoBSON) Name() string           { return "mongo-bson" }
func (s *mongoBSON) Version() string        { return ModuleVersion("go.mongodb.org/mongo-driver") }
func (s *mongoBSON) StreamMode() StreamMode { return StreamAdapted }
func (s *mongoBSON) NativeKind() NativeKind { return NativeReflect }
func (s *mongoBSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *mongoBSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *mongoBSON) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return bson.Marshal(fx.Value)
}

func (s *mongoBSON) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := bson.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *mongoBSON) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *mongoBSON) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}
