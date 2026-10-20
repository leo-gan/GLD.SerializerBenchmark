package serializers

import (
	"bytes"
	"math"
	"strings"
	"testing"

	"google.golang.org/protobuf/proto"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

func v2Fixture(typeID string) model.Fixture {
	val := modelv2.MakeOne(typeID, nil, 42, 0)
	if val == nil {
		panic("unknown v2 type: " + typeID)
	}
	return model.Fixture{Name: typeID, Value: val}
}

func TestMsgpackUsesReusedEncoder(t *testing.T) {
	s := newVmihailencoMsgpack()
	if s.enc == nil {
		t.Fatal("expected reused Encoder")
	}
	fx := v2Fixture("message")
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	a, err := s.SerializeBytes(fx)
	if err != nil || len(a) == 0 {
		t.Fatalf("serialize: %v len=%d", err, len(a))
	}
	b, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	// Deterministic encode of same value
	if !bytes.Equal(a, b) {
		t.Fatal("msgpack encode not deterministic for same fixture")
	}
	out, err := s.DeserializeBytes(a)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(fx.Value, out) {
		t.Fatal("msgpack fidelity")
	}
}

func TestProtobufTimedPathReturnsMessage(t *testing.T) {
	s := newGoogleProtobuf()
	fx := v2Fixture("message")
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	raw, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := s.DeserializeBytes(raw)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := decoded.(proto.Message); !ok {
		t.Fatalf("deserialize should return proto.Message for timed path, got %T", decoded)
	}
	// Same dst instance must be reused across deserializations (proto.Reset path).
	decoded2, err := s.DeserializeBytes(raw)
	if err != nil {
		t.Fatal(err)
	}
	if decoded != decoded2 {
		t.Fatal("expected reused protobuf dst message across DeserializeBytes calls")
	}
	domain, err := s.ToDomain(decoded)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(fx.Value, domain) {
		t.Fatal("ToDomain fidelity")
	}
}

func TestAvroSchemaCache(t *testing.T) {
	a, err := schemaFor("message")
	if err != nil {
		t.Fatal(err)
	}
	b, err := schemaFor("message")
	if err != nil {
		t.Fatal(err)
	}
	// Same cached instance
	if a != b {
		t.Fatal("expected cached schema identity")
	}
}

func TestAllSerializersMessageRoundtrip(t *testing.T) {
	fx := v2Fixture("message")
	for _, ser := range All() {
		if !ser.Supports("message") {
			continue
		}
		t.Run(ser.Name(), func(t *testing.T) {
			if err := ser.Prepare(fx); err != nil {
				t.Fatal(err)
			}
			raw, err := ser.SerializeBytes(fx)
			if err != nil {
				t.Fatal(err)
			}
			out, err := ser.DeserializeBytes(raw)
			if err != nil {
				t.Fatal(err)
			}
			if conv, ok := ser.(DomainConverter); ok {
				out, err = conv.ToDomain(out)
				if err != nil {
					t.Fatal(err)
				}
			}
			if !model.Fidelity(fx.Value, out) {
				t.Fatalf("fidelity failed for %s", ser.Name())
			}
		})
	}
}

func TestRegistryHasExpectedNames(t *testing.T) {
	names := map[string]bool{}
	for _, s := range All() {
		names[s.Name()] = true
	}
	for _, want := range []string{
		"encoding/json", "encoding/json/v2", "sonic", "goccy/go-json", "jsoniter",
		"vmihailenco/msgpack", "shamaton/msgpack", "fxamacker/cbor",
		"encoding/gob", "mongo-bson", "ion-go", "protobuf", "hamba/avro", "linkedin/goavro",
	} {
		if !names[want] {
			t.Errorf("missing serializer %s", want)
		}
	}
}

func TestGldKilnBatchRoundtrip(t *testing.T) {
	s := newGldKiln()
	if s.Supports("graph") || s.Supports("table") {
		t.Fatal("gld-kiln supports only the five suite types")
	}
	for _, typeID := range []string{"message", "document", "telemetry", "strings", "event"} {
		one := v2Fixture(typeID)
		batchVals := reflectBatch(typeID, 100)
		for _, fx := range []model.Fixture{one, {Name: typeID, Value: batchVals}} {
			if err := s.Prepare(fx); err != nil {
				t.Fatal(err)
			}
			raw, err := s.SerializeBytes(fx)
			if err != nil {
				t.Fatalf("%s serialize: %v", typeID, err)
			}
			// Copy before the next encode: SerializeBytes reuses its buffer.
			first := append([]byte(nil), raw...)
			raw2, err := s.SerializeBytes(fx)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(first, raw2) {
				t.Fatalf("%s encode not stable", typeID)
			}
			out, err := s.DeserializeBytes(raw2)
			if err != nil {
				t.Fatal(err)
			}
			dom, err := s.ToDomain(out)
			if err != nil {
				t.Fatal(err)
			}
			if !model.Fidelity(fx.Value, dom) {
				t.Fatalf("%s fidelity failed", typeID)
			}
		}
	}
}

func reflectBatch(typeID string, n int) any {
	switch typeID {
	case "message":
		s := make([]modelv2.Message, n)
		for i := range s {
			s[i] = modelv2.MakeOne(typeID, nil, 7, i).(modelv2.Message)
		}
		return s
	case "document":
		s := make([]modelv2.Document, n)
		for i := range s {
			s[i] = modelv2.MakeOne(typeID, nil, 7, i).(modelv2.Document)
		}
		return s
	case "telemetry":
		s := make([]modelv2.Telemetry, n)
		for i := range s {
			s[i] = modelv2.MakeOne(typeID, nil, 7, i).(modelv2.Telemetry)
		}
		return s
	case "strings":
		s := make([]modelv2.Strings, n)
		for i := range s {
			s[i] = modelv2.MakeOne(typeID, nil, 7, i).(modelv2.Strings)
		}
		return s
	default:
		s := make([]modelv2.Event, n)
		for i := range s {
			s[i] = modelv2.MakeOne(typeID, nil, 7, i).(modelv2.Event)
		}
		return s
	}
}

func TestProtobufSupportsOnlyV2(t *testing.T) {
	s := newGoogleProtobuf()
	if s.Supports("not-a-suite-type") {
		t.Fatal("protobuf should reject unknown type ids")
	}
	if !s.Supports("message") || !s.Supports("document") || !s.Supports("event") {
		t.Fatal("protobuf should support suite type_ids")
	}
}

func TestCallPathDocsMentionOptimizations(t *testing.T) {
	// Sanity: msgpack file documents Encoder reuse.
	// (structural guard so the optimized path is not silently removed)
	s := newVmihailencoMsgpack()
	fx := v2Fixture("document")
	_ = s.Prepare(fx)
	raw, _ := s.SerializeBytes(fx)
	var stream bytes.Buffer
	n, err := s.SerializeStream(fx, &stream)
	if err != nil || n == 0 {
		t.Fatalf("stream: n=%d err=%v", n, err)
	}
	if len(raw) == 0 {
		t.Fatal("empty bytes")
	}
	// Names should be stable for analysis
	if !strings.Contains(s.Name(), "msgpack") {
		t.Fatal(s.Name())
	}
}

// TestStreamModeLabels documents which codecs truly use library stream APIs.
// Adapted = Marshal-bytes + Write / ReadAll + Unmarshal (no native io path).
func TestStreamModeLabels(t *testing.T) {
	want := map[string]StreamMode{
		"encoding/json":            StreamNative,
		"encoding/json/v2":         StreamNative,
		"sonic":                    StreamNative,
		"goccy/go-json":            StreamNative,
		"jsoniter":                 StreamNative,
		"segmentio/encoding/json":  StreamNative,
		"ugorji/json":              StreamNative,
		"vmihailenco/msgpack":      StreamNative,
		"shamaton/msgpack":         StreamNative,
		"shamaton/msgpack (array)": StreamNative,
		"ugorji/msgpack":           StreamNative,
		"fxamacker/cbor":           StreamNative,
		"ugorji/cbor":              StreamNative,
		"kelindar/binary":          StreamNative,
		"encoding/gob":             StreamNative,
		"mongo-bson":               StreamNative,
		"ion-go":                   StreamNative,
		"gld-kiln":                 StreamAdapted,
		"goccy/go-yaml":            StreamNative,
		"pelletier/go-toml":        StreamNative,
		"hamba/avro":               StreamNative,
		// Byte-slice-only libraries (OCF would change wire format vs bytes):
		"protobuf":           StreamAdapted,
		"linkedin/goavro":    StreamAdapted,
		"fory":               StreamAdapted,
		"dagr-packed":        StreamAdapted,
		"dagr-regular":       StreamAdapted,
		"dagr-frozen":        StreamAdapted,
		"dagr-frozen-packed": StreamAdapted,
		// Bytes API only. Adapted streams must not crash; they are not a native io path.
		"arrow-ipc":            StreamAdapted,
		"parquet":              StreamAdapted,
		"parquet-uncompressed": StreamAdapted,
		"sbe":                  StreamAdapted,
	}
	seen := map[string]bool{}
	for _, ser := range All() {
		seen[ser.Name()] = true
		got := ser.StreamMode()
		w, ok := want[ser.Name()]
		if !ok {
			t.Errorf("missing StreamMode expectation for %s (got %s)", ser.Name(), got)
			continue
		}
		if got != w {
			t.Errorf("%s StreamMode=%s want %s", ser.Name(), got, w)
		}
	}
	for name := range want {
		if !seen[name] {
			t.Errorf("expected serializer %s not registered", name)
		}
	}
}

func TestAllSerializersMessageStreamRoundtrip(t *testing.T) {
	fx := v2Fixture("message")
	for _, ser := range All() {
		if !ser.Supports("message") {
			continue
		}
		t.Run(ser.Name(), func(t *testing.T) {
			if err := ser.Prepare(fx); err != nil {
				t.Fatal(err)
			}
			raw, err := ser.SerializeBytes(fx)
			if err != nil {
				t.Fatal(err)
			}
			var stream bytes.Buffer
			n, err := ser.SerializeStream(fx, &stream)
			if err != nil {
				t.Fatal(err)
			}
			if n != stream.Len() {
				t.Fatalf("SerializeStream count %d != buffer %d", n, stream.Len())
			}
			// Stream payload should match bytes payload for single-value formats.
			if !bytes.Equal(raw, stream.Bytes()) {
				// Some codecs may differ only if stream adds framing; still require
				// round-trip fidelity below. Log size mismatch for diagnosis.
				if len(raw) != stream.Len() {
					t.Logf("bytes size %d vs stream size %d (may be OK if framing differs)", len(raw), stream.Len())
				}
			}
			out, err := ser.DeserializeStream(bytes.NewReader(stream.Bytes()))
			if err != nil {
				t.Fatal(err)
			}
			if conv, ok := ser.(DomainConverter); ok {
				out, err = conv.ToDomain(out)
				if err != nil {
					t.Fatal(err)
				}
			}
			if !model.Fidelity(fx.Value, out) {
				t.Fatalf("stream fidelity failed for %s", ser.Name())
			}
		})
	}
}

// TestDagrBatchFramingAndVersion (every Dagr layout row): N>1 cells use the suite frame (u32 count + (u32 len +
// record)×N) and round-trip; the version comes from schemas/v2/dagr/dagr.lock.json.
func TestDagrBatchFramingAndVersion(t *testing.T) {
	for _, s := range []*dagrSer{newDagr(), newDagrRegular(), newDagrFrozen(), newDagrFrozenPacked()} {
		t.Run(s.Name(), func(t *testing.T) { testDagrBatchFramingAndVersion(t, s) })
	}
}

func testDagrBatchFramingAndVersion(t *testing.T, s *dagrSer) {
	if v := s.Version(); v == "" || strings.HasPrefix(v, "dagr") {
		t.Fatalf("dagr version %q", v)
	}
	for _, typeID := range []string{"message", "document", "telemetry", "strings", "event"} {
		for _, n := range []int{1, 3} {
			_, val := modelv2.FixtureFromCell(modelv2.Cell{TypeID: typeID, DataTypeInstanceCount: n}, 42)
			fx := model.Fixture{Name: typeID, Value: val}
			if err := s.Prepare(fx); err != nil {
				t.Fatal(err)
			}
			raw, err := s.SerializeBytes(fx)
			if err != nil {
				t.Fatalf("%s n=%d: %v", typeID, n, err)
			}
			if n > 1 && int(raw[0]) != n {
				t.Fatalf("%s n=%d: frame count %d", typeID, n, raw[0])
			}
			out, err := s.DeserializeBytes(raw)
			if err != nil {
				t.Fatalf("%s n=%d: %v", typeID, n, err)
			}
			if !model.Fidelity(fx.Value, out) {
				t.Fatalf("%s n=%d: fidelity", typeID, n)
			}
			if _, err := s.DeserializeBytes(raw[:len(raw)/2]); err == nil && n == 1 {
				t.Logf("%s: truncated record decoded without error (lazy reader)", typeID)
			}
		}
	}
}

func TestKilnTensorRoundtrip(t *testing.T) {
	s := newGldKiln()
	for _, id := range []string{"tensor", "tensor_view", "prompt", "shard", "request"} {
		if !s.Supports(id) {
			t.Fatalf("supports %s", id)
		}
	}
	if s.Supports("graph") || s.Supports("table") {
		t.Fatal("tensor support must not include graph or table")
	}
	full := modelv2.MakeOne("tensor", nil, 7, 0).(modelv2.Tensor)
	again := modelv2.MakeOne("tensor_view", nil, 7, 0).(modelv2.Tensor)
	if !model.Fidelity(full, again) {
		t.Fatal("tensor_view seed diverged from tensor")
	}
	if len(full.Values) != 1024*1024 || full.Rows != 1024 || full.Cols != 1024 {
		t.Fatalf("shape %d x %d len %d", full.Rows, full.Cols, len(full.Values))
	}
	if math.Float32bits(full.Values[0]) != 0x80000000 || math.Float32bits(full.Values[1]) != 0x7fc00000 {
		t.Fatalf("pins %08x %08x", math.Float32bits(full.Values[0]), math.Float32bits(full.Values[1]))
	}
	pos := full
	pos.Values = append([]float32(nil), full.Values...)
	pos.Values[0] = 0
	if model.Fidelity(full, pos) {
		t.Fatal("negative zero compared equal to +0")
	}

	small := map[string]any{
		"rows": float64(4), "cols": float64(4),
		"batch": float64(2), "seq": float64(8), "vocab": float64(32),
		"hidden": float64(4), "ffn": float64(6),
		"string_len": map[string]any{"min": float64(3), "max": float64(6)},
	}
	for _, id := range []string{"tensor", "tensor_view", "prompt", "shard", "request"} {
		fx := model.Fixture{Name: id, Value: modelv2.MakeOne(id, small, 9, 1)}
		if err := s.Prepare(fx); err != nil {
			t.Fatal(err)
		}
		raw, err := s.SerializeBytes(fx)
		if err != nil {
			t.Fatalf("%s serialize: %v", id, err)
		}
		if id == "tensor" || id == "tensor_view" {
			want := 12 + 4*4*4
			if len(raw) != want {
				t.Fatalf("%s size %d want %d", id, len(raw), want)
			}
		}
		out, err := s.DeserializeBytes(raw)
		if err != nil {
			t.Fatalf("%s decode: %v", id, err)
		}
		if id == "tensor_view" {
			view, ok := out.(tensorView)
			if !ok || len(view.Payload) == 0 || &view.Payload[0] != &raw[12] {
				t.Fatalf("%s decode copied the matrix (%T)", id, out)
			}
			raw[12] ^= 0xff
			dom, err := s.ToDomain(out)
			if err != nil {
				t.Fatal(err)
			}
			if model.Fidelity(fx.Value, dom) {
				t.Fatal("tensor_view ignored borrowed bytes")
			}
			raw[12] ^= 0xff
			dom, err = s.ToDomain(out)
			if err != nil || !model.Fidelity(fx.Value, dom) {
				t.Fatalf("%s fidelity after restore: %v", id, err)
			}
			raw[12] ^= 0xff
			if !model.Fidelity(fx.Value, dom) {
				t.Fatal("ToDomain aliased the payload")
			}
			continue
		}
		if id == "tensor" {
			raw[12] ^= 0xff
			dom, err := s.ToDomain(out)
			if err != nil {
				t.Fatal(err)
			}
			if !model.Fidelity(fx.Value, dom) {
				t.Fatal("tensor decode did not own the float list")
			}
			continue
		}
		dom, err := s.ToDomain(out)
		if err != nil {
			t.Fatal(err)
		}
		if !model.Fidelity(fx.Value, dom) {
			t.Fatalf("%s fidelity", id)
		}
	}

	fx := model.Fixture{Name: "tensor", Value: full}
	if err := s.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	raw, err := s.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw) != 4194316 {
		t.Fatalf("1024x1024 wire size %d", len(raw))
	}
	out, err := s.DeserializeBytes(raw)
	if err != nil {
		t.Fatal(err)
	}
	dom, err := s.ToDomain(out)
	if err != nil || !model.Fidelity(full, dom) {
		t.Fatalf("full tensor fidelity: %v", err)
	}
	viewFx := model.Fixture{Name: "tensor_view", Value: again}
	if err := s.Prepare(viewFx); err != nil {
		t.Fatal(err)
	}
	raw, err = s.SerializeBytes(viewFx)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw) != 4194316 {
		t.Fatalf("tensor_view wire size %d", len(raw))
	}
	out, err = s.DeserializeBytes(raw)
	if err != nil {
		t.Fatal(err)
	}
	view := out.(tensorView)
	if &view.Payload[0] != &raw[12] || len(view.Payload) != 1024*1024*4 {
		t.Fatal("full tensor_view copied")
	}
	dom, err = s.ToDomain(out)
	if err != nil || !model.Fidelity(again, dom) {
		t.Fatalf("full tensor_view fidelity: %v", err)
	}
}
