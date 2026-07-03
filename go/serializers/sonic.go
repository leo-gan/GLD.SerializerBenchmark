package serializers

import (
	"io"

	"github.com/bytedance/sonic"

	"serializer-benchmark-go/model"
)

// sonicJSON — bytedance/sonic (SIMD-accelerated JSON, widely used at scale).
// Recommended: sonic.ConfigDefault.Marshal/Unmarshal; pretouch optional for hot types.
// Stream: sonic Encode/Decode via API or adapted bytes (we use Encode to writer when available).
// https://github.com/bytedance/sonic
type sonicJSON struct {
	proto any
	api   sonic.API
}

func newSonicJSON() *sonicJSON {
	// ConfigDefault is the recommended production config (HTML escape off for speed, etc.).
	return &sonicJSON{api: sonic.ConfigDefault}
}

func (s *sonicJSON) Name() string           { return "sonic" }
func (s *sonicJSON) Version() string        { return "1" }
func (s *sonicJSON) StreamMode() StreamMode { return StreamNative }
func (s *sonicJSON) NativeKind() NativeKind { return NativeReflect }
func (s *sonicJSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *sonicJSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	// Pretouch compiles type-specialized encoder/decoder (recommended for hot paths).
	_ = sonic.Pretouch(typeOf(fx.Value))
	return nil
}

func (s *sonicJSON) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.api.Marshal(fx.Value)
}

func (s *sonicJSON) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.api.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *sonicJSON) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := s.api.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *sonicJSON) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.api.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
