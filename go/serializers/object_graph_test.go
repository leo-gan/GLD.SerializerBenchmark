package serializers

import (
	"bytes"
	"testing"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

func columnarOnly(name string) bool {
	switch name {
	case "arrow-ipc", "parquet", "parquet-uncompressed", "sbe":
		return true
	default:
		return false
	}
}

func TestAllSerializersSupportV2Types(t *testing.T) {
	original := []string{"message", "document", "telemetry", "strings", "event"}
	for _, ser := range All() {
		if columnarOnly(ser.Name()) {
			for _, typeID := range original {
				if ser.Supports(typeID) {
					t.Errorf("%s should not support %s", ser.Name(), typeID)
				}
			}
			continue
		}
		for _, typeID := range original {
			if !ser.Supports(typeID) {
				t.Errorf("%s should support %s", ser.Name(), typeID)
			}
		}
	}
}

func TestV2TypesRoundtripBytesAndStream(t *testing.T) {
	for _, typeID := range []string{"message", "document", "telemetry", "strings", "event"} {
		typeID := typeID
		fx := model.Fixture{Name: typeID, Value: modelv2.MakeOne(typeID, nil, 42, 0)}
		t.Run(typeID, func(t *testing.T) {
			for _, ser := range All() {
				ser := ser
				if !ser.Supports(typeID) {
					continue
				}
				t.Run(ser.Name(), func(t *testing.T) {
					if err := ser.Prepare(fx); err != nil {
						t.Fatalf("prepare: %v", err)
					}
					buf, err := ser.SerializeBytes(fx)
					if err != nil {
						t.Fatalf("serialize bytes: %v", err)
					}
					if len(buf) == 0 {
						t.Fatal("empty payload")
					}
					out, err := ser.DeserializeBytes(buf)
					if err != nil {
						t.Fatalf("deserialize bytes: %v", err)
					}
					if conv, ok := ser.(DomainConverter); ok {
						out, err = conv.ToDomain(out)
						if err != nil {
							t.Fatalf("ToDomain: %v", err)
						}
					}
					if !model.Fidelity(fx.Value, out) {
						t.Fatalf("bytes fidelity failed: got %#v", out)
					}

					var stream bytes.Buffer
					n, err := ser.SerializeStream(fx, &stream)
					if err != nil {
						t.Fatalf("serialize stream: %v", err)
					}
					if n == 0 || stream.Len() == 0 {
						t.Fatal("empty stream payload")
					}
					out2, err := ser.DeserializeStream(bytes.NewReader(stream.Bytes()))
					if err != nil {
						t.Fatalf("deserialize stream: %v", err)
					}
					if conv, ok := ser.(DomainConverter); ok {
						out2, err = conv.ToDomain(out2)
						if err != nil {
							t.Fatalf("ToDomain stream: %v", err)
						}
					}
					if !model.Fidelity(fx.Value, out2) {
						t.Fatalf("stream fidelity failed: got %#v", out2)
					}
				})
			}
		})
	}
}
