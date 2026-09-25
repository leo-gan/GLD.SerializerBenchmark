// dagr-frozen-packed — the Dagr row (dagr.go) over FROZEN+PACKED nodes: positional and
// fixed (densest record, no schema evolution). Graphs `<Type>FrozenPackedGraph` →
// go/gen/dagrv2/<type>frozenpackedgraphdirect (direct builder + lazy accessors). Same
// timed path as `dagr-packed`: direct value structs built in Prepare, `BuildAppend` timed; lazy
// accessors → owned suite value, arrays via `<F>Iter()`.
//
// Mirrors dagr.go field for field; keep dagr_regular.go / dagr_frozen.go /
// dagr_frozen_packed.go in step with it (the per-package types rule out one generic
// decoder without putting dictionary-dispatched accessor calls on the clock).

package serializers

import (
	"fmt"

	"dagrv2/dagr"
	"dagrv2/documentfrozenpackedgraphdirect"
	"dagrv2/eventfrozenpackedgraphdirect"
	"dagrv2/messagefrozenpackedgraphdirect"
	"dagrv2/stringsfrozenpackedgraphdirect"
	"dagrv2/telemetryfrozenpackedgraphdirect"

	modelv2 "serializer-benchmark-go/model/v2"
)

func newDagrFrozenPacked() *dagrSer {
	return &dagrSer{name: "dagr-frozen-packed", bind: newDagrFrozenPackedBinder()}
}

// ── dagr-frozen-packed: frozen+packed nodes; direct builder (encode), lazy accessors (decode) ──

// newDagrFrozenPackedBinder binds the `dagr-frozen-packed` row: direct builder, exactly
// like the `dagr-packed` row (one builder per type, reset by every Build).
func newDagrFrozenPackedBinder() func(any) (dagrCodec, error) {
	var (
		mB *messagefrozenpackedgraphdirect.MessageFrozenPackedGraphBuilder
		dB *documentfrozenpackedgraphdirect.DocumentFrozenPackedGraphBuilder
		tB *telemetryfrozenpackedgraphdirect.TelemetryFrozenPackedGraphBuilder
		sB *stringsfrozenpackedgraphdirect.StringsFrozenPackedGraphBuilder
		eB *eventfrozenpackedgraphdirect.EventFrozenPackedGraphBuilder
	)
	return func(v any) (dagrCodec, error) {
		switch v.(type) {
		case modelv2.Message, []modelv2.Message:
			if mB == nil {
				mB = messagefrozenpackedgraphdirect.NewMessageFrozenPackedGraphBuilder()
			}
			return bindDagr(v, directMessageFrozenPacked, mB.BuildAppend, getMessageFrozenPacked), nil
		case modelv2.Document, []modelv2.Document:
			if dB == nil {
				dB = documentfrozenpackedgraphdirect.NewDocumentFrozenPackedGraphBuilder()
			}
			return bindDagr(v, directDocumentFrozenPacked, dB.BuildAppend, getDocumentFrozenPacked), nil
		case modelv2.Telemetry, []modelv2.Telemetry:
			if tB == nil {
				tB = telemetryfrozenpackedgraphdirect.NewTelemetryFrozenPackedGraphBuilder()
			}
			return bindDagr(v, directTelemetryFrozenPacked, tB.BuildAppend, getTelemetryFrozenPacked), nil
		case modelv2.Strings, []modelv2.Strings:
			if sB == nil {
				sB = stringsfrozenpackedgraphdirect.NewStringsFrozenPackedGraphBuilder()
			}
			return bindDagr(v, directStringsFrozenPacked, sB.BuildAppend, getStringsFrozenPacked), nil
		case modelv2.Event, []modelv2.Event:
			if eB == nil {
				eB = eventfrozenpackedgraphdirect.NewEventFrozenPackedGraphBuilder()
			}
			return bindDagr(v, directEventFrozenPacked, eB.BuildAppend, getEventFrozenPacked), nil
		}
		return dagrCodec{}, fmt.Errorf("unsupported type %T", v)
	}
}

// ── suite value → direct value struct (Prepare, untimed; every field set) ──

func directMessageFrozenPacked(m modelv2.Message) messagefrozenpackedgraphdirect.Message {
	return messagefrozenpackedgraphdirect.Message{
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

func directDocumentFrozenPacked(d modelv2.Document) documentfrozenpackedgraphdirect.Document {
	items := make([]documentfrozenpackedgraphdirect.DocumentItem, len(d.Items))
	for i, it := range d.Items {
		items[i] = documentfrozenpackedgraphdirect.DocumentItem{
			Sku:        dagr.Some(it.SKU),
			Qty:        dagr.Some(it.Qty),
			PriceMinor: dagr.Some(it.PriceMinor),
		}
	}
	return documentfrozenpackedgraphdirect.Document{
		ID:     dagr.Some(d.ID),
		Status: dagr.Some(d.Status),
		Meta: dagr.Some(documentfrozenpackedgraphdirect.DocumentMeta{
			Region:  dagr.Some(d.Meta.Region),
			Version: dagr.Some(d.Meta.Version),
		}),
		Items: dagr.Some(items),
	}
}

func directTelemetryFrozenPacked(t modelv2.Telemetry) telemetryfrozenpackedgraphdirect.Telemetry {
	return telemetryfrozenpackedgraphdirect.Telemetry{
		Source: dagr.Some(t.Source),
		Ts:     dagr.Some(t.TS),
		Tags:   dagr.Some(t.Tags),
		Values: dagr.Some(t.Values),
	}
}

func directStringsFrozenPacked(st modelv2.Strings) stringsfrozenpackedgraphdirect.Strings {
	return stringsfrozenpackedgraphdirect.Strings{Items: dagr.Some(st.Items)}
}

func directEventFrozenPacked(e modelv2.Event) eventfrozenpackedgraphdirect.Event {
	attrs := make([]eventfrozenpackedgraphdirect.EventAttr, len(e.Attrs))
	for i, a := range e.Attrs {
		attrs[i] = eventfrozenpackedgraphdirect.EventAttr{Key: dagr.Some(a.Key), Value: dagr.Some(a.Value)}
	}
	return eventfrozenpackedgraphdirect.Event{
		EventID:    dagr.Some(e.EventID),
		EventType:  dagr.Some(e.EventType),
		OccurredAt: dagr.Some(e.OccurredAt),
		Producer:   dagr.Some(e.Producer),
		Attrs:      dagr.Some(attrs),
	}
}

// ── decode (lazy reader → owned suite value) ──

func getMessageFrozenPacked(buf []byte) (modelv2.Message, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Message{}, err
	}
	a := messagefrozenpackedgraphdirect.NewMessageAccessor(buf, pos)
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

func getDocumentFrozenPacked(buf []byte) (modelv2.Document, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Document{}, err
	}
	a := documentfrozenpackedgraphdirect.NewDocumentAccessor(buf, pos)
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

func getTelemetryFrozenPacked(buf []byte) (modelv2.Telemetry, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Telemetry{}, err
	}
	a := telemetryfrozenpackedgraphdirect.NewTelemetryAccessor(buf, pos)
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

func getStringsFrozenPacked(buf []byte) (modelv2.Strings, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Strings{}, err
	}
	a := stringsfrozenpackedgraphdirect.NewStringsAccessor(buf, pos)
	it := a.ItemsIter()
	items := make([]string, it.Len())
	for i := range items {
		items[i], _ = it.Next()
	}
	return modelv2.Strings{Items: items}, nil
}

func getEventFrozenPacked(buf []byte) (modelv2.Event, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Event{}, err
	}
	a := eventfrozenpackedgraphdirect.NewEventAccessor(buf, pos)
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
