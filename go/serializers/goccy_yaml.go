package serializers

import (
	"io"

	"github.com/goccy/go-yaml"

	"serializer-benchmark-go/model"
)

// goccyYAML — high-performance YAML (same author family as goccy/go-json).
// Recommended: yaml.Marshal / Unmarshal (no pretty options); Encoder/Decoder for streams.
// https://github.com/goccy/go-yaml
type goccyYAML struct {
	proto any
}

func newGoccyYAML() *goccyYAML { return &goccyYAML{} }

func (s *goccyYAML) Name() string           { return "goccy/go-yaml" }
func (s *goccyYAML) Version() string        { return ModuleVersion("github.com/goccy/go-yaml") }
func (s *goccyYAML) StreamMode() StreamMode { return StreamNative }
func (s *goccyYAML) NativeKind() NativeKind { return NativeReflect }
func (s *goccyYAML) Supports(n string) bool { return DefaultSupports(n) }

func (s *goccyYAML) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *goccyYAML) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return yaml.Marshal(fx.Value)
}

func (s *goccyYAML) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := yaml.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *goccyYAML) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	enc := yaml.NewEncoder(cw)
	if err := enc.Encode(fx.Value); err != nil {
		_ = enc.Close()
		return 0, err
	}
	if err := enc.Close(); err != nil {
		return cw.n, err
	}
	return cw.n, nil
}

func (s *goccyYAML) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := yaml.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
