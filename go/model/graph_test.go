package model

import (
	"testing"

	modelv2 "serializer-benchmark-go/model/v2"
)

func TestGraphFidelity(t *testing.T) {
	a := modelv2.MakeOne("graph", nil, 42, 0).(modelv2.Book)
	b := modelv2.MakeOne("graph", nil, 42, 0).(modelv2.Book)
	if !Fidelity(a, b) {
		t.Fatal("deterministic graphs should match")
	}
	if !Fidelity(&a, b) {
		t.Fatal("pointer and value should match")
	}
	other := modelv2.MakeOne("graph", nil, 42, 1).(modelv2.Book)
	if Fidelity(a, other) {
		t.Fatal("different instance should not match")
	}
	if !Fidelity(a, aliasGraph(a)) {
		t.Fatal("alias copy should match")
	}
	if Fidelity(a, dupRegions(a)) {
		t.Fatal("duplicated regions should not match")
	}
	broken := aliasGraph(a)
	broken.People[0].Next = &modelv2.Person{Name: broken.People[1].Name}
	if Fidelity(a, broken) {
		t.Fatal("broken ring should not match")
	}
	changed := aliasGraph(a)
	changed.Orders[0].Qty++
	if Fidelity(a, changed) {
		t.Fatal("field mismatch should not match")
	}
	changed = aliasGraph(a)
	changed.Orders[3].Region.Note = changed.Orders[3].Region.Note[:63] + "x"
	if Fidelity(a, changed) {
		t.Fatal("shared region field mismatch should not match")
	}

	one := modelv2.MakeOne("graph", map[string]any{
		"ring_size": 1, "region_count": 1, "order_count": 2,
	}, 9, 0).(modelv2.Book)
	if !Fidelity(one, aliasGraph(one)) {
		t.Fatal("self-cycle should match an alias copy")
	}

	batchA := []modelv2.Book{a, other}
	batchB := []modelv2.Book{
		modelv2.MakeOne("graph", nil, 42, 0).(modelv2.Book),
		modelv2.MakeOne("graph", nil, 42, 1).(modelv2.Book),
	}
	if !Fidelity(batchA, batchB) {
		t.Fatal("batch should match")
	}
	batchB[0] = dupRegions(batchB[0])
	if Fidelity(batchA, batchB) {
		t.Fatal("duplicated region in a batch should not match")
	}
}

func aliasGraph(b modelv2.Book) modelv2.Book {
	regs := map[*modelv2.Region]*modelv2.Region{}
	orders := make([]modelv2.Order, len(b.Orders))
	for i, order := range b.Orders {
		reg := regs[order.Region]
		if reg == nil {
			reg = &modelv2.Region{Code: order.Region.Code, Note: order.Region.Note, Version: order.Region.Version}
			regs[order.Region] = reg
		}
		orders[i] = modelv2.Order{SKU: order.SKU, Qty: order.Qty, Region: reg}
	}
	people := make([]*modelv2.Person, len(b.People))
	back := map[*modelv2.Person]*modelv2.Person{}
	for i, person := range b.People {
		people[i] = &modelv2.Person{Name: person.Name}
		back[person] = people[i]
	}
	for i, person := range b.People {
		people[i].Next = back[person.Next]
	}
	return modelv2.Book{Orders: orders, People: people}
}

func dupRegions(b modelv2.Book) modelv2.Book {
	out := aliasGraph(b)
	for i, order := range out.Orders {
		out.Orders[i].Region = &modelv2.Region{
			Code: order.Region.Code, Note: order.Region.Note, Version: order.Region.Version,
		}
	}
	return out
}
