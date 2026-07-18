package model

import (
	"testing"

	modelv2 "serializer-benchmark-go/model/v2"
)

func TestFidelityMessage(t *testing.T) {
	m := modelv2.MakeOne("message", nil, 42, 0).(modelv2.Message)
	if !Fidelity(m, m) {
		t.Fatal("self-fidelity failed")
	}
	other := m
	other.FString = m.FString + "x"
	if Fidelity(m, other) {
		t.Fatal("expected mismatch")
	}
}

func TestNewEmptyPtrMessage(t *testing.T) {
	m := modelv2.MakeOne("message", nil, 42, 0).(modelv2.Message)
	ptr := NewEmptyPtr(m)
	if _, ok := ptr.(*modelv2.Message); !ok {
		t.Fatalf("got %T", ptr)
	}
	d, ok := Deref(ptr).(modelv2.Message)
	if !ok {
		t.Fatalf("deref %T", Deref(ptr))
	}
	if d.FString != "" || d.FInt32 != 0 {
		t.Fatalf("empty not zero: %+v", d)
	}
}

func TestNewEmptyPtrSlice(t *testing.T) {
	s := []modelv2.Message{{FInt32: 1}}
	ptr := NewEmptyPtr(s)
	ps, ok := ptr.(*[]modelv2.Message)
	if !ok {
		t.Fatalf("got %T", ptr)
	}
	if len(*ps) != 0 {
		t.Fatalf("want empty slice, got %d", len(*ps))
	}
}
