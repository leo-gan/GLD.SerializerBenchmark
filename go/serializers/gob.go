package serializers

import (
	"bytes"
	"encoding/gob"
	"io"

	"serializer-benchmark-go/data"
)

// encodingGob — Go-native binary format (stdlib encoding/gob).
// Recommended: register types once; reuse Encoder/Decoder on streams; for bytes use buffer.
// https://pkg.go.dev/encoding/gob
type encodingGob struct {
	proto any
}

func newEncodingGob() *encodingGob {
	// Register concrete types once at construction (recommended).
	gob.Register(data.Person{})
	gob.Register(data.IntegerValue{})
	gob.Register(data.TelemetryData{})
	gob.Register(data.SimpleObject{})
	gob.Register(data.StringArrayObject{})
	gob.Register(data.Edi835{})
	gob.Register(data.Passport{})
	gob.Register(data.PoliceRecord{})
	gob.Register(data.Claim{})
	gob.Register(data.ServiceLine{})
	return &encodingGob{}
}

func (s *encodingGob) Name() string           { return "encoding/gob" }
func (s *encodingGob) Version() string        { return "stdlib" }
func (s *encodingGob) StreamMode() StreamMode { return StreamNative }
func (s *encodingGob) NativeKind() NativeKind { return NativeReflect }
func (s *encodingGob) Supports(n string) bool { return DefaultSupports(n) }

func (s *encodingGob) Prepare(fx data.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *encodingGob) SerializeBytes(fx data.Fixture) ([]byte, error) {
	var buf bytes.Buffer
	if err := gob.NewEncoder(&buf).Encode(fx.Value); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (s *encodingGob) DeserializeBytes(buf []byte) (any, error) {
	dst := data.NewEmptyPtr(s.proto)
	if err := gob.NewDecoder(bytes.NewReader(buf)).Decode(dst); err != nil {
		return nil, err
	}
	return data.Deref(dst), nil
}

func (s *encodingGob) SerializeStream(fx data.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := gob.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *encodingGob) DeserializeStream(r io.Reader) (any, error) {
	dst := data.NewEmptyPtr(s.proto)
	if err := gob.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return data.Deref(dst), nil
}
