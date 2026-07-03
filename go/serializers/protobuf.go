package serializers

import (
	"fmt"
	"io"
	"time"

	"google.golang.org/protobuf/proto"

	"serializer-benchmark-go/data"
	pb "serializer-benchmark-go/gen/pb"
)

// googleProtobuf — official google.golang.org/protobuf (protoimpl API).
// Recommended: proto.Marshal / proto.Unmarshal on generated messages;
// convert domain types in Prepare (untimed).
// https://protobuf.dev/getting-started/gotutorial/
type googleProtobuf struct {
	name    string
	msg     proto.Message // prepared native message
	fxName  string
}

func newGoogleProtobuf() *googleProtobuf { return &googleProtobuf{} }

func (s *googleProtobuf) Name() string           { return "protobuf" }
func (s *googleProtobuf) Version() string        { return "proto3" }
func (s *googleProtobuf) StreamMode() StreamMode { return StreamAdapted }
func (s *googleProtobuf) NativeKind() NativeKind { return NativeMessage }
func (s *googleProtobuf) Supports(n string) bool {
	// No bare Integer message in shared schema (aligned with Rust prost).
	if n == "Integer" || n == "ObjectGraph" {
		return false
	}
	return true
}

func (s *googleProtobuf) Prepare(fx data.Fixture) error {
	s.fxName = fx.Name
	msg, err := toProto(fx)
	if err != nil {
		return err
	}
	s.msg = msg
	return nil
}

func (s *googleProtobuf) SerializeBytes(_ data.Fixture) ([]byte, error) {
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

func (s *googleProtobuf) SerializeStream(fx data.Fixture, w io.Writer) (int, error) {
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

func toProto(fx data.Fixture) (proto.Message, error) {
	switch v := fx.Value.(type) {
	case data.Person:
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
			FirstName:      v.FirstName,
			LastName:       v.LastName,
			Age:            uint32(v.Age),
			Gender:         pb.Gender(v.Gender),
			Passport:       pass,
			PoliceRecords:  recs,
		}, nil
	case data.SimpleObject:
		return &pb.SimpleObject{
			Id:        v.ID,
			Name:      v.Name,
			Timestamp: parseTimeMs(v.Timestamp),
			IsActive:  v.IsActive,
		}, nil
	case data.StringArrayObject:
		return &pb.StringArrayObject{Items: append([]string(nil), v.Items...)}, nil
	case data.TelemetryData:
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
	case data.Edi835:
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
	default:
		return nil
	}
}

func fromProto(name string, msg proto.Message) (any, error) {
	switch name {
	case "Person":
		p := msg.(*pb.Person)
		var pass *data.Passport
		if p.Passport != nil {
			pass = &data.Passport{
				Number:         p.Passport.Number,
				Authority:      p.Passport.Authority,
				ExpirationDate: formatTimeMs(p.Passport.ExpirationDate),
			}
		}
		recs := make([]data.PoliceRecord, len(p.PoliceRecords))
		for i, r := range p.PoliceRecords {
			recs[i] = data.PoliceRecord{ID: r.Id, CrimeCode: r.CrimeCode}
		}
		return data.Person{
			FirstName:     p.FirstName,
			LastName:      p.LastName,
			Age:           int32(p.Age),
			Gender:        data.Gender(p.Gender),
			Passport:      pass,
			PoliceRecords: recs,
		}, nil
	case "SimpleObject":
		p := msg.(*pb.SimpleObject)
		return data.SimpleObject{
			ID:        p.Id,
			Name:      p.Name,
			Timestamp: formatTimeMs(p.Timestamp),
			IsActive:  p.IsActive,
		}, nil
	case "StringArray":
		p := msg.(*pb.StringArrayObject)
		return data.StringArrayObject{Items: append([]string(nil), p.Items...)}, nil
	case "Telemetry":
		p := msg.(*pb.TelemetryData)
		return data.TelemetryData{
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
		claims := make([]data.Claim, len(p.Claims))
		for i, c := range p.Claims {
			lines := make([]data.ServiceLine, len(c.Lines))
			for j, l := range c.Lines {
				lines[j] = data.ServiceLine{
					ServiceCode:       l.ServiceCode,
					ChargeAmount:      l.ChargeAmount,
					AdjudicatedAmount: l.AdjudicatedAmount,
				}
			}
			claims[i] = data.Claim{
				ClaimID:       c.ClaimId,
				PatientName:   c.PatientName,
				TotalCharge:   c.TotalCharge,
				PaymentAmount: c.PaymentAmount,
				Lines:         lines,
			}
		}
		return data.Edi835{
			PayerName:                p.PayerName,
			PayeeName:                p.PayeeName,
			PaymentDate:              formatTimeMs(p.PaymentDate),
			TotalActualAmount:        p.TotalActualAmount,
			TransactionControlNumber: p.TransactionControlNumber,
			Claims:                   claims,
		}, nil
	default:
		return nil, fmt.Errorf("fromProto: %s", name)
	}
}
