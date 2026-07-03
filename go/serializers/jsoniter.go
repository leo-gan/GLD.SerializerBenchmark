package serializers

import (
	"io"

	jsoniter "github.com/json-iterator/go"

	"serializer-benchmark-go/model"
)

// jsonIter — json-iterator/go (ConfigCompatibleWithStandardLibrary is the recommended
// drop-in for encoding/json semantics).
// https://github.com/json-iterator/go
type jsonIter struct {
	proto any
	api   jsoniter.API
}

func newJSONIter() *jsonIter {
	return &jsonIter{api: jsoniter.ConfigCompatibleWithStandardLibrary}
}

func (s *jsonIter) Name() string           { return "jsoniter" }
func (s *jsonIter) Version() string        { return "1" }
func (s *jsonIter) StreamMode() StreamMode { return StreamNative }
func (s *jsonIter) NativeKind() NativeKind { return NativeReflect }
func (s *jsonIter) Supports(n string) bool { return DefaultSupports(n) }

func (s *jsonIter) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *jsonIter) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.api.Marshal(fx.Value)
}

func (s *jsonIter) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.api.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *jsonIter) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := s.api.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *jsonIter) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.api.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
