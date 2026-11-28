package serializers

import (
	"bytes"
	"testing"
	"time"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

func TestGldKilnAsmSupportsAndVersion(t *testing.T) {
	s := newGldKilnAsm()
	if s.Name() != "gld-kiln-asm" {
		t.Fatalf("name=%q", s.Name())
	}
	if s.Version() != "0.2.0" {
		t.Fatalf("version=%q want 0.2.0", s.Version())
	}
	if s.StreamMode() != StreamAdapted || s.NativeKind() != NativeSchema {
		t.Fatalf("mode=%v kind=%v", s.StreamMode(), s.NativeKind())
	}
	for _, id := range []string{
		"message", "document", "telemetry", "strings", "event",
		"table", "table_project", "nested_table", "signal",
		"tensor", "tensor_view", "prompt", "shard", "request",
	} {
		if !s.Supports(id) {
			t.Fatalf("should support %s", id)
		}
	}
	if s.Supports("graph") || s.Supports("grid") {
		t.Fatal("should not support graph or grid in Go")
	}
}

func TestGldKilnAsmAllRoundtrips(t *testing.T) {
	s := newGldKilnAsm()
	for _, id := range []string{"message", "document", "telemetry", "strings", "event", "table", "table_project", "nested_table", "signal"} {
		for _, n := range []int{1, 100} {
			fx := v2Cell(id, n)
			t.Run(id, func(t *testing.T) {
				checkRoundTrip(t, s, fx)
			})
		}
	}

	small := map[string]any{
		"rows": float64(4), "cols": float64(4),
		"batch": float64(2), "seq": float64(8), "vocab": float64(32),
		"hidden": float64(4), "ffn": float64(6),
		"string_len": map[string]any{"min": float64(3), "max": float64(6)},
	}
	for _, id := range []string{"tensor", "tensor_view", "prompt", "shard", "request"} {
		fx := model.Fixture{Name: id, Value: modelv2.MakeOne(id, small, 9, 1)}
		t.Run(id, func(t *testing.T) {
			checkRoundTrip(t, s, fx)
		})
	}
}

func TestGldKilnAsmTensorViewBorrowsWire(t *testing.T) {
	s := newGldKilnAsm()
	small := map[string]any{"rows": float64(4), "cols": float64(4)}
	fx := model.Fixture{Name: "tensor_view", Value: modelv2.MakeOne("tensor_view", small, 9, 1)}
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	raw, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	wire := append([]byte(nil), raw...)
	out, err := s.DeserializeBytes(wire)
	if err != nil {
		t.Fatal(err)
	}
	view, ok := out.(tensorView)
	if !ok || len(view.Payload) != 4*4*4 {
		t.Fatalf("unexpected view %T len=%d", out, len(view.Payload))
	}
	// Payload must alias wire (KLNT v2 payload starts at offset >= 16 inside wire).
	idx := bytes.Index(wire, view.Payload)
	if idx < 0 || &view.Payload[0] != &wire[idx] {
		t.Fatalf("tensor_view copied instead of borrowing wire (idx=%d)", idx)
	}
	wire[idx] ^= 0xff
	dom, err := s.ToDomain(out)
	if err != nil {
		t.Fatal(err)
	}
	if model.Fidelity(fx.Value, dom) {
		t.Fatal("tensor_view did not alias wire bytes")
	}
	wire[idx] ^= 0xff
	dom, err = s.ToDomain(out)
	if err != nil || !model.Fidelity(fx.Value, dom) {
		t.Fatalf("fidelity after restore: %v", err)
	}
	wire[idx] ^= 0xff
	if !model.Fidelity(fx.Value, dom) {
		t.Fatal("ToDomain aliased wire bytes")
	}
}

func TestGldKilnAsmTableProjectionFasterThanFull(t *testing.T) {
	s := newGldKilnAsm()
	fx := v2Cell("table", 10000)
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	raw, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	wire := append([]byte(nil), raw...)
	// Warmup + measure full table decode.
	if _, err := s.DeserializeBytes(wire); err != nil {
		t.Fatal(err)
	}
	t0 := time.Now()
	for i := 0; i < 5; i++ {
		if _, err := s.DeserializeBytes(wire); err != nil {
			t.Fatal(err)
		}
	}
	full := time.Since(t0)

	projFx := model.Fixture{Name: "table_project", Value: fx.Value}
	if err := s.Prepare(projFx); err != nil {
		t.Fatal(err)
	}
	got, err := s.DeserializeBytes(wire)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(modelv2.ProjectFFloat0(fx.Value), got) {
		t.Fatal("table_project mismatch")
	}
	t1 := time.Now()
	for i := 0; i < 5; i++ {
		if _, err := s.DeserializeBytes(wire); err != nil {
			t.Fatal(err)
		}
	}
	proj := time.Since(t1)
	t.Logf("gld-kiln-asm N=10000 deser full=%s proj=%s (%.1fx)", full, proj, float64(full)/float64(proj))
	if proj*2 >= full {
		t.Fatalf("table_project (%s) not clearly faster than full (%s)", proj, full)
	}
}

func TestGldKilnAsmRejectsInvalidUTF8(t *testing.T) {
	s := newGldKilnAsm()
	fx := v2Fixture("message")
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	raw, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	bad := append([]byte(nil), raw...)
	// Message fixed prefix before f_string bytes: bool(1)+i32(4)+i64(8)+f64(8)+u32(4) = 25.
	if len(bad) > 25 {
		bad[25] = 0xFF
		if _, err := s.DeserializeBytes(bad); err == nil {
			t.Fatal("expected invalid UTF-8 to be rejected")
		}
	}
}
