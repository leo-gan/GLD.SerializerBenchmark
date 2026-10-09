package serializers

import (
	"bytes"
	"testing"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

func TestGraphSupportsOnlyDagrArena(t *testing.T) {
	for _, ser := range All() {
		got := ser.Supports("graph")
		want := ser.Name() == "dagr-regular" || ser.Name() == "dagr-frozen"
		if got != want {
			t.Errorf("%s Supports(graph)=%v, want %v", ser.Name(), got, want)
		}
	}
}

func TestDagrSupportsSuiteNotColumnar(t *testing.T) {
	for _, ser := range []BenchSerializer{newDagr(), newDagrRegular(), newDagrFrozen(), newDagrFrozenPacked()} {
		for _, id := range []string{"message", "document", "telemetry", "strings", "event"} {
			if !ser.Supports(id) {
				t.Errorf("%s should support %s", ser.Name(), id)
			}
		}
		for _, id := range []string{"table", "table_project", "nested_table", "signal"} {
			if ser.Supports(id) {
				t.Errorf("%s should not support %s", ser.Name(), id)
			}
		}
	}
}

func TestDagrGraphRoundTrip(t *testing.T) {
	books := make([]modelv2.Book, 2)
	for i := range books {
		books[i] = modelv2.MakeOne("graph", nil, 42, i).(modelv2.Book)
	}
	ring1 := modelv2.MakeOne("graph", map[string]any{
		"ring_size": 1, "region_count": 1, "order_count": 4,
	}, 7, 0).(modelv2.Book)
	cases := []model.Fixture{
		{Name: "graph", Value: books[0]},
		{Name: "graph", Value: books},
		{Name: "graph", Value: ring1},
	}
	for _, ser := range []BenchSerializer{newDagrRegular(), newDagrFrozen()} {
		ser := ser
		t.Run(ser.Name(), func(t *testing.T) {
			for _, fx := range cases {
				fx := fx
				if err := ser.Prepare(fx); err != nil {
					t.Fatalf("prepare: %v", err)
				}
				buf, err := ser.SerializeBytes(fx)
				if err != nil {
					t.Fatalf("serialize: %v", err)
				}
				out, err := ser.DeserializeBytes(buf)
				if err != nil {
					t.Fatalf("deserialize: %v", err)
				}
				if !model.Fidelity(fx.Value, out) {
					t.Fatalf("fidelity failed: %#v", out)
				}
				assertDecodedGraph(t, out)
				var stream bytes.Buffer
				if _, err := ser.SerializeStream(fx, &stream); err != nil {
					t.Fatalf("serialize stream: %v", err)
				}
				out, err = ser.DeserializeStream(bytes.NewReader(stream.Bytes()))
				if err != nil {
					t.Fatalf("deserialize stream: %v", err)
				}
				if !model.Fidelity(fx.Value, out) {
					t.Fatal("stream fidelity failed")
				}
				assertDecodedGraph(t, out)
			}
		})
	}
}

func assertDecodedGraph(t *testing.T, out any) {
	t.Helper()
	switch v := out.(type) {
	case modelv2.Book:
		assertBookIdentity(t, v)
	case []modelv2.Book:
		if len(v) < 2 {
			t.Fatalf("batch len %d", len(v))
		}
		for i := range v {
			assertBookIdentity(t, v[i])
		}
		if sharesDecodedRegion(v[0], v[1]) {
			t.Fatal("decoded batch shares a region")
		}
	default:
		t.Fatalf("decoded %T", out)
	}
}

func assertBookIdentity(t *testing.T, b modelv2.Book) {
	t.Helper()
	if len(b.Orders) == 0 || len(b.People) == 0 {
		t.Fatalf("empty graph: %d orders %d people", len(b.Orders), len(b.People))
	}
	regs := map[*modelv2.Region]int{}
	for i, order := range b.Orders {
		if order.Region == nil {
			t.Fatalf("order %d: nil region", i)
		}
		if len(order.Region.Note) != 64 {
			t.Fatalf("note len %d", len(order.Region.Note))
		}
		regs[order.Region]++
	}
	// Defaults are 4 regions × 8. Smaller configs still share when several orders name one region.
	if len(b.Orders) > len(regs) {
		for _, n := range regs {
			if n < 2 {
				t.Fatal("shared region was copied")
			}
		}
	}
	n := len(b.People)
	for i, person := range b.People {
		if person == nil || person.Next != b.People[(i+1)%n] {
			t.Fatalf("people[%d].next broke the ring", i)
		}
	}
}

func sharesDecodedRegion(a, b modelv2.Book) bool {
	seen := map[*modelv2.Region]bool{}
	for _, order := range a.Orders {
		seen[order.Region] = true
	}
	for _, order := range b.Orders {
		if seen[order.Region] {
			return true
		}
	}
	return false
}
