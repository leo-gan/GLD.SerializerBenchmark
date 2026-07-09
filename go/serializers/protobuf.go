package serializers

import (
	"fmt"
	"io"
	"time"

	"google.golang.org/protobuf/proto"

	pb "serializer-benchmark-go/gen/pb"
	"serializer-benchmark-go/model"
)

// googleProtobuf — official google.golang.org/protobuf (protoimpl API).
// Recommended: proto.Marshal / proto.Unmarshal on generated messages;
// convert domain types in Prepare (untimed).
// https://protobuf.dev/getting-started/gotutorial/
type googleProtobuf struct {
	name   string
	msg    proto.Message // prepared native message
	fxName string
}

func newGoogleProtobuf() *googleProtobuf { return &googleProtobuf{} }

func (s *googleProtobuf) Name() string           { return "protobuf" }
func (s *googleProtobuf) Version() string        { return ModuleVersion("google.golang.org/protobuf") }
func (s *googleProtobuf) StreamMode() StreamMode { return StreamAdapted }
func (s *googleProtobuf) NativeKind() NativeKind { return NativeMessage }
func (s *googleProtobuf) Supports(n string) bool {
	// No bare Integer message in shared schema (aligned with Rust prost).
	// Flat ObjectGraph is supported via GraphNodeData index edges.
	return n != "Integer"
}

func (s *googleProtobuf) Prepare(fx model.Fixture) error {
	s.fxName = fx.Name
	msg, err := toProto(fx)
	if err != nil {
		return err
	}
	s.msg = msg
	return nil
}

func (s *googleProtobuf) SerializeBytes(_ model.Fixture) ([]byte, error) {
	return proto.Marshal(s.msg)
}

func (s *googleProtobuf) DeserializeBytes(buf []byte) (any, error) {
	msg := emptyProto(s.fxName)
	if msg == nil {
		return nil, fmt.Errorf("unknown fixture %s", s.fxName)
	}
	if err := proto.Unmarshal(buf, msg); err != nil {
		return nil, err
	}
	return fromProto(s.fxName, msg)
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
	default:
		return nil
	}
}

func fromProto(name string, msg proto.Message) (any, error) {
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
	default:
		return nil, fmt.Errorf("fromProto: %s", name)
	}
}
