package serializers

import (
	"io"

	"github.com/shamaton/msgpack/v3"

	"serializer-benchmark-go/model"
)

// shamatonMsgpackArray — shamaton/msgpack using its struct-as-array encoding
// (MarshalAsArray/UnmarshalAsArray, MarshalWriteAsArray/UnmarshalReadAsArray).
// Structs are encoded positionally instead of as maps with field-name keys,
// which is a distinct, more compact wire shape (closer to how avro/protobuf
// encode records) and is worth comparing separately from the default,
// map-based `shamaton/msgpack` entry.
// https://github.com/shamaton/msgpack
type shamatonMsgpackArray struct {
	proto any
}

func newShamatonMsgpackArray() *shamatonMsgpackArray { return &shamatonMsgpackArray{} }

func (s *shamatonMsgpackArray) Name() string { return "shamaton/msgpack (array)" }
func (s *shamatonMsgpackArray) Version() string {
	return ModuleVersion("github.com/shamaton/msgpack/v3")
}
func (s *shamatonMsgpackArray) StreamMode() StreamMode { return StreamNative }
func (s *shamatonMsgpackArray) NativeKind() NativeKind { return NativeReflect }
func (s *shamatonMsgpackArray) Supports(n string) bool { return DefaultSupports(n) }

func (s *shamatonMsgpackArray) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *shamatonMsgpackArray) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return msgpack.MarshalAsArray(fx.Value)
}

func (s *shamatonMsgpackArray) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := msgpack.UnmarshalAsArray(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *shamatonMsgpackArray) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := msgpack.MarshalWriteAsArray(cw, fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *shamatonMsgpackArray) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := msgpack.UnmarshalReadAsArray(r, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
