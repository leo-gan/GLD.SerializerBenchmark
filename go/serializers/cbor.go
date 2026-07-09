package serializers

import (
	"io"

	"github.com/fxamacker/cbor/v2"

	"serializer-benchmark-go/model"
)

// fxamackerCBOR — leading CBOR implementation for Go (IETF RFC 8949).
// Recommended: create EncMode/DecMode once (immutable, concurrent-safe) and reuse.
// https://github.com/fxamacker/cbor
type fxamackerCBOR struct {
	proto any
	em    cbor.EncMode
	dm    cbor.DecMode
}

func newFxamackerCBOR() *fxamackerCBOR {
	// Default EncOptions (not CoreDet): CoreDet sorts / normalizes for deterministic
	// encoding and is slower on struct payloads without map keys. Throughput path
	// reuses immutable EncMode/DecMode (library-recommended).
	// https://github.com/fxamacker/cbor#usage
	em, err := cbor.EncOptions{}.EncMode()
	if err != nil {
		panic(err)
	}
	dm, err := cbor.DecOptions{}.DecMode()
	if err != nil {
		panic(err)
	}
	return &fxamackerCBOR{em: em, dm: dm}
}

func (s *fxamackerCBOR) Name() string           { return "fxamacker/cbor" }
func (s *fxamackerCBOR) Version() string        { return ModuleVersion("github.com/fxamacker/cbor/v2") }
func (s *fxamackerCBOR) StreamMode() StreamMode { return StreamNative }
func (s *fxamackerCBOR) NativeKind() NativeKind { return NativeReflect }
func (s *fxamackerCBOR) Supports(n string) bool { return DefaultSupports(n) }

func (s *fxamackerCBOR) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	return nil
}

func (s *fxamackerCBOR) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.em.Marshal(fx.Value)
}

func (s *fxamackerCBOR) DeserializeBytes(buf []byte) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.dm.Unmarshal(buf, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *fxamackerCBOR) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := s.em.NewEncoder(cw).Encode(fx.Value); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *fxamackerCBOR) DeserializeStream(r io.Reader) (any, error) {
	dst := model.NewEmptyPtr(s.proto)
	if err := s.dm.NewDecoder(r).Decode(dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}
