package serializers

import (
	"bytes"
	"io"

	"github.com/kelindar/binary"

	"serializer-benchmark-go/model"
)

// kelindarBinary — high-performance Go-only binary packer (varint ints, reflect structs).
// Recommended: reuse Encoder via Reset onto a buffer; Unmarshal / Decoder for decode.
// https://github.com/kelindar/binary
type kelindarBinary struct {
	proto any
	buf   bytes.Buffer
	enc   *binary.Encoder
}

func newKelindarBinary() *kelindarBinary {
	s := &kelindarBinary{}
	s.enc = binary.NewEncoder(&s.buf)
	return s
}

func (s *kelindarBinary) Name() string           { return "kelindar/binary" }
func (s *kelindarBinary) Version() string        { return ModuleVersion("github.com/kelindar/binary") }
func (s *kelindarBinary) StreamMode() StreamMode { return StreamNative }
func (s *kelindarBinary) NativeKind() NativeKind { return NativeReflect }
func (s *kelindarBinary) Supports(n string) bool { return DefaultSupports(n) }

func (s *kelindarBinary) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	return nil
}

func (s *kelindarBinary) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	if err := s.enc.Encode(fx.Value); err != nil {
		return nil, err
	}
	out := make([]byte, s.buf.Len())
	copy(out, s.buf.Bytes())
	return out, nil
}

func (s *kelindarBinary) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := binary.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *kelindarBinary) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	s.enc.Reset(cw)
	if err := s.enc.Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *kelindarBinary) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := binary.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
