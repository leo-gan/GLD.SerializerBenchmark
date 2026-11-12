package serializers

import (
	"io"

	toongo "github.com/toon-format/toon-go"

	"serializer-benchmark-go/model"
)

// toonGo encodes the JSON data model as TOON text.
// The encoder is reused. Marshal and Unmarshal are the library's byte API,
// so the stream path writes that buffer. Size is the UTF-8 length.
// https://github.com/toon-format/toon-go
type toonGo struct {
	proto any
	enc   *toongo.Encoder
}

func newToonGo() *toonGo {
	return &toonGo{enc: toongo.NewEncoder()}
}

func (s *toonGo) Name() string           { return "toon-go" }
func (s *toonGo) Version() string        { return ModuleVersion("github.com/toon-format/toon-go") }
func (s *toonGo) StreamMode() StreamMode { return StreamAdapted }
func (s *toonGo) NativeKind() NativeKind { return NativeReflect }
func (s *toonGo) Supports(n string) bool { return DefaultSupports(n) }

func (s *toonGo) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *toonGo) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.enc.Marshal(fx.Value)
}

func (s *toonGo) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := toongo.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *toonGo) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *toonGo) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}
