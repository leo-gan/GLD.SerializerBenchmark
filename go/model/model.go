// Package model holds runner fixtures and fidelity helpers for the Go serializer harness.
// Payload types live in model/v2 (Data Model v2).
package model

import "reflect"

// Fixture is one named payload used by the runner.
type Fixture struct {
	Name  string
	Value any
}

// Fidelity checks semantic equality (structural DeepEqual for v2 types).
func Fidelity(expected, actual any) bool {
	return reflect.DeepEqual(expected, actual)
}

// NewEmptyPtr allocates a pointer to a zero value of the same concrete type as v.
// Uses reflection so Data Model v2 structs/slices work without a switch per type.
func NewEmptyPtr(v any) any {
	if v == nil {
		return nil
	}
	t := reflect.TypeOf(v)
	if t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	return reflect.New(t).Interface()
}

// Deref converts an unmarshal target pointer back to a value.
func Deref(ptr any) any {
	if ptr == nil {
		return nil
	}
	rv := reflect.ValueOf(ptr)
	if rv.Kind() == reflect.Ptr {
		return rv.Elem().Interface()
	}
	return ptr
}
