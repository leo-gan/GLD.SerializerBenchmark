package v2

import (
	"strings"
	"testing"
)

func TestMakeGraphShape(t *testing.T) {
	book := MakeOne("graph", nil, 42, 0).(Book)
	if len(book.Orders) != 32 {
		t.Fatalf("orders: got %d", len(book.Orders))
	}
	if len(book.People) != 8 {
		t.Fatalf("people: got %d", len(book.People))
	}
	counts := map[*Region]int{}
	for i, order := range book.Orders {
		if order.Region == nil {
			t.Fatalf("order %d: nil region", i)
		}
		if order.Region != book.Orders[i%4].Region {
			t.Fatalf("order %d: region is not region %d", i, i%4)
		}
		if n := len(order.SKU); n < 8 || n > 16 {
			t.Fatalf("order %d: sku len %d", i, n)
		}
		if order.Qty < 1 || order.Qty > 100 {
			t.Fatalf("order %d: qty %d", i, order.Qty)
		}
		if n := len(order.Region.Code); n < 8 || n > 16 {
			t.Fatalf("region code len %d", n)
		}
		if len(order.Region.Note) != 64 {
			t.Fatalf("note len %d", len(order.Region.Note))
		}
		if order.Region.Version < 1 || order.Region.Version > 10 {
			t.Fatalf("version %d", order.Region.Version)
		}
		counts[order.Region]++
	}
	if len(counts) != 4 {
		t.Fatalf("regions: got %d", len(counts))
	}
	for region, n := range counts {
		if n != 8 {
			t.Fatalf("region %s used %d times", region.Code, n)
		}
	}
	start := book.People[0]
	node := start
	for i := 0; i < 8; i++ {
		if node == nil || node.Next == nil {
			t.Fatal("ring broke")
		}
		if n := len(node.Name); n < 8 || n > 16 {
			t.Fatalf("person name len %d", n)
		}
		if node.Next != book.People[(i+1)%8] {
			t.Fatalf("people[%d].next is not people[%d]", i, (i+1)%8)
		}
		node = node.Next
	}
	if node != start {
		t.Fatal("ring did not close")
	}

	again := MakeOne("graph", nil, 42, 0).(Book)
	if graphSig(book) != graphSig(again) {
		t.Fatal("same seed was not deterministic")
	}
	other := MakeOne("graph", nil, 42, 1).(Book)
	if graphSig(book) == graphSig(other) {
		t.Fatal("instance index did not change values")
	}
	if sharesGraphNodes(book, other) {
		t.Fatal("graphs share nodes")
	}

	_, batch := FixtureFromCell(Cell{TypeID: "graph", DataTypeInstanceCount: 2}, 42)
	books, ok := batch.([]Book)
	if !ok || len(books) != 2 {
		t.Fatalf("batch type %T", batch)
	}
	if sharesGraphNodes(books[0], books[1]) {
		t.Fatal("batch graphs share nodes")
	}

	one := MakeOne("graph", map[string]any{
		"ring_size": 1, "region_count": 1, "order_count": 2,
	}, 3, 0).(Book)
	if len(one.People) != 1 || one.People[0].Next != one.People[0] {
		t.Fatal("ring_size 1 should be a self-cycle")
	}
	if one.Orders[0].Region != one.Orders[1].Region {
		t.Fatal("single region should be shared")
	}
}

func graphSig(b Book) string {
	var sb strings.Builder
	for _, order := range b.Orders {
		sb.WriteString(order.SKU)
		sb.WriteByte('|')
		sb.WriteString(order.Region.Code)
		sb.WriteByte('|')
		sb.WriteString(order.Region.Note)
		sb.WriteByte('\n')
	}
	for _, person := range b.People {
		sb.WriteString(person.Name)
		sb.WriteByte('\n')
	}
	return sb.String()
}

func sharesGraphNodes(a, b Book) bool {
	regs := map[*Region]bool{}
	people := map[*Person]bool{}
	for _, order := range a.Orders {
		regs[order.Region] = true
	}
	for _, person := range a.People {
		people[person] = true
	}
	for _, order := range b.Orders {
		if regs[order.Region] {
			return true
		}
	}
	for _, person := range b.People {
		if people[person] {
			return true
		}
	}
	return false
}
