package serializers

import (
	"io"

	"github.com/ugorji/go/codec"

	"serializer-benchmark-go/model"
)

// ugorjiHandle is shared machinery for ugorji/go/codec handles.
// Recommended (go-codec primer): reuse Handle; NewEncoderBytes + ResetBytes per encode;
// NewDecoderBytes + ResetBytes per decode; WriterBufferSize for stream throughput.
//
// lib implementation doesn't allow a reset across bytes vs io, so keep 2 separate pairs
//
// https://github.com/ugorji/go/codec  http://ugorji.net/blog/go-codec-primer
type ugorjiCodec struct {
	name   string
	h      codec.Handle
	out    []byte	
	enc    *codec.Encoder
	dec    *codec.Decoder
	strenc *codec.Encoder
	strdec *codec.Decoder
	proto  any
}

func newUgorjiCodec(h codec.Handle, bh *codec.BasicHandle) *ugorjiCodec {
	// Buffering improves stream encode; zero Indent for JSON throughput.
	bh.WriterBufferSize = 8192
	bh.ReaderBufferSize = 8192
	s := &ugorjiCodec{name: "ugorji/"+h.Name(), h: h}
	s.enc = codec.NewEncoderBytes(&s.out, h)
	s.dec = codec.NewDecoderBytes(nil, h)
	s.strenc = codec.NewEncoder(nil, h)
	s.strdec = codec.NewDecoder(nil, h)
	return s
}

func newUgorjiJSON() *ugorjiCodec {
	h := new(codec.JsonHandle)
	// Match high-throughput JSON: no HTML escape, no indent.
	h.HTMLCharsAsIs = true
	h.Indent = 0
	return newUgorjiCodec(h, &h.BasicHandle)
}

func newUgorjiMsgpack() *ugorjiCodec {
	h := new(codec.MsgpackHandle)
	// WriteExt improves type fidelity for time etc.; keep default for structs.
	return newUgorjiCodec(h, &h.BasicHandle)
}

func newUgorjiCBOR() *ugorjiCodec {
	h := new(codec.CborHandle)
	return newUgorjiCodec(h, &h.BasicHandle)
}

func (s *ugorjiCodec) Name() string           { return s.name }
func (s *ugorjiCodec) Version() string        { return ModuleVersion("github.com/ugorji/go/codec") }
func (s *ugorjiCodec) StreamMode() StreamMode { return StreamNative }
func (s *ugorjiCodec) NativeKind() NativeKind { return NativeReflect }
func (s *ugorjiCodec) Supports(n string) bool { return DefaultSupports(n) }

func (s *ugorjiCodec) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *ugorjiCodec) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.out = s.out[:0]
	s.enc.ResetBytes(&s.out)
	if err := s.enc.Encode(fx.Value); err != nil {
		return nil, err
	}
	return s.out, nil // honors zero-copy disciplined implementation
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
	s.strenc.Reset(cw)
	if err := s.strenc.Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *ugorjiCodec) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	s.strdec.Reset(r)
	if err := s.strdec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
