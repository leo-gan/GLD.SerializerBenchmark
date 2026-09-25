package serializers

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"dagrv2/dagr"
	"dagrv2/documentgraphdirect"
	"dagrv2/eventgraphdirect"
	"dagrv2/messagegraphdirect"
	"dagrv2/stringsgraphdirect"
	"dagrv2/telemetrygraphdirect"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// dagrSer — Dagr ("Data Graph") via generated Go code.
//
// Schema: schemas/v2/dagr/schema.py → `dagr build` → go/gen/dagrv2 (its own module,
// wired with a `replace` in go.mod). Only the per-graph `<graph>direct` packages are
// imported: each is self-contained (direct builder + lazy accessors); the root `dagrv2`
// package (arenas + eager restore) is not needed here. One DataGraph per suite type, all nodes packed,
// Telemetry.values marked `raw` (native-LE doubles, like protobuf's packed double).
//
// Serialize (timed): the generated **direct builder** (plain value structs → bytes, no
// arena). The value structs are this codec's native model, so — like protobuf's toProto —
// they are built from the suite values in Prepare (untimed); the timed call only runs
// `BuildAppend`. One `<Graph>Builder` per type is created in Prepare and reset by every
// Build; `BuildAppend` appends the record to a reused output buffer (Dagr writes
// back-to-front, so that one copy is inherent).
//
// Deserialize (timed): the generated **lazy reader** (`dagr.RootOffset` framing check +
// `New<Root>Accessor`, the body of `Open<Graph>Unchecked`; one recover per call so
// malformed bytes are an error, not a panic), then the
// owned suite value is materialized field by field. Arrays are walked with the
// generated `<F>Iter()` (O(n)), never `<F>At(i)` (O(i) per call).
//
// N>1 cells: the schema has no Batch_* wrapper (the harness frames N instances), so the
// frame is the suite's cross-language one (rust/src/run_v2.rs, C bench_serialize_cell):
// u32 LE count + (u32 LE len + record)×N. N=1 is the bare record.
//
// Per-type encode/decode functions are bound in Prepare (no type switch on the clock).
// Stream mode is adapted (Dagr's graph API is []byte-in / []byte-out).
type dagrSer struct {
	enc func(dst []byte) []byte // timed: encode the prepared value(s)
	dec func(buf []byte) (any, error)
	out []byte // reused encode buffer; SerializeBytes returns a copy (as protobuf does)

	// Created lazily in Prepare, reused across cells and reps.
	msgB *messagegraphdirect.MessageGraphBuilder
	docB *documentgraphdirect.DocumentGraphBuilder
	telB *telemetrygraphdirect.TelemetryGraphBuilder
	strB *stringsgraphdirect.StringsGraphBuilder
	evB  *eventgraphdirect.EventGraphBuilder
}

func newDagr() *dagrSer { return &dagrSer{} }

func (s *dagrSer) Name() string           { return "dagr" }
func (s *dagrSer) Version() string        { return dagrToolVersion() }
func (s *dagrSer) StreamMode() StreamMode { return StreamAdapted }
func (s *dagrSer) NativeKind() NativeKind { return NativeSchema }
func (s *dagrSer) Supports(n string) bool { return modelv2.IsV2TypeName(n) }

// ── version ────────────────────────────────────────────────────────────────

var (
	dagrVersionOnce sync.Once
	dagrVersion     string
)

// dagrToolVersion is the generator version recorded in the committed receipt
// schemas/v2/dagr/dagr.lock.json (provenance.tool_version "dagr 2026.9.0" → "2026.9.0") — the
// Go analogue of rust/build.rs's DAGR_VERSION. The generated code is vendored as a local
// module, so build info carries no version for it. go:embed cannot reach outside the Go
// module, so the receipt is read once at runtime from the repository root (the runner
// already resolves its run config the same way).
func dagrToolVersion() string {
	dagrVersionOnce.Do(func() {
		cwd, _ := os.Getwd()
		for dir := cwd; ; dir = filepath.Dir(dir) {
			raw, err := os.ReadFile(filepath.Join(dir, "schemas", "v2", "dagr", "dagr.lock.json"))
			if err == nil {
				var lock struct {
					Provenance struct {
						ToolVersion string `json:"tool_version"`
					} `json:"provenance"`
				}
				if json.Unmarshal(raw, &lock) == nil {
					dagrVersion = strings.TrimSpace(strings.TrimPrefix(lock.Provenance.ToolVersion, "dagr"))
				}
				return
			}
			if parent := filepath.Dir(dir); parent == dir {
				return
			}
		}
	})
	return dagrVersion
}

// ── prepare / timed path ───────────────────────────────────────────────────

func (s *dagrSer) Prepare(fx model.Fixture) error {
	switch fx.Value.(type) {
	case modelv2.Message, []modelv2.Message:
		if s.msgB == nil {
			s.msgB = messagegraphdirect.NewMessageGraphBuilder()
		}
		s.enc, s.dec = bindDagr(fx.Value, directMessage, s.msgB.BuildAppend, getMessage)
	case modelv2.Document, []modelv2.Document:
		if s.docB == nil {
			s.docB = documentgraphdirect.NewDocumentGraphBuilder()
		}
		s.enc, s.dec = bindDagr(fx.Value, directDocument, s.docB.BuildAppend, getDocument)
	case modelv2.Telemetry, []modelv2.Telemetry:
		if s.telB == nil {
			s.telB = telemetrygraphdirect.NewTelemetryGraphBuilder()
		}
		s.enc, s.dec = bindDagr(fx.Value, directTelemetry, s.telB.BuildAppend, getTelemetry)
	case modelv2.Strings, []modelv2.Strings:
		if s.strB == nil {
			s.strB = stringsgraphdirect.NewStringsGraphBuilder()
		}
		s.enc, s.dec = bindDagr(fx.Value, directStrings, s.strB.BuildAppend, getStrings)
	case modelv2.Event, []modelv2.Event:
		if s.evB == nil {
			s.evB = eventgraphdirect.NewEventGraphBuilder()
		}
		s.enc, s.dec = bindDagr(fx.Value, directEvent, s.evB.BuildAppend, getEvent)
	default:
		return fmt.Errorf("dagr: unsupported type %T", fx.Value)
	}
	s.out = s.out[:0]
	return nil
}

func (s *dagrSer) SerializeBytes(_ model.Fixture) ([]byte, error) {
	if s.enc == nil {
		return nil, fmt.Errorf("dagr: prepare() required before serialize")
	}
	s.out = s.enc(s.out[:0])
	out := make([]byte, len(s.out))
	copy(out, s.out)
	return out, nil
}

func (s *dagrSer) DeserializeBytes(buf []byte) (v any, err error) {
	if s.dec == nil {
		return nil, fmt.Errorf("dagr: prepare() required before deserialize")
	}
	// The unchecked open trusts the bytes; a malformed buffer panics inside an
	// accessor — turn that into an error (one defer per call, not per field).
	defer func() {
		if r := recover(); r != nil {
			v, err = nil, dagr.ErrMalformed
		}
	}()
	return s.dec(buf)
}

func (s *dagrSer) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *dagrSer) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

// bindDagr converts the prepared suite value(s) to direct value structs ONCE (untimed —
// the counterpart of protobuf's toProto in Prepare) and binds the single-record or the
// framed-batch codec, chosen from the value's shape.
func bindDagr[T, V any](
	sample any,
	conv func(T) V,
	put func(dst []byte, v V) []byte,
	get func(buf []byte) (T, error),
) (func([]byte) []byte, func([]byte) (any, error)) {
	if x, single := sample.(T); single {
		v := conv(x)
		enc := func(dst []byte) []byte { return put(dst, v) }
		dec := func(buf []byte) (any, error) { return get(buf) }
		return enc, dec
	}
	xs := sample.([]T)
	vs := make([]V, len(xs))
	for i := range xs {
		vs[i] = conv(xs[i])
	}
	enc := func(dst []byte) []byte {
		dst = binary.LittleEndian.AppendUint32(dst, uint32(len(vs)))
		for i := range vs {
			at := len(dst)
			dst = append(dst, 0, 0, 0, 0)
			dst = put(dst, vs[i])
			binary.LittleEndian.PutUint32(dst[at:], uint32(len(dst)-at-4))
		}
		return dst
	}
	dec := func(buf []byte) (any, error) {
		if len(buf) < 4 {
			return nil, fmt.Errorf("dagr: batch frame too short")
		}
		n := int(binary.LittleEndian.Uint32(buf))
		o := 4
		out := make([]T, n)
		for i := range out {
			if o+4 > len(buf) {
				return nil, fmt.Errorf("dagr: truncated batch frame")
			}
			l := int(binary.LittleEndian.Uint32(buf[o:]))
			o += 4
			if o+l > len(buf) {
				return nil, fmt.Errorf("dagr: truncated batch payload")
			}
			var err error
			if out[i], err = get(buf[o : o+l]); err != nil {
				return nil, err
			}
			o += l
		}
		return out, nil
	}
	return enc, dec
}

// ── suite value → direct value struct (Prepare, untimed; every field set) ───

func directMessage(m modelv2.Message) messagegraphdirect.Message {
	return messagegraphdirect.Message{
		FBool:    dagr.Some(m.FBool),
		FInt32:   dagr.Some(m.FInt32),
		FInt64:   dagr.Some(m.FInt64),
		FFloat64: dagr.Some(m.FFloat64),
		FString:  dagr.Some(m.FString),
		FBool2:   dagr.Some(m.FBool2),
		FInt32_2: dagr.Some(m.FInt32_2),
		FString2: dagr.Some(m.FString2),
	}
}

func directDocument(d modelv2.Document) documentgraphdirect.Document {
	items := make([]documentgraphdirect.DocumentItem, len(d.Items))
	for i, it := range d.Items {
		items[i] = documentgraphdirect.DocumentItem{
			Sku:        dagr.Some(it.SKU),
			Qty:        dagr.Some(it.Qty),
			PriceMinor: dagr.Some(it.PriceMinor),
		}
	}
	return documentgraphdirect.Document{
		ID:     dagr.Some(d.ID),
		Status: dagr.Some(d.Status),
		Meta: dagr.Some(documentgraphdirect.DocumentMeta{
			Region:  dagr.Some(d.Meta.Region),
			Version: dagr.Some(d.Meta.Version),
		}),
		Items: dagr.Some(items),
	}
}

func directTelemetry(t modelv2.Telemetry) telemetrygraphdirect.Telemetry {
	return telemetrygraphdirect.Telemetry{
		Source: dagr.Some(t.Source),
		Ts:     dagr.Some(t.TS),
		Tags:   dagr.Some(t.Tags),
		Values: dagr.Some(t.Values),
	}
}

func directStrings(st modelv2.Strings) stringsgraphdirect.Strings {
	return stringsgraphdirect.Strings{Items: dagr.Some(st.Items)}
}

func directEvent(e modelv2.Event) eventgraphdirect.Event {
	attrs := make([]eventgraphdirect.EventAttr, len(e.Attrs))
	for i, a := range e.Attrs {
		attrs[i] = eventgraphdirect.EventAttr{Key: dagr.Some(a.Key), Value: dagr.Some(a.Value)}
	}
	return eventgraphdirect.Event{
		EventID:    dagr.Some(e.EventID),
		EventType:  dagr.Some(e.EventType),
		OccurredAt: dagr.Some(e.OccurredAt),
		Producer:   dagr.Some(e.Producer),
		Attrs:      dagr.Some(attrs),
	}
}

// ── decode (lazy reader → owned suite value; strings are copied out) ──────

func getMessage(buf []byte) (modelv2.Message, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Message{}, err
	}
	a := messagegraphdirect.NewMessageAccessor(buf, pos)
	var m modelv2.Message
	m.FBool, _ = a.FBool()
	m.FInt32, _ = a.FInt32()
	m.FInt64, _ = a.FInt64()
	m.FFloat64, _ = a.FFloat64()
	m.FString, _ = a.FString()
	m.FBool2, _ = a.FBool2()
	m.FInt32_2, _ = a.FInt32_2()
	m.FString2, _ = a.FString2()
	return m, nil
}

func getDocument(buf []byte) (modelv2.Document, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Document{}, err
	}
	a := documentgraphdirect.NewDocumentAccessor(buf, pos)
	var d modelv2.Document
	d.ID, _ = a.ID()
	d.Status, _ = a.Status()
	if meta, ok := a.Meta(); ok {
		d.Meta.Region, _ = meta.Region()
		d.Meta.Version, _ = meta.Version()
	}
	it := a.ItemsIter()
	d.Items = make([]modelv2.DocumentItem, it.Len())
	for i := range d.Items {
		e, _ := it.Next()
		out := &d.Items[i]
		out.SKU, _ = e.Sku()
		out.Qty, _ = e.Qty()
		out.PriceMinor, _ = e.PriceMinor()
	}
	return d, nil
}

func getTelemetry(buf []byte) (modelv2.Telemetry, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Telemetry{}, err
	}
	a := telemetrygraphdirect.NewTelemetryAccessor(buf, pos)
	var t modelv2.Telemetry
	t.Source, _ = a.Source()
	t.TS, _ = a.Ts()
	tags := a.TagsIter()
	t.Tags = make([]string, tags.Len())
	for i := range t.Tags {
		t.Tags[i], _ = tags.Next()
	}
	vals := a.ValuesIter()
	t.Values = make([]float64, vals.Len())
	for i := range t.Values {
		t.Values[i], _ = vals.Next()
	}
	return t, nil
}

func getStrings(buf []byte) (modelv2.Strings, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Strings{}, err
	}
	a := stringsgraphdirect.NewStringsAccessor(buf, pos)
	it := a.ItemsIter()
	items := make([]string, it.Len())
	for i := range items {
		items[i], _ = it.Next()
	}
	return modelv2.Strings{Items: items}, nil
}

func getEvent(buf []byte) (modelv2.Event, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Event{}, err
	}
	a := eventgraphdirect.NewEventAccessor(buf, pos)
	var e modelv2.Event
	e.EventID, _ = a.EventID()
	e.EventType, _ = a.EventType()
	e.OccurredAt, _ = a.OccurredAt()
	e.Producer, _ = a.Producer()
	it := a.AttrsIter()
	e.Attrs = make([]modelv2.EventAttr, it.Len())
	for i := range e.Attrs {
		x, _ := it.Next()
		e.Attrs[i].Key, _ = x.Key()
		e.Attrs[i].Value, _ = x.Value()
	}
	return e, nil
}
