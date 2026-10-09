package model

import modelv2 "serializer-benchmark-go/model/v2"

// graphFidelity reports whether expected is a graph value (one Book or a batch).
// Each book is compared on its own: nodes are not shared across books.
// A second visit must land on the same pointer on the other side, so a copied
// region or a broken person ring fails even when the field values match.
func graphFidelity(expected, actual any) (equal bool, matched bool) {
	if book, ok := bookOf(expected); ok {
		other, ok := bookOf(actual)
		if !ok {
			return false, true
		}
		return booksEqual(book, other), true
	}
	batch, ok := expected.([]modelv2.Book)
	if !ok {
		return false, false
	}
	other, ok := actual.([]modelv2.Book)
	if !ok || len(batch) != len(other) {
		return false, true
	}
	for i := range batch {
		if !booksEqual(batch[i], other[i]) {
			return false, true
		}
	}
	return true, true
}

func bookOf(v any) (modelv2.Book, bool) {
	switch t := v.(type) {
	case modelv2.Book:
		return t, true
	case *modelv2.Book:
		if t == nil {
			return modelv2.Book{}, false
		}
		return *t, true
	default:
		return modelv2.Book{}, false
	}
}

func booksEqual(a, b modelv2.Book) bool {
	if len(a.Orders) != len(b.Orders) || len(a.People) != len(b.People) {
		return false
	}
	m := graphMemo{
		aReg: map[*modelv2.Region]int{},
		bReg: map[*modelv2.Region]int{},
		aPer: map[*modelv2.Person]int{},
		bPer: map[*modelv2.Person]int{},
	}
	for i := range a.Orders {
		if a.Orders[i].SKU != b.Orders[i].SKU || a.Orders[i].Qty != b.Orders[i].Qty {
			return false
		}
		if !m.region(a.Orders[i].Region, b.Orders[i].Region) {
			return false
		}
	}
	for i := range a.People {
		if !m.person(a.People[i], b.People[i]) {
			return false
		}
	}
	return true
}

type graphMemo struct {
	aReg map[*modelv2.Region]int
	bReg map[*modelv2.Region]int
	aPer map[*modelv2.Person]int
	bPer map[*modelv2.Person]int
}

func (m graphMemo) region(a, b *modelv2.Region) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	idA, seenA := m.aReg[a]
	idB, seenB := m.bReg[b]
	if seenA || seenB {
		return seenA && seenB && idA == idB
	}
	token := len(m.aReg)
	m.aReg[a] = token
	m.bReg[b] = token
	return a.Code == b.Code && a.Note == b.Note && a.Version == b.Version
}

func (m graphMemo) person(a, b *modelv2.Person) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	idA, seenA := m.aPer[a]
	idB, seenB := m.bPer[b]
	if seenA || seenB {
		return seenA && seenB && idA == idB
	}
	token := len(m.aPer)
	m.aPer[a] = token
	m.bPer[b] = token
	if a.Name != b.Name {
		return false
	}
	return m.person(a.Next, b.Next)
}
