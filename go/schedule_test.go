package main

import "testing"

func TestGoldenPermutation(t *testing.T) {
	seed := deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0)
	if seed != 15992650003647724414 {
		t.Fatalf("seed %d", seed)
	}
	p := fisherYatesStrings([]string{"A", "B", "C"}, seed)
	if p[0] != "C" || p[1] != "B" || p[2] != "A" {
		t.Fatalf("perm %v", p)
	}
}
