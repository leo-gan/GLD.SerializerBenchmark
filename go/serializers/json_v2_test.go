package serializers

import (
	"bytes"
	"encoding/json"
	jsonv2 "encoding/json/v2"
	"testing"

	"serializer-benchmark-go/model"
)

// Go 1.27 keeps v1 semantics on encoding/json and puts the stricter defaults
// on encoding/json/v2. https://go.dev/doc/go1.27
func TestEncodingJSONV2DefaultsDifferFromV1(t *testing.T) {
	dup := []byte(`{"a":1,"a":2}`)
	var v any
	if err := json.Unmarshal(dup, &v); err != nil {
		t.Fatalf("encoding/json duplicate names: %v", err)
	}
	if err := jsonv2.Unmarshal(dup, &v); err == nil {
		t.Fatal("encoding/json/v2 accepted duplicate object names")
	}

	bad := []byte("{\"a\":\"\xff\"}")
	if err := json.Unmarshal(bad, &v); err != nil {
		t.Fatalf("encoding/json invalid UTF-8: %v", err)
	}
	if err := jsonv2.Unmarshal(bad, &v); err == nil {
		t.Fatal("encoding/json/v2 accepted invalid UTF-8")
	}
}

func TestEncodingJSONV2RoundTrip(t *testing.T) {
	s := newEncodingJSONV2()
	for _, id := range []string{"message", "document", "telemetry", "strings", "event"} {
		t.Run(id, func(t *testing.T) {
			fx := v2Fixture(id)
			if err := s.Prepare(fx); err != nil {
				t.Fatal(err)
			}
			raw, err := s.SerializeBytes(fx)
			if err != nil {
				t.Fatal(err)
			}
			out, err := s.DeserializeBytes(raw)
			if err != nil {
				t.Fatal(err)
			}
			if !model.Fidelity(fx.Value, out) {
				t.Fatal("bytes fidelity")
			}
			var buf bytes.Buffer
			n, err := s.SerializeStream(fx, &buf)
			if err != nil || n == 0 {
				t.Fatalf("stream ser n=%d err=%v", n, err)
			}
			out, err = s.DeserializeStream(&buf)
			if err != nil {
				t.Fatal(err)
			}
			if !model.Fidelity(fx.Value, out) {
				t.Fatal("stream fidelity")
			}
		})
	}
}
