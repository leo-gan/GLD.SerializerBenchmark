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
	// Throughput path reuses immutable EncMode/DecMode (library-recommended).
	// https://github.com/fxamacker/cbor#quick-start

	// fxamacker/cbor provides struct tag options `toarray` or `keyasint` to
	// improve speed and reduce encoded size.
	// To take effect, `toarray` or `keyasint` needs to be added to the Go structs
	// in this benchmark's fixture file (model/v2/generate.go).
	// See how to use struct tag options at:
	// https://github.com/fxamacker/cbor#smaller-encodings-with-struct-tag-options

	// fxamacker/cbor encodes structs faster than Go maps because struct keys
	// and their sort order are cached per type, while map keys are encoded and
	// sorted every time.

	// Deterministic encoding isn't required in the benchmarks, so the
	// default encoding option is used instead of cbor.CoreDetEncOptions.
	em, err := cbor.EncOptions{}.EncMode()
	if err != nil {
		panic(err)
	}

	// For untrusted input, the default option validates UTF-8 strings. All the
	// generated fixtures are valid UTF-8, so the default option isn't used here.
	dm, err := cbor.DecOptions{UTF8: cbor.UTF8DecodeInvalid}.DecMode()
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
