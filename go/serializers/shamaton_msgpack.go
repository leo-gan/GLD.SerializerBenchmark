package serializers

import (
	"io"

	"github.com/shamaton/msgpack/v3"

	"serializer-benchmark-go/model"
)

// shamatonMsgpack — high-performance pure-Go MessagePack (frequent top of go_serialization_benchmarks).
// Recommended: msgpack.Marshal / msgpack.Unmarshal.
// https://github.com/shamaton/msgpack
type shamatonMsgpack struct {
	proto any
}

func newShamatonMsgpack() *shamatonMsgpack { return &shamatonMsgpack{} }

func (s *shamatonMsgpack) Name() string           { return "shamaton/msgpack" }
func (s *shamatonMsgpack) Version() string        { return "3" }
func (s *shamatonMsgpack) StreamMode() StreamMode { return StreamAdapted }
func (s *shamatonMsgpack) NativeKind() NativeKind { return NativeReflect }
func (s *shamatonMsgpack) Supports(n string) bool { return DefaultSupports(n) }

func (s *shamatonMsgpack) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *shamatonMsgpack) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return msgpack.Marshal(fx.Value)
}

func (s *shamatonMsgpack) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := msgpack.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *shamatonMsgpack) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *shamatonMsgpack) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}
