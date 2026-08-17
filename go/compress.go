package main

import (
	"bytes"
	"compress/gzip"

	"github.com/klauspost/compress/zstd"
)

// compressSizes returns one-shot gzip(6) and zstd(3) lengths of raw.
// Not on the timed path. Empty input or a codec error yields 0.
func compressSizes(raw []byte) (gz, zs int) {
	if len(raw) == 0 {
		return 0, 0
	}
	var buf bytes.Buffer
	w, err := gzip.NewWriterLevel(&buf, 6)
	if err != nil {
		return 0, 0
	}
	if _, err := w.Write(raw); err != nil {
		_ = w.Close()
		return 0, 0
	}
	if err := w.Close(); err != nil {
		return 0, 0
	}
	gz = buf.Len()

	enc, err := zstd.NewWriter(nil, zstd.WithEncoderLevel(zstd.EncoderLevelFromZstd(3)))
	if err == nil {
		zs = len(enc.EncodeAll(raw, nil))
		_ = enc.Close()
	}
	return gz, zs
}
