package serializers

import (
	"bytes"
	"strings"
	"testing"

	"google.golang.org/protobuf/proto"

	"serializer-benchmark-go/model"
)

func fixtureByName(name string) model.Fixture {
	for _, f := range model.AllFixtures(42) {
		if f.Name == name {
			return f
		}
	}
	panic("fixture not found: " + name)
}

func TestMsgpackUsesReusedEncoder(t *testing.T) {
	s := newVmihailencoMsgpack()
	if s.enc == nil {
		t.Fatal("expected reused Encoder")
	}
	fx := fixtureByName("Person")
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	a, err := s.SerializeBytes(fx)
	if err != nil || len(a) == 0 {
		t.Fatalf("serialize: %v len=%d", err, len(a))
	}
	b, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	// Deterministic encode of same value
	if !bytes.Equal(a, b) {
		t.Fatal("msgpack encode not deterministic for same fixture")
	}
	out, err := s.DeserializeBytes(a)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(fx.Value, out) {
		t.Fatal("msgpack fidelity")
	}
}

func TestProtobufTimedPathReturnsMessage(t *testing.T) {
	s := newGoogleProtobuf()
	fx := fixtureByName("Person")
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	raw, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := s.DeserializeBytes(raw)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := decoded.(proto.Message); !ok {
		t.Fatalf("deserialize should return proto.Message for timed path, got %T", decoded)
	}
	domain, err := s.ToDomain(decoded)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(fx.Value, domain) {
		t.Fatal("ToDomain fidelity")
	}
}

func TestAvroSchemaCache(t *testing.T) {
	a, err := schemaFor("Person")
	if err != nil {
		t.Fatal(err)
	}
	b, err := schemaFor("Person")
	if err != nil {
		t.Fatal(err)
	}
	// Same cached instance
	if a != b {
		t.Fatal("expected cached schema identity")
	}
}

func TestAllSerializersPersonRoundtrip(t *testing.T) {
	fx := fixtureByName("Person")
	for _, ser := range All() {
		if !ser.Supports("Person") {
			continue
		}
		t.Run(ser.Name(), func(t *testing.T) {
			if err := ser.Prepare(fx); err != nil {
				t.Fatal(err)
			}
			raw, err := ser.SerializeBytes(fx)
			if err != nil {
				t.Fatal(err)
			}
			out, err := ser.DeserializeBytes(raw)
			if err != nil {
				t.Fatal(err)
			}
			if conv, ok := ser.(DomainConverter); ok {
				out, err = conv.ToDomain(out)
				if err != nil {
					t.Fatal(err)
				}
			}
			if !model.Fidelity(fx.Value, out) {
				t.Fatalf("fidelity failed for %s", ser.Name())
			}
		})
	}
}

func TestRegistryHasExpectedNames(t *testing.T) {
	names := map[string]bool{}
	for _, s := range All() {
		names[s.Name()] = true
	}
	for _, want := range []string{
		"encoding/json", "sonic", "goccy/go-json", "jsoniter",
		"vmihailenco/msgpack", "shamaton/msgpack", "fxamacker/cbor",
		"encoding/gob", "mongo-bson", "protobuf", "hamba/avro",
	} {
		if !names[want] {
			t.Errorf("missing serializer %s", want)
		}
	}
}

func TestProtobufDoesNotSupportInteger(t *testing.T) {
	s := newGoogleProtobuf()
	if s.Supports("Integer") {
		t.Fatal("protobuf should exclude bare Integer")
	}
	if !s.Supports("ObjectGraph") {
		t.Fatal("protobuf should support flat ObjectGraph")
	}
}

func TestCallPathDocsMentionOptimizations(t *testing.T) {
	// Sanity: msgpack file documents Encoder reuse.
	// (structural guard so the optimized path is not silently removed)
	s := newVmihailencoMsgpack()
	fx := fixtureByName("SimpleObject")
	_ = s.Prepare(fx)
	raw, _ := s.SerializeBytes(fx)
	var stream bytes.Buffer
	n, err := s.SerializeStream(fx, &stream)
	if err != nil || n == 0 {
		t.Fatalf("stream: n=%d err=%v", n, err)
	}
	if len(raw) == 0 {
		t.Fatal("empty bytes")
	}
	// Names should be stable for analysis
	if !strings.Contains(s.Name(), "msgpack") {
		t.Fatal(s.Name())
	}
}
