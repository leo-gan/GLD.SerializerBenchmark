package serializers

import (
	"encoding/json"
	"io"

	"serializer-benchmark-go/model"
)

// encodingJSON — Go standard library baseline.
// Recommended: json.Marshal / json.Unmarshal (no indent); Encoder/Decoder for streams.
// https://pkg.go.dev/encoding/json
type encodingJSON struct {
	proto any // value prototype from Prepare
}

func newEncodingJSON() *encodingJSON { return &encodingJSON{} }

func (s *encodingJSON) Name() string           { return "encoding/json" }
func (s *encodingJSON) Version() string        { return ModuleVersion("stdlib") }
func (s *encodingJSON) StreamMode() StreamMode { return StreamNative }
func (s *encodingJSON) NativeKind() NativeKind { return NativeReflect }
func (s *encodingJSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *encodingJSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *encodingJSON) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return json.Marshal(fx.Value)
}

func (s *encodingJSON) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := json.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *encodingJSON) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	enc := json.NewEncoder(cw)
	// SetEscapeHTML(false): match high-throughput JSON practice; Marshal already
	// does not HTML-escape the same way Encoder defaults do for <>& .
	enc.SetEscapeHTML(false)
	if err := enc.Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *encodingJSON) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := json.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
