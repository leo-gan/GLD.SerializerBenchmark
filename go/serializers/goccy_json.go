package serializers

import (
	"io"

	gojson "github.com/goccy/go-json"

	"serializer-benchmark-go/model"
)

// goccyJSON — goccy/go-json (fast drop-in encoding/json alternative).
// Recommended: gojson.Marshal / gojson.Unmarshal; Encoder/Decoder for streams.
// https://github.com/goccy/go-json
type goccyJSON struct {
	proto any
}

func newGoccyJSON() *goccyJSON { return &goccyJSON{} }

func (s *goccyJSON) Name() string           { return "goccy/go-json" }
func (s *goccyJSON) Version() string        { return "0.10" }
func (s *goccyJSON) StreamMode() StreamMode { return StreamNative }
func (s *goccyJSON) NativeKind() NativeKind { return NativeReflect }
func (s *goccyJSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *goccyJSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *goccyJSON) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return gojson.Marshal(fx.Value)
}

func (s *goccyJSON) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := gojson.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *goccyJSON) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := gojson.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *goccyJSON) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := gojson.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
