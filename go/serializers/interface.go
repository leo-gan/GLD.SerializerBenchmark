// Package serializers implements the prepare/timed call-path contract for Go libraries.
package serializers

import (
	"io"

	"serializer-benchmark-go/data"
)

// StreamMode documents how stream I/O is implemented.
type StreamMode int

const (
	StreamAdapted StreamMode = iota
	StreamNative
)

func (m StreamMode) String() string {
	if m == StreamNative {
		return "native"
	}
	return "adapted"
}

// NativeKind documents what the timed path primarily operates on.
type NativeKind int

const (
	NativeReflect NativeKind = iota
	NativeMessage
	NativeSchema
)

func (k NativeKind) String() string {
	switch k {
	case NativeMessage:
		return "message"
	case NativeSchema:
		return "schema"
	default:
		return "reflect"
	}
}

// BenchSerializer is the Python/Rust-aligned contract.
type BenchSerializer interface {
	Name() string
	Version() string
	StreamMode() StreamMode
	NativeKind() NativeKind
	Supports(testDataName string) bool
	Prepare(fx data.Fixture) error
	SerializeBytes(fx data.Fixture) ([]byte, error)
	DeserializeBytes(data []byte) (any, error)
	SerializeStream(fx data.Fixture, w io.Writer) (int, error)
	DeserializeStream(r io.Reader) (any, error)
}

func DefaultSupports(testDataName string) bool {
	return testDataName != "ObjectGraph"
}

func AdaptedSerializeStream(s BenchSerializer, fx data.Fixture, w io.Writer) (int, error) {
	b, err := s.SerializeBytes(fx)
	if err != nil {
		return 0, err
	}
	n, err := w.Write(b)
	return n, err
}

func AdaptedDeserializeStream(s BenchSerializer, r io.Reader) (any, error) {
	b, err := io.ReadAll(r)
	if err != nil {
		return nil, err
	}
	return s.DeserializeBytes(b)
}

type countWriter struct {
	w io.Writer
	n int
}

func (c *countWriter) Write(p []byte) (int, error) {
	n, err := c.w.Write(p)
	c.n += n
	return n, err
}
