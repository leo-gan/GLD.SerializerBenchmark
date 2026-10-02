package serializers

import (
	"io"

	jsonv2 "encoding/json/v2"

	"serializer-benchmark-go/model"
)

// encodingJSONV2 — Go 1.27 encoding/json/v2, measured separately from encoding/json.
//
// v2 defaults are stricter than the v1 API: invalid UTF-8 and duplicate object
// names are errors, and <, >, & are not HTML-escaped. No Options are passed;
// the row is the package defaults.
//
// Bytes use Marshal / Unmarshal. Stream uses MarshalWrite / UnmarshalRead,
// the io.Writer / io.Reader entry points in the package docs.
// https://pkg.go.dev/encoding/json/v2
// https://go.dev/doc/go1.27
// https://go.dev/doc/jsonv2-migration
type encodingJSONV2 struct {
	proto any
}

func newEncodingJSONV2() *encodingJSONV2 { return &encodingJSONV2{} }

func (s *encodingJSONV2) Name() string           { return "encoding/json/v2" }
func (s *encodingJSONV2) Version() string        { return ModuleVersion("stdlib") }
func (s *encodingJSONV2) StreamMode() StreamMode { return StreamNative }
func (s *encodingJSONV2) NativeKind() NativeKind { return NativeReflect }
func (s *encodingJSONV2) Supports(n string) bool { return DefaultSupports(n) }

func (s *encodingJSONV2) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *encodingJSONV2) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return jsonv2.Marshal(fx.Value)
}

func (s *encodingJSONV2) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := jsonv2.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *encodingJSONV2) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := jsonv2.MarshalWrite(cw, fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *encodingJSONV2) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := jsonv2.UnmarshalRead(r, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
