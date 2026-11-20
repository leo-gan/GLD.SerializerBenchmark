// MiniUser golden vectors G1–G5 (Serialization 401 lab appendix).
// Run from this directory: go run miniuser_goldens.go
//
// Teaching subset only — not production Protobuf.
package main

import (
	"encoding/hex"
	"fmt"
	"os"
)

type MiniUser struct {
	ID      uint32
	Name    string
	Manager *MiniUser
	Tags    []uint32
}

func encodeVarint(u uint64) []byte {
	var out []byte
	for u > 0x7f {
		out = append(out, byte(u&0x7f)|0x80)
		u >>= 7
	}
	return append(out, byte(u&0x7f))
}

func encodeKey(fieldNumber, wireType int) []byte {
	return encodeVarint(uint64(fieldNumber<<3 | wireType))
}

func encodeMiniUser(u MiniUser) []byte {
	var out []byte
	if u.ID != 0 {
		out = append(out, encodeKey(1, 0)...)
		out = append(out, encodeVarint(uint64(u.ID))...)
	}
	if u.Name != "" {
		b := []byte(u.Name)
		out = append(out, encodeKey(2, 2)...)
		out = append(out, encodeVarint(uint64(len(b)))...)
		out = append(out, b...)
	}
	if u.Manager != nil {
		inner := encodeMiniUser(*u.Manager)
		out = append(out, encodeKey(3, 2)...)
		out = append(out, encodeVarint(uint64(len(inner)))...)
		out = append(out, inner...)
	}
	for _, t := range u.Tags {
		out = append(out, encodeKey(4, 0)...)
		out = append(out, encodeVarint(uint64(t))...)
	}
	return out
}

func mustHex(s string) []byte {
	if s == "" {
		return nil
	}
	b, err := hex.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}

func main() {
	type caseT struct {
		label string
		user  MiniUser
		want  string // hex without spaces
	}
	cases := []caseT{
		{"G1", MiniUser{ID: 1, Name: "Ada"}, "08011203416461"},
		{"G2", MiniUser{}, ""},
		{"G3", MiniUser{ID: 300}, "08ac02"},
		{"G4", MiniUser{Tags: []uint32{1, 2}}, "20012002"},
		{"G5", MiniUser{Manager: &MiniUser{ID: 2}}, "1a020802"},
	}
	failed := false
	for _, c := range cases {
		got := encodeMiniUser(c.user)
		want := mustHex(c.want)
		if string(got) != string(want) {
			fmt.Printf("FAIL %s: got %x want %x\n", c.label, got, want)
			failed = true
		} else {
			if len(got) == 0 {
				fmt.Printf("OK %s: <empty>\n", c.label)
			} else {
				fmt.Printf("OK %s: %x\n", c.label, got)
			}
		}
	}
	if failed {
		os.Exit(1)
	}
}
