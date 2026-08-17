package main

import "testing"

func TestCompressSizesGzipHello(t *testing.T) {
	gz, zs := compressSizes([]byte("hello"))
	if gz < 20 || gz > 40 {
		t.Fatalf("gzip(hello) size %d, want ~25", gz)
	}
	if zs == 0 {
		t.Fatal("zstd(hello) size is 0")
	}
	if zs >= gz+20 {
		t.Fatalf("zstd %d unexpectedly larger than gzip %d", zs, gz)
	}
}

func TestCompressSizesEmpty(t *testing.T) {
	gz, zs := compressSizes(nil)
	if gz != 0 || zs != 0 {
		t.Fatalf("empty: got %d %d", gz, zs)
	}
}
