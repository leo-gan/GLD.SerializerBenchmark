package serializers

import (
	"bytes"
	"testing"

	"serializer-benchmark-go/model"
)

func TestAllSerializersSupportObjectGraph(t *testing.T) {
	for _, ser := range All() {
		if !ser.Supports("ObjectGraph") {
			t.Errorf("%s should support ObjectGraph", ser.Name())
		}
	}
}

func TestObjectGraphRoundtripBytesAndStream(t *testing.T) {
	fx := model.Fixture{Name: "ObjectGraph", Value: model.AllFixtures(42)[len(model.AllFixtures(42))-1].Value}
	// Prefer explicit graph
	g := model.AllFixtures(42)
	var og model.ObjectGraph
	for _, f := range g {
		if f.Name == "ObjectGraph" {
			og = f.Value.(model.ObjectGraph)
			fx = f
			break
		}
	}
	_ = og

	for _, ser := range All() {
		ser := ser
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
}

func TestPersonStillRoundtrips(t *testing.T) {
	var fx model.Fixture
	for _, f := range model.AllFixtures(42) {
		if f.Name == "Person" {
			fx = f
			break
		}
	}
	for _, ser := range All() {
		if !ser.Supports("Person") {
			continue
		}
		if err := ser.Prepare(fx); err != nil {
			t.Fatalf("%s prepare: %v", ser.Name(), err)
		}
		buf, err := ser.SerializeBytes(fx)
		if err != nil {
			t.Fatalf("%s ser: %v", ser.Name(), err)
		}
		out, err := ser.DeserializeBytes(buf)
		if err != nil {
			t.Fatalf("%s deser: %v", ser.Name(), err)
		}
		if conv, ok := ser.(DomainConverter); ok {
			out, err = conv.ToDomain(out)
			if err != nil {
				t.Fatalf("%s ToDomain: %v", ser.Name(), err)
			}
		}
		if !model.Fidelity(fx.Value, out) {
			t.Fatalf("%s person fidelity", ser.Name())
		}
	}
}
