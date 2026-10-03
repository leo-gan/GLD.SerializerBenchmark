package serializers

import (
	"fmt"
	"io"

	"google.golang.org/protobuf/proto"

	pbv2 "serializer-benchmark-go/gen/pbv2"
	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// googleProtobuf — official google.golang.org/protobuf (protoimpl API).
// Recommended: convert domain→Message in Prepare (untimed); timed path is only
// MarshalAppend / Unmarshal. Domain conversion after deser is untimed (ToDomain).
// Stream mode is adapted: proto.Marshal/Unmarshal are []byte-only (gRPC framing
// is a different protocol, not used here).
// https://protobuf.dev/getting-started/gotutorial/
// https://pkg.go.dev/google.golang.org/protobuf/proto#MarshalOptions.MarshalAppend
type googleProtobuf struct {
	msg    proto.Message // prepared native message (serialize)
	dst    proto.Message // reusable unmarshal target
	serBuf []byte        // MarshalAppend scratch (reused)
	fxName string
}

func newGoogleProtobuf() *googleProtobuf { return &googleProtobuf{} }

func (s *googleProtobuf) Name() string           { return "protobuf" }
func (s *googleProtobuf) Version() string        { return ModuleVersion("google.golang.org/protobuf") }
func (s *googleProtobuf) StreamMode() StreamMode { return StreamAdapted }
func (s *googleProtobuf) NativeKind() NativeKind { return NativeMessage }
func (s *googleProtobuf) Supports(n string) bool {
	return modelv2.IsV2TypeName(n)
}

func (s *googleProtobuf) Prepare(fx model.Fixture) error {
	s.fxName = fx.Name
	msg, err := toProto(fx)
	if err != nil {
		return err
	}
	s.msg = msg
	// Destination type matches prepared message (Batch_* for N>1).
	s.dst = proto.Clone(msg)
	proto.Reset(s.dst)
	s.serBuf = s.serBuf[:0]
	return nil
}

func (s *googleProtobuf) SerializeBytes(_ model.Fixture) ([]byte, error) {
	var err error
	// MarshalAppend reuses serBuf (0 alloc steady-state); copy for caller ownership.
	s.serBuf, err = proto.MarshalOptions{}.MarshalAppend(s.serBuf[:0], s.msg)
	if err != nil {
		return nil, err
	}
	out := make([]byte, len(s.serBuf))
	copy(out, s.serBuf)
	return out, nil
}

func (s *googleProtobuf) DeserializeBytes(buf []byte) (any, error) {
	if s.dst == nil {
		return nil, fmt.Errorf("prepare() required before deserialize")
	}
	// Reuse dst: Unmarshal merges into the message, so clear first. Reset avoids
	// allocating a new Message (and nested slices) on every timed deser call.
	// https://pkg.go.dev/google.golang.org/protobuf/proto#Reset
	proto.Reset(s.dst)
	if err := proto.Unmarshal(buf, s.dst); err != nil {
		return nil, err
	}
	// Timed path ends here — Message only (domain conversion via ToDomain).
	return s.dst, nil
}

// ToDomain converts a protobuf Message to suite model types (untimed fidelity path).
func (s *googleProtobuf) ToDomain(decoded any) (any, error) {
	msg, ok := decoded.(proto.Message)
	if !ok {
		return decoded, nil
	}
	out, err := fromProto(s.fxName, msg)
	if err != nil {
		// Batch types / unknown: accept native message for fidelity via proto.Equal
		return decoded, nil
	}
	return out, nil
}

func (s *googleProtobuf) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *googleProtobuf) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

func toProto(fx model.Fixture) (proto.Message, error) {
	switch v := fx.Value.(type) {
	case modelv2.Message:
		return &pbv2.Message{
			FBool: v.FBool, FInt32: v.FInt32, FInt64: v.FInt64, FFloat64: v.FFloat64,
			FString: v.FString, FBool_2: v.FBool2, FInt32_2: v.FInt32_2, FString_2: v.FString2,
		}, nil
	case modelv2.Document:
		items := make([]*pbv2.DocumentItem, len(v.Items))
		for i, it := range v.Items {
			items[i] = &pbv2.DocumentItem{Sku: it.SKU, Qty: it.Qty, PriceMinor: it.PriceMinor}
		}
		return &pbv2.Document{
			Id: v.ID, Status: v.Status,
			Meta:  &pbv2.DocumentMeta{Region: v.Meta.Region, Version: v.Meta.Version},
			Items: items,
		}, nil
	case modelv2.Telemetry:
		return &pbv2.Telemetry{
			Source: v.Source, Ts: v.TS,
			Tags: append([]string(nil), v.Tags...), Values: append([]float64(nil), v.Values...),
		}, nil
	case modelv2.Strings:
		return &pbv2.Strings{Items: append([]string(nil), v.Items...)}, nil
	case modelv2.Event:
		attrs := make([]*pbv2.EventAttr, len(v.Attrs))
		for i, a := range v.Attrs {
			attrs[i] = &pbv2.EventAttr{Key: a.Key, Value: a.Value}
		}
		return &pbv2.Event{
			EventId: v.EventID, EventType: v.EventType, OccurredAt: v.OccurredAt,
			Producer: v.Producer, Attrs: attrs,
		}, nil
	case []modelv2.Message:
		items := make([]*pbv2.Message, len(v))
		for i := range v {
			m, err := toProto(model.Fixture{Name: "message", Value: v[i]})
			if err != nil {
				return nil, err
			}
			items[i] = m.(*pbv2.Message)
		}
		return &pbv2.BatchMessage{Items: items}, nil
	case []modelv2.Document:
		items := make([]*pbv2.Document, len(v))
		for i := range v {
			m, err := toProto(model.Fixture{Name: "document", Value: v[i]})
			if err != nil {
				return nil, err
			}
			items[i] = m.(*pbv2.Document)
		}
		return &pbv2.BatchDocument{Items: items}, nil
	case []modelv2.Telemetry:
		items := make([]*pbv2.Telemetry, len(v))
		for i := range v {
			m, err := toProto(model.Fixture{Name: "telemetry", Value: v[i]})
			if err != nil {
				return nil, err
			}
			items[i] = m.(*pbv2.Telemetry)
		}
		return &pbv2.BatchTelemetry{Items: items}, nil
	case []modelv2.Strings:
		items := make([]*pbv2.Strings, len(v))
		for i := range v {
			m, err := toProto(model.Fixture{Name: "strings", Value: v[i]})
			if err != nil {
				return nil, err
			}
			items[i] = m.(*pbv2.Strings)
		}
		return &pbv2.BatchStrings{Items: items}, nil
	case []modelv2.Event:
		items := make([]*pbv2.Event, len(v))
		for i := range v {
			m, err := toProto(model.Fixture{Name: "event", Value: v[i]})
			if err != nil {
				return nil, err
			}
			items[i] = m.(*pbv2.Event)
		}
		return &pbv2.BatchEvent{Items: items}, nil
	case modelv2.TableRow:
		return tableToProto(v), nil
	case []modelv2.TableRow:
		items := make([]*pbv2.Table, len(v))
		for i := range v {
			items[i] = tableToProto(v[i])
		}
		return &pbv2.BatchTable{Items: items}, nil
	case modelv2.NestedRow:
		return nestedToProto(v), nil
	case []modelv2.NestedRow:
		items := make([]*pbv2.NestedRow, len(v))
		for i := range v {
			items[i] = nestedToProto(v[i])
		}
		return &pbv2.BatchNestedRow{Items: items}, nil
	case modelv2.Signal:
		return signalToProto(v), nil
	case []modelv2.Signal:
		items := make([]*pbv2.Signal, len(v))
		for i := range v {
			items[i] = signalToProto(v[i])
		}
		return &pbv2.BatchSignal{Items: items}, nil
	default:
		return nil, fmt.Errorf("protobuf: unsupported type %T", fx.Value)
	}
}

func tableToProto(v modelv2.TableRow) *pbv2.Table {
	return &pbv2.Table{
		FFloat_0: v.FFloat0, FFloat_1: v.FFloat1, FFloat_2: v.FFloat2, FFloat_3: v.FFloat3,
		FFloat_4: v.FFloat4, FFloat_5: v.FFloat5, FFloat_6: v.FFloat6, FFloat_7: v.FFloat7,
		FFloat_8: v.FFloat8, FFloat_9: v.FFloat9, FFloat_10: v.FFloat10, FFloat_11: v.FFloat11,
		FFloat_12: v.FFloat12, FFloat_13: v.FFloat13, FFloat_14: v.FFloat14, FFloat_15: v.FFloat15,
		FInt_0: v.FInt0, FInt_1: v.FInt1, FInt_2: v.FInt2, FInt_3: v.FInt3,
		FStr_0: v.FStr0, FStr_1: v.FStr1,
	}
}

func tableFromPB(p *pbv2.Table) modelv2.TableRow {
	if p == nil {
		return modelv2.TableRow{}
	}
	return modelv2.TableRow{
		FFloat0: p.FFloat_0, FFloat1: p.FFloat_1, FFloat2: p.FFloat_2, FFloat3: p.FFloat_3,
		FFloat4: p.FFloat_4, FFloat5: p.FFloat_5, FFloat6: p.FFloat_6, FFloat7: p.FFloat_7,
		FFloat8: p.FFloat_8, FFloat9: p.FFloat_9, FFloat10: p.FFloat_10, FFloat11: p.FFloat_11,
		FFloat12: p.FFloat_12, FFloat13: p.FFloat_13, FFloat14: p.FFloat_14, FFloat15: p.FFloat_15,
		FInt0: p.FInt_0, FInt1: p.FInt_1, FInt2: p.FInt_2, FInt3: p.FInt_3,
		FStr0: p.FStr_0, FStr1: p.FStr_1,
	}
}

func nestedToProto(v modelv2.NestedRow) *pbv2.NestedRow {
	items := make([]*pbv2.NestedItem, len(v.Items))
	for i, it := range v.Items {
		items[i] = &pbv2.NestedItem{Sku: it.SKU, Qty: it.Qty, PriceMinor: it.PriceMinor}
	}
	return &pbv2.NestedRow{
		Id: v.ID, Status: v.Status,
		Meta:  &pbv2.NestedMeta{Region: v.Meta.Region, Version: v.Meta.Version},
		Items: items,
	}
}

func nestedFromPB(p *pbv2.NestedRow) modelv2.NestedRow {
	if p == nil {
		return modelv2.NestedRow{}
	}
	var meta modelv2.NestedMeta
	if p.Meta != nil {
		meta = modelv2.NestedMeta{Region: p.Meta.Region, Version: p.Meta.Version}
	}
	items := make([]modelv2.NestedItem, len(p.Items))
	for i, it := range p.Items {
		if it == nil {
			continue
		}
		items[i] = modelv2.NestedItem{SKU: it.Sku, Qty: it.Qty, PriceMinor: it.PriceMinor}
	}
	return modelv2.NestedRow{ID: p.Id, Status: p.Status, Meta: meta, Items: items}
}

func signalToProto(v modelv2.Signal) *pbv2.Signal {
	legs := make([]*pbv2.SignalLeg, len(v.Legs))
	for i, leg := range v.Legs {
		legs[i] = &pbv2.SignalLeg{LegId: leg.LegID, LegQty: leg.LegQty, LegPad: leg.LegPad}
	}
	return &pbv2.Signal{
		Seq: v.Seq, Ts: v.TS, PriceMantissa: v.PriceMantissa,
		Qty: v.Qty, Flags: v.Flags, Symbol: v.Symbol, Venue: v.Venue, Legs: legs,
	}
}

func signalFromPB(p *pbv2.Signal) modelv2.Signal {
	if p == nil {
		return modelv2.Signal{}
	}
	legs := make([]modelv2.SignalLeg, len(p.Legs))
	for i, leg := range p.Legs {
		if leg == nil {
			continue
		}
		legs[i] = modelv2.SignalLeg{LegID: leg.LegId, LegQty: leg.LegQty, LegPad: leg.LegPad}
	}
	return modelv2.Signal{
		Seq: p.Seq, TS: p.Ts, PriceMantissa: p.PriceMantissa,
		Qty: p.Qty, Flags: p.Flags, Symbol: p.Symbol, Venue: p.Venue, Legs: legs,
	}
}

func fromProto(name string, msg proto.Message) (any, error) {
	// Prefer concrete batch types when present (N>1 cells).
	switch b := msg.(type) {
	case *pbv2.BatchMessage:
		out := make([]modelv2.Message, len(b.Items))
		for i, p := range b.Items {
			out[i] = modelv2.Message{
				FBool: p.FBool, FInt32: p.FInt32, FInt64: p.FInt64, FFloat64: p.FFloat64,
				FString: p.FString, FBool2: p.FBool_2, FInt32_2: p.FInt32_2, FString2: p.FString_2,
			}
		}
		return out, nil
	case *pbv2.BatchDocument:
		out := make([]modelv2.Document, len(b.Items))
		for i, p := range b.Items {
			var meta modelv2.DocumentMeta
			if p.Meta != nil {
				meta = modelv2.DocumentMeta{Region: p.Meta.Region, Version: p.Meta.Version}
			}
			items := make([]modelv2.DocumentItem, len(p.Items))
			for j, it := range p.Items {
				items[j] = modelv2.DocumentItem{SKU: it.Sku, Qty: it.Qty, PriceMinor: it.PriceMinor}
			}
			out[i] = modelv2.Document{ID: p.Id, Status: p.Status, Meta: meta, Items: items}
		}
		return out, nil
	case *pbv2.BatchTelemetry:
		out := make([]modelv2.Telemetry, len(b.Items))
		for i, p := range b.Items {
			out[i] = modelv2.Telemetry{
				Source: p.Source, TS: p.Ts,
				Tags: append([]string(nil), p.Tags...), Values: append([]float64(nil), p.Values...),
			}
		}
		return out, nil
	case *pbv2.BatchStrings:
		out := make([]modelv2.Strings, len(b.Items))
		for i, p := range b.Items {
			out[i] = modelv2.Strings{Items: append([]string(nil), p.Items...)}
		}
		return out, nil
	case *pbv2.BatchEvent:
		out := make([]modelv2.Event, len(b.Items))
		for i, p := range b.Items {
			attrs := make([]modelv2.EventAttr, len(p.Attrs))
			for j, a := range p.Attrs {
				attrs[j] = modelv2.EventAttr{Key: a.Key, Value: a.Value}
			}
			out[i] = modelv2.Event{
				EventID: p.EventId, EventType: p.EventType, OccurredAt: p.OccurredAt,
				Producer: p.Producer, Attrs: attrs,
			}
		}
		return out, nil
	case *pbv2.Table:
		row := tableFromPB(b)
		if name == "table_project" {
			return modelv2.ProjectFFloat0(row), nil
		}
		return row, nil
	case *pbv2.BatchTable:
		rows := make([]modelv2.TableRow, len(b.Items))
		for i, p := range b.Items {
			rows[i] = tableFromPB(p)
		}
		if name == "table_project" {
			return modelv2.ProjectFFloat0(rows), nil
		}
		return rows, nil
	case *pbv2.NestedRow:
		return nestedFromPB(b), nil
	case *pbv2.BatchNestedRow:
		rows := make([]modelv2.NestedRow, len(b.Items))
		for i, p := range b.Items {
			rows[i] = nestedFromPB(p)
		}
		return rows, nil
	case *pbv2.Signal:
		return signalFromPB(b), nil
	case *pbv2.BatchSignal:
		rows := make([]modelv2.Signal, len(b.Items))
		for i, p := range b.Items {
			rows[i] = signalFromPB(p)
		}
		return rows, nil
	}
	switch name {
	case "message":
		if b, ok := msg.(*pbv2.BatchMessage); ok {
			out := make([]modelv2.Message, len(b.Items))
			for i, p := range b.Items {
				out[i] = modelv2.Message{
					FBool: p.FBool, FInt32: p.FInt32, FInt64: p.FInt64, FFloat64: p.FFloat64,
					FString: p.FString, FBool2: p.FBool_2, FInt32_2: p.FInt32_2, FString2: p.FString_2,
				}
			}
			return out, nil
		}
		p := msg.(*pbv2.Message)
		return modelv2.Message{
			FBool: p.FBool, FInt32: p.FInt32, FInt64: p.FInt64, FFloat64: p.FFloat64,
			FString: p.FString, FBool2: p.FBool_2, FInt32_2: p.FInt32_2, FString2: p.FString_2,
		}, nil
	case "document":
		p := msg.(*pbv2.Document)
		var meta modelv2.DocumentMeta
		if p.Meta != nil {
			meta = modelv2.DocumentMeta{Region: p.Meta.Region, Version: p.Meta.Version}
		}
		items := make([]modelv2.DocumentItem, len(p.Items))
		for i, it := range p.Items {
			items[i] = modelv2.DocumentItem{SKU: it.Sku, Qty: it.Qty, PriceMinor: it.PriceMinor}
		}
		return modelv2.Document{ID: p.Id, Status: p.Status, Meta: meta, Items: items}, nil
	case "telemetry":
		p := msg.(*pbv2.Telemetry)
		return modelv2.Telemetry{
			Source: p.Source, TS: p.Ts,
			Tags: append([]string(nil), p.Tags...), Values: append([]float64(nil), p.Values...),
		}, nil
	case "strings":
		p := msg.(*pbv2.Strings)
		return modelv2.Strings{Items: append([]string(nil), p.Items...)}, nil
	case "event":
		p := msg.(*pbv2.Event)
		attrs := make([]modelv2.EventAttr, len(p.Attrs))
		for i, a := range p.Attrs {
			attrs[i] = modelv2.EventAttr{Key: a.Key, Value: a.Value}
		}
		return modelv2.Event{
			EventID: p.EventId, EventType: p.EventType, OccurredAt: p.OccurredAt,
			Producer: p.Producer, Attrs: attrs,
		}, nil
	default:
		return nil, fmt.Errorf("fromProto: %s", name)
	}
}
