package serializers

import (
	"fmt"
	"io"
	"time"

	"google.golang.org/protobuf/proto"

	pb "serializer-benchmark-go/gen/pb"
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
	// No bare Integer message in shared schema (aligned with Rust prost).
	switch n {
	case "Integer":
		return false
	case "message", "document", "telemetry", "strings", "event",
		"Person", "SimpleObject", "StringArray", "Telemetry", "EDI_835", "ObjectGraph":
		return true
	default:
		return true
	}
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

func parseTimeMs(s string) int64 {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		// try date-only variants already used as full RFC3339 in fixtures
		return 0
	}
	return t.UnixMilli()
}

func formatTimeMs(ms int64) string {
	if ms == 0 {
		return ""
	}
	return time.UnixMilli(ms).UTC().Format(time.RFC3339)
}

func toProto(fx model.Fixture) (proto.Message, error) {
	switch v := fx.Value.(type) {
	case model.Person:
		var pass *pb.Passport
		if v.Passport != nil {
			pass = &pb.Passport{
				Number:         v.Passport.Number,
				Authority:      v.Passport.Authority,
				ExpirationDate: parseTimeMs(v.Passport.ExpirationDate),
			}
		}
		recs := make([]*pb.PoliceRecord, len(v.PoliceRecords))
		for i, r := range v.PoliceRecords {
			recs[i] = &pb.PoliceRecord{Id: r.ID, CrimeCode: r.CrimeCode}
		}
		return &pb.Person{
			FirstName:     v.FirstName,
			LastName:      v.LastName,
			Age:           uint32(v.Age),
			Gender:        pb.Gender(v.Gender),
			Passport:      pass,
			PoliceRecords: recs,
		}, nil
	case model.SimpleObject:
		return &pb.SimpleObject{
			Id:        v.ID,
			Name:      v.Name,
			Timestamp: parseTimeMs(v.Timestamp),
			IsActive:  v.IsActive,
		}, nil
	case model.StringArrayObject:
		return &pb.StringArrayObject{Items: append([]string(nil), v.Items...)}, nil
	case model.TelemetryData:
		return &pb.TelemetryData{
			Id:                  v.ID,
			DataSource:          v.DataSource,
			TimeStamp:           parseTimeMs(v.TimeStamp),
			Param1:              v.Param1,
			Param2:              uint32(v.Param2),
			Measurements:        append([]float64(nil), v.Measurements...),
			AssociatedProblemID: int64(v.AssociatedProblemID),
			AssociatedLogID:     int64(v.AssociatedLogID),
			WasProcessed:        v.WasProcessed,
		}, nil
	case model.Edi835:
		claims := make([]*pb.Claim, len(v.Claims))
		for i, c := range v.Claims {
			lines := make([]*pb.ServiceLine, len(c.Lines))
			for j, l := range c.Lines {
				lines[j] = &pb.ServiceLine{
					ServiceCode:       l.ServiceCode,
					ChargeAmount:      l.ChargeAmount,
					AdjudicatedAmount: l.AdjudicatedAmount,
				}
			}
			claims[i] = &pb.Claim{
				ClaimId:       c.ClaimID,
				PatientName:   c.PatientName,
				TotalCharge:   c.TotalCharge,
				PaymentAmount: c.PaymentAmount,
				Lines:         lines,
			}
		}
		return &pb.EDI835{
			PayerName:                v.PayerName,
			PayeeName:                v.PayeeName,
			PaymentDate:              parseTimeMs(v.PaymentDate),
			TotalActualAmount:        v.TotalActualAmount,
			TransactionControlNumber: v.TransactionControlNumber,
			Claims:                   claims,
		}, nil
	case model.ObjectGraph:
		nodes := make([]*pb.GraphNodeData, len(v.Nodes))
		for i, n := range v.Nodes {
			nodes[i] = &pb.GraphNodeData{
				Name:     n.Name,
				Parent:   n.Parent,
				Related:  n.Related,
				Children: append([]int32(nil), n.Children...),
			}
		}
		return &pb.ObjectGraph{Root: v.Root, Nodes: nodes}, nil
	// Data Model v2
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
	default:
		return nil, fmt.Errorf("protobuf: unsupported type %T", fx.Value)
	}
}

func emptyProto(name string) proto.Message {
	switch name {
	case "Person":
		return &pb.Person{}
	case "SimpleObject":
		return &pb.SimpleObject{}
	case "StringArray":
		return &pb.StringArrayObject{}
	case "Telemetry":
		return &pb.TelemetryData{}
	case "EDI_835":
		return &pb.EDI835{}
	case "ObjectGraph":
		return &pb.ObjectGraph{}
	case "message":
		return &pbv2.Message{}
	case "document":
		return &pbv2.Document{}
	case "telemetry":
		return &pbv2.Telemetry{}
	case "strings":
		return &pbv2.Strings{}
	case "event":
		return &pbv2.Event{}
	default:
		return nil
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
	}
	switch name {
	case "Person":
		p := msg.(*pb.Person)
		var pass *model.Passport
		if p.Passport != nil {
			pass = &model.Passport{
				Number:         p.Passport.Number,
				Authority:      p.Passport.Authority,
				ExpirationDate: formatTimeMs(p.Passport.ExpirationDate),
			}
		}
		recs := make([]model.PoliceRecord, len(p.PoliceRecords))
		for i, r := range p.PoliceRecords {
			recs[i] = model.PoliceRecord{ID: r.Id, CrimeCode: r.CrimeCode}
		}
		return model.Person{
			FirstName:     p.FirstName,
			LastName:      p.LastName,
			Age:           int32(p.Age),
			Gender:        model.Gender(p.Gender),
			Passport:      pass,
			PoliceRecords: recs,
		}, nil
	case "SimpleObject":
		p := msg.(*pb.SimpleObject)
		return model.SimpleObject{
			ID:        p.Id,
			Name:      p.Name,
			Timestamp: formatTimeMs(p.Timestamp),
			IsActive:  p.IsActive,
		}, nil
	case "StringArray":
		p := msg.(*pb.StringArrayObject)
		return model.StringArrayObject{Items: append([]string(nil), p.Items...)}, nil
	case "Telemetry":
		p := msg.(*pb.TelemetryData)
		return model.TelemetryData{
			ID:                  p.Id,
			DataSource:          p.DataSource,
			TimeStamp:           formatTimeMs(p.TimeStamp),
			Param1:              p.Param1,
			Param2:              int32(p.Param2),
			Measurements:        append([]float64(nil), p.Measurements...),
			AssociatedProblemID: int32(p.AssociatedProblemID),
			AssociatedLogID:     int32(p.AssociatedLogID),
			WasProcessed:        p.WasProcessed,
		}, nil
	case "EDI_835":
		p := msg.(*pb.EDI835)
		claims := make([]model.Claim, len(p.Claims))
		for i, c := range p.Claims {
			lines := make([]model.ServiceLine, len(c.Lines))
			for j, l := range c.Lines {
				lines[j] = model.ServiceLine{
					ServiceCode:       l.ServiceCode,
					ChargeAmount:      l.ChargeAmount,
					AdjudicatedAmount: l.AdjudicatedAmount,
				}
			}
			claims[i] = model.Claim{
				ClaimID:       c.ClaimId,
				PatientName:   c.PatientName,
				TotalCharge:   c.TotalCharge,
				PaymentAmount: c.PaymentAmount,
				Lines:         lines,
			}
		}
		return model.Edi835{
			PayerName:                p.PayerName,
			PayeeName:                p.PayeeName,
			PaymentDate:              formatTimeMs(p.PaymentDate),
			TotalActualAmount:        p.TotalActualAmount,
			TransactionControlNumber: p.TransactionControlNumber,
			Claims:                   claims,
		}, nil
	case "ObjectGraph":
		p := msg.(*pb.ObjectGraph)
		nodes := make([]model.GraphNodeData, len(p.Nodes))
		for i, n := range p.Nodes {
			ch := n.Children
			if ch == nil {
				ch = []int32{}
			}
			nodes[i] = model.GraphNodeData{
				Name:     n.Name,
				Parent:   n.Parent,
				Related:  n.Related,
				Children: append([]int32(nil), ch...),
			}
		}
		return model.ObjectGraph{Root: p.Root, Nodes: nodes}, nil
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
