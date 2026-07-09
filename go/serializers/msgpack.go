package serializers

import (
	"bytes"
	"io"

	"github.com/vmihailenco/msgpack/v5"

	"serializer-benchmark-go/model"
)

// vmihailencoMsgpack — most popular MessagePack library for Go.
// Recommended hot path: reuse Encoder via Reset (avoids per-call encoder setup
// that Marshal's pool still pays for buffer ownership). Unmarshal for bytes decode.
// https://github.com/vmihailenco/msgpack
type vmihailencoMsgpack struct {
	proto any
	buf   bytes.Buffer
	enc   *msgpack.Encoder
}

func newVmihailencoMsgpack() *vmihailencoMsgpack {
	s := &vmihailencoMsgpack{}
	s.enc = msgpack.NewEncoder(&s.buf)
	return s
}

func (s *vmihailencoMsgpack) Name() string           { return "vmihailenco/msgpack" }
func (s *vmihailencoMsgpack) Version() string        { return ModuleVersion("github.com/vmihailenco/msgpack/v5") }
func (s *vmihailencoMsgpack) StreamMode() StreamMode { return StreamNative }
func (s *vmihailencoMsgpack) NativeKind() NativeKind { return NativeReflect }
func (s *vmihailencoMsgpack) Supports(n string) bool { return DefaultSupports(n) }

func (s *vmihailencoMsgpack) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	return nil
}

func (s *vmihailencoMsgpack) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	if err := s.enc.Encode(fx.Value); err != nil {
		return nil, err
	}
	// Copy: internal buffer is reused on the next call.
	out := make([]byte, s.buf.Len())
	copy(out, s.buf.Bytes())
	return out, nil
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
	s.enc.Reset(cw)
	if err := s.enc.Encode(fx.Value); err != nil {
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
