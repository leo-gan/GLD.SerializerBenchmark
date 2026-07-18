package serializers

import (
	"bytes"
	"encoding/gob"
	"io"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// encodingGob — Go-native binary format (stdlib encoding/gob).
// Recommended: register types once; each independent payload needs NewEncoder
// (type headers); reuse the backing Buffer with Reset to cut allocs.
// https://pkg.go.dev/encoding/gob
type encodingGob struct {
	proto any
	buf   bytes.Buffer
}

func newEncodingGob() *encodingGob {
	// Register concrete Data Model v2 types once at construction (recommended).
	gob.Register(modelv2.Message{})
	gob.Register(modelv2.Document{})
	gob.Register(modelv2.DocumentMeta{})
	gob.Register(modelv2.DocumentItem{})
	gob.Register(modelv2.Telemetry{})
	gob.Register(modelv2.Strings{})
	gob.Register(modelv2.Event{})
	gob.Register(modelv2.EventAttr{})
	return &encodingGob{}
}

func (s *encodingGob) Name() string           { return "encoding/gob" }
func (s *encodingGob) Version() string        { return ModuleVersion("stdlib") }
func (s *encodingGob) StreamMode() StreamMode { return StreamNative }
func (s *encodingGob) NativeKind() NativeKind { return NativeReflect }
func (s *encodingGob) Supports(n string) bool { return DefaultSupports(n) }

func (s *encodingGob) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.buf.Reset()
	return nil
}

func (s *encodingGob) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.buf.Reset()
	if err := gob.NewEncoder(&s.buf).Encode(fx.Value); err != nil {
		return nil, err
	}
	out := make([]byte, s.buf.Len())
	copy(out, s.buf.Bytes())
	return out, nil
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
