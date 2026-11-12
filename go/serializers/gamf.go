package serializers

import (
	"bytes"
	"io"

	"github.com/gnolizuh/gamf"

	"serializer-benchmark-go/model"
)

// gamfAmf0 times github.com/gnolizuh/gamf Marshal, which writes AMF0.
// AMF3 in this release panics while decoding a struct, so it is not registered.
// https://github.com/gnolizuh/gamf
type gamfAmf0 struct {
	proto any
}

func newGamfAmf0() *gamfAmf0 { return &gamfAmf0{} }

func (s *gamfAmf0) Name() string           { return "gamf-amf0" }
func (s *gamfAmf0) Version() string        { return ModuleVersion("github.com/gnolizuh/gamf") }
func (s *gamfAmf0) StreamMode() StreamMode { return StreamAdapted }
func (s *gamfAmf0) NativeKind() NativeKind { return NativeReflect }
func (s *gamfAmf0) Supports(n string) bool { return DefaultSupports(n) }

func (s *gamfAmf0) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *gamfAmf0) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return amf.Marshal(fx.Value)
}

func (s *gamfAmf0) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	dec := amf.NewDecoder().WithReader(bytes.NewReader(buf))
	if err := dec.Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *gamfAmf0) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *gamfAmf0) DeserializeStream(r io.Reader) (any, error) {
	buf, err := io.ReadAll(r)
	if err != nil {
		return nil, err
	}
	return s.DeserializeBytes(buf)
}
