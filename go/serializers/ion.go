package serializers

import (
	"io"

	"github.com/amazon-ion/ion-go/ion"

	"serializer-benchmark-go/model"
)

// amazonIon is the Ion team Go library (binary Ion).
// MarshalBinary / Unmarshal match encoding/json. Stream uses Encoder and Reader.
// https://github.com/amazon-ion/ion-go
type amazonIon struct {
	proto any
}

func newAmazonIon() *amazonIon { return &amazonIon{} }

func (s *amazonIon) Name() string           { return "ion-go" }
func (s *amazonIon) Version() string        { return ModuleVersion("github.com/amazon-ion/ion-go") }
func (s *amazonIon) StreamMode() StreamMode { return StreamNative }
func (s *amazonIon) NativeKind() NativeKind { return NativeReflect }
func (s *amazonIon) Supports(n string) bool { return DefaultSupports(n) }

func (s *amazonIon) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *amazonIon) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return ion.MarshalBinary(fx.Value)
}

func (s *amazonIon) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := ion.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *amazonIon) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	enc := ion.NewBinaryEncoder(cw)
	if err := enc.Encode(fx.Value); err != nil {
		return 0, err
	}
	if err := enc.Finish(); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *amazonIon) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := ion.UnmarshalFrom(ion.NewReader(r), dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
