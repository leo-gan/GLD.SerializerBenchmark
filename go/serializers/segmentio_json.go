package serializers

import (
	"io"

	sjson "github.com/segmentio/encoding/json"

	"serializer-benchmark-go/model"
)

// segmentioJSON — segmentio/encoding/json (high-performance fork used in production at Segment).
// Recommended: json.Marshal / json.Unmarshal from this package (same API as stdlib).
// https://github.com/segmentio/encoding
type segmentioJSON struct {
	proto any
}

func newSegmentioJSON() *segmentioJSON { return &segmentioJSON{} }

func (s *segmentioJSON) Name() string           { return "segmentio/encoding/json" }
func (s *segmentioJSON) Version() string        { return ModuleVersion("github.com/segmentio/encoding") }
func (s *segmentioJSON) StreamMode() StreamMode { return StreamNative }
func (s *segmentioJSON) NativeKind() NativeKind { return NativeReflect }
func (s *segmentioJSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *segmentioJSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *segmentioJSON) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return sjson.Marshal(fx.Value)
}

func (s *segmentioJSON) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := sjson.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *segmentioJSON) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := sjson.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *segmentioJSON) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := sjson.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
