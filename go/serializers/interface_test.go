package serializers

import (
	"bytes"
	"errors"
	"io"
	"testing"
)

func TestCountedWriteReportsBytesWritten(t *testing.T) {
	var buf bytes.Buffer
	n, err := countedWrite(&buf, func(w io.Writer) error {
		if _, err := w.Write([]byte("ab")); err != nil {
			return err
		}
		_, err := w.Write([]byte("c"))
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	if n != 3 || buf.String() != "abc" {
		t.Fatalf("got n=%d buf=%q", n, buf.String())
	}
}

func TestCountedWriteReportsZeroOnError(t *testing.T) {
	var buf bytes.Buffer
	n, err := countedWrite(&buf, func(w io.Writer) error {
		if _, werr := w.Write([]byte("ab")); werr != nil {
			return werr
		}
		return errors.New("boom")
	})
	if err == nil || err.Error() != "boom" || n != 0 || buf.String() != "ab" {
		t.Fatalf("n=%d err=%v buf=%q", n, err, buf.String())
	}
}
