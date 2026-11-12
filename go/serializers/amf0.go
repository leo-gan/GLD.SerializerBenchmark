package serializers

import (
	"bytes"
	"io"

	"github.com/yutopp/go-amf0"

	"serializer-benchmark-go/model"
)

// yutoppAmf0 encodes AMF0 with reflection.
// The encoder writes structs as AMF0 objects and slices as strict arrays.
// https://github.com/yutopp/go-amf0
type yutoppAmf0 struct {
	proto any
	buf   bytes.Buffer
	enc   *amf0.Encoder
}

func newYutoppAmf0() *yutoppAmf0 {
	s := &yutoppAmf0{}
	s.enc = amf0.NewEncoder(&s.buf)
	return s
}

func (s *yutoppAmf0) Name() string           { return "go-amf0" }
func (s *yutoppAmf0) Version() string        { return ModuleVersion("github.com/yutopp/go-amf0") }
func (s *yutoppAmf0) StreamMode() StreamMode { return StreamNative }
func (s *yutoppAmf0) NativeKind() NativeKind { return NativeReflect }
func (s *yutoppAmf0) Supports(n string) bool { return DefaultSupports(n) }

func (s *yutoppAmf0) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	return nil
}

func (s *yutoppAmf0) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	if err := s.enc.Encode(fx.Value); err != nil {
		return nil, err
	}
	out := make([]byte, s.buf.Len())
	copy(out, s.buf.Bytes())
	return out, nil
}

func (s *yutoppAmf0) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	dec := amf0.NewDecoder(bytes.NewReader(buf))
	if err := dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *yutoppAmf0) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return countedWrite(w, func(cw io.Writer) error {
		s.enc.Reset(cw)
		return s.enc.Encode(fx.Value)
	})
}

func (s *yutoppAmf0) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	dec := amf0.NewDecoder(r)
	if err := dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
