package serializers

import (
	"bytes"
	"encoding/gob"
	"io"

	"serializer-benchmark-go/model"
)

// encodingGob — Go-native binary format (stdlib encoding/gob).
// Recommended: register types once; reuse Encoder/Decoder on streams; for bytes use buffer.
// https://pkg.go.dev/encoding/gob
type encodingGob struct {
	proto any
}

func newEncodingGob() *encodingGob {
	// Register concrete types once at construction (recommended).
	gob.Register(model.Person{})
	gob.Register(model.IntegerValue{})
	gob.Register(model.TelemetryData{})
	gob.Register(model.SimpleObject{})
	gob.Register(model.StringArrayObject{})
	gob.Register(model.Edi835{})
	gob.Register(model.Passport{})
	gob.Register(model.PoliceRecord{})
	gob.Register(model.Claim{})
	gob.Register(model.ServiceLine{})
	return &encodingGob{}
}

func (s *encodingGob) Name() string           { return "encoding/gob" }
func (s *encodingGob) Version() string        { return "stdlib" }
func (s *encodingGob) StreamMode() StreamMode { return StreamNative }
func (s *encodingGob) NativeKind() NativeKind { return NativeReflect }
func (s *encodingGob) Supports(n string) bool { return DefaultSupports(n) }

func (s *encodingGob) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *encodingGob) SerializeBytes(fx model.Fixture) ([]byte, error) {
	var buf bytes.Buffer
	if err := gob.NewEncoder(&buf).Encode(fx.Value); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (s *encodingGob) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := gob.NewDecoder(bytes.NewReader(buf)).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *encodingGob) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := gob.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *encodingGob) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := gob.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
