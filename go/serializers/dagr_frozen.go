// dagr-frozen — the Dagr row (dagr.go) over FROZEN nodes: fixed struct layout, no vtable
// (no schema evolution, `mmap`-able when all fields are required-inline). Graphs
// `<Type>FrozenGraph` → go/gen/dagrv2/<type>frozengraph (lazy + arena + serde; no direct
// builder for a non-packed root). Encode: the generated arena, built in Prepare
// (untimed); the timed call is `AppendTo<Graph>` into a reused Builder. Decode: lazy accessors → owned
// suite value, arrays via `<F>Iter()`. Framing/recover as `dagr-packed`.
//
// Mirrors dagr.go field for field; keep dagr_regular.go / dagr_frozen.go /
// dagr_frozen_packed.go in step with it (the per-package types rule out one generic
// decoder without putting dictionary-dispatched accessor calls on the clock).

package serializers

import (
	"fmt"

	"dagrv2/dagr"
	"dagrv2/documentfrozengraph"
	"dagrv2/eventfrozengraph"
	"dagrv2/messagefrozengraph"
	"dagrv2/stringsfrozengraph"
	"dagrv2/telemetryfrozengraph"

	modelv2 "serializer-benchmark-go/model/v2"
)

func newDagrFrozen() *dagrSer { return &dagrSer{name: "dagr-frozen", bind: bindDagrFrozen} }

// ── dagr-frozen: frozen (fixed-struct) nodes; arena → AppendTo (encode), lazy accessors (decode) ──

// bindDagrFrozen binds the `dagr-frozen` row: arena built in Prepare, `AppendTo{Graph}` timed (one reused Builder).
func bindDagrFrozen(v any) (dagrCodec, error) {
	switch v.(type) {
	case modelv2.Message, []modelv2.Message:
		return bindDagrArena(v, arenaMessageFrozen, messagefrozengraph.AppendToMessageFrozenGraph, getMessageFrozen), nil
	case modelv2.Document, []modelv2.Document:
		return bindDagrArena(v, arenaDocumentFrozen, documentfrozengraph.AppendToDocumentFrozenGraph, getDocumentFrozen), nil
	case modelv2.Telemetry, []modelv2.Telemetry:
		return bindDagrArena(v, arenaTelemetryFrozen, telemetryfrozengraph.AppendToTelemetryFrozenGraph, getTelemetryFrozen), nil
	case modelv2.Strings, []modelv2.Strings:
		return bindDagrArena(v, arenaStringsFrozen, stringsfrozengraph.AppendToStringsFrozenGraph, getStringsFrozen), nil
	case modelv2.Event, []modelv2.Event:
		return bindDagrArena(v, arenaEventFrozen, eventfrozengraph.AppendToEventFrozenGraph, getEventFrozen), nil
	}
	return dagrCodec{}, fmt.Errorf("unsupported type %T", v)
}

// ── suite value → arena (Prepare, untimed; every field set) ──

func arenaMessageFrozen(m modelv2.Message) messagefrozengraph.Message {
	a := messagefrozengraph.NewArena()
	n := a.NewMessage()
	n.SetFBool(m.FBool)
	n.SetFInt32(m.FInt32)
	n.SetFInt64(m.FInt64)
	n.SetFFloat64(m.FFloat64)
	n.SetFString(m.FString)
	n.SetFBool2(m.FBool2)
	n.SetFInt32_2(m.FInt32_2)
	n.SetFString2(m.FString2)
	a.SetRoot(n)
	return n
}

func arenaDocumentFrozen(d modelv2.Document) documentfrozengraph.Document {
	a := documentfrozengraph.NewArena()
	meta := a.NewDocumentMeta()
	meta.SetRegion(d.Meta.Region)
	meta.SetVersion(d.Meta.Version)
	items := make([]documentfrozengraph.DocumentItem, len(d.Items))
	for i, it := range d.Items {
		items[i] = a.NewDocumentItem()
		items[i].SetSku(it.SKU)
		items[i].SetQty(it.Qty)
		items[i].SetPriceMinor(it.PriceMinor)
	}
	n := a.NewDocument()
	n.SetID(d.ID)
	n.SetStatus(d.Status)
	n.SetMeta(meta)
	n.SetItems(items)
	a.SetRoot(n)
	return n
}

func arenaTelemetryFrozen(t modelv2.Telemetry) telemetryfrozengraph.Telemetry {
	a := telemetryfrozengraph.NewArena()
	n := a.NewTelemetry()
	n.SetSource(t.Source)
	n.SetTs(t.TS)
	n.SetTags(t.Tags)
	n.SetValues(t.Values)
	a.SetRoot(n)
	return n
}

func arenaStringsFrozen(st modelv2.Strings) stringsfrozengraph.Strings {
	a := stringsfrozengraph.NewArena()
	n := a.NewStrings()
	n.SetItems(st.Items)
	a.SetRoot(n)
	return n
}

func arenaEventFrozen(e modelv2.Event) eventfrozengraph.Event {
	a := eventfrozengraph.NewArena()
	attrs := make([]eventfrozengraph.EventAttr, len(e.Attrs))
	for i, x := range e.Attrs {
		attrs[i] = a.NewEventAttr()
		attrs[i].SetKey(x.Key)
		attrs[i].SetValue(x.Value)
	}
	n := a.NewEvent()
	n.SetEventID(e.EventID)
	n.SetEventType(e.EventType)
	n.SetOccurredAt(e.OccurredAt)
	n.SetProducer(e.Producer)
	n.SetAttrs(attrs)
	a.SetRoot(n)
	return n
}

// ── decode (lazy reader → owned suite value) ──

func getMessageFrozen(buf []byte) (modelv2.Message, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Message{}, err
	}
	a := messagefrozengraph.NewMessageAccessor(buf, pos)
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

func getDocumentFrozen(buf []byte) (modelv2.Document, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Document{}, err
	}
	a := documentfrozengraph.NewDocumentAccessor(buf, pos)
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

func getTelemetryFrozen(buf []byte) (modelv2.Telemetry, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Telemetry{}, err
	}
	a := telemetryfrozengraph.NewTelemetryAccessor(buf, pos)
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

func getStringsFrozen(buf []byte) (modelv2.Strings, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Strings{}, err
	}
	a := stringsfrozengraph.NewStringsAccessor(buf, pos)
	it := a.ItemsIter()
	items := make([]string, it.Len())
	for i := range items {
		items[i], _ = it.Next()
	}
	return modelv2.Strings{Items: items}, nil
}

func getEventFrozen(buf []byte) (modelv2.Event, error) {
	pos, err := dagr.RootOffset(buf)
	if err != nil {
		return modelv2.Event{}, err
	}
	a := eventfrozengraph.NewEventAccessor(buf, pos)
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
