package serializers

import (
	"io"

	"github.com/vmihailenco/msgpack/v5"

	"serializer-benchmark-go/model"
)

// vmihailencoMsgpack — most popular MessagePack library for Go.
// Recommended: msgpack.Marshal / msgpack.Unmarshal; reuse Encoder/Decoder with
// SetCustomStructTag("json") optional. We use default struct tags (msgpack / field names).
// https://github.com/vmihailenco/msgpack
type vmihailencoMsgpack struct {
	proto any
}

func newVmihailencoMsgpack() *vmihailencoMsgpack { return &vmihailencoMsgpack{} }

func (s *vmihailencoMsgpack) Name() string           { return "vmihailenco/msgpack" }
func (s *vmihailencoMsgpack) Version() string        { return "5" }
func (s *vmihailencoMsgpack) StreamMode() StreamMode { return StreamNative }
func (s *vmihailencoMsgpack) NativeKind() NativeKind { return NativeReflect }
func (s *vmihailencoMsgpack) Supports(n string) bool { return DefaultSupports(n) }

func (s *vmihailencoMsgpack) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *vmihailencoMsgpack) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return msgpack.Marshal(fx.Value)
}

func (s *vmihailencoMsgpack) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := msgpack.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *vmihailencoMsgpack) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	enc := msgpack.NewEncoder(cw)
	if err := enc.Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *vmihailencoMsgpack) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	dec := msgpack.NewDecoder(r)
	if err := dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
