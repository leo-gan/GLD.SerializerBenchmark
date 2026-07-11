package serializers

import (
	"io"

	"github.com/ugorji/go/codec"

	"serializer-benchmark-go/model"
)

// ugorjiHandle is shared machinery for ugorji/go/codec handles.
// Recommended (go-codec primer): reuse Handle; NewEncoderBytes + ResetBytes per encode;
// NewDecoderBytes + ResetBytes per decode; WriterBufferSize for stream throughput.
// https://github.com/ugorji/go/codec  http://ugorji.net/blog/go-codec-primer
type ugorjiCodec struct {
	name   string
	h      codec.Handle
	out    []byte
	enc    *codec.Encoder
	dec    *codec.Decoder
	proto  any
	stream *codec.Encoder
}

func configureBasic(h *codec.BasicHandle) {
	// Buffering improves stream encode; zero Indent for JSON throughput.
	h.WriterBufferSize = 8192
	h.ReaderBufferSize = 8192
}

func newUgorjiJSON() *ugorjiCodec {
	jh := new(codec.JsonHandle)
	configureBasic(&jh.BasicHandle)
	// Match high-throughput JSON: no HTML escape, no indent.
	jh.HTMLCharsAsIs = true
	jh.Indent = 0
	s := &ugorjiCodec{name: "ugorji/json", h: jh}
	s.enc = codec.NewEncoderBytes(&s.out, jh)
	s.dec = codec.NewDecoderBytes(nil, jh)
	return s
}

func newUgorjiMsgpack() *ugorjiCodec {
	mh := new(codec.MsgpackHandle)
	configureBasic(&mh.BasicHandle)
	// WriteExt improves type fidelity for time etc.; keep default for structs.
	s := &ugorjiCodec{name: "ugorji/msgpack", h: mh}
	s.enc = codec.NewEncoderBytes(&s.out, mh)
	s.dec = codec.NewDecoderBytes(nil, mh)
	return s
}

func newUgorjiCBOR() *ugorjiCodec {
	ch := new(codec.CborHandle)
	configureBasic(&ch.BasicHandle)
	s := &ugorjiCodec{name: "ugorji/cbor", h: ch}
	s.enc = codec.NewEncoderBytes(&s.out, ch)
	s.dec = codec.NewDecoderBytes(nil, ch)
	return s
}

func (s *ugorjiCodec) Name() string           { return s.name }
func (s *ugorjiCodec) Version() string        { return ModuleVersion("github.com/ugorji/go/codec") }
func (s *ugorjiCodec) StreamMode() StreamMode { return StreamNative }
func (s *ugorjiCodec) NativeKind() NativeKind { return NativeReflect }
func (s *ugorjiCodec) Supports(n string) bool { return DefaultSupports(n) }

func (s *ugorjiCodec) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.out = s.out[:0]
	s.enc.ResetBytes(&s.out)
	return nil
}

func (s *ugorjiCodec) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.out = s.out[:0]
	s.enc.ResetBytes(&s.out)
	if err := s.enc.Encode(fx.Value); err != nil {
		return nil, err
	}
	out := make([]byte, len(s.out))
	copy(out, s.out)
	return out, nil
}

func (s *ugorjiCodec) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	s.dec.ResetBytes(buf)
	if err := s.dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *ugorjiCodec) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	// Writer path: NewEncoder + Reset (cannot mix Bytes encoder with Writer Reset).
	enc := codec.NewEncoder(cw, s.h)
	if err := enc.Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *ugorjiCodec) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	dec := codec.NewDecoder(r, s.h)
	if err := dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
