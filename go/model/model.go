// Package data holds canonical test payloads for the Go serializer harness.
// Collection sizes and seed match schemas/test_data_config.json (seed=42).
package model

import (
	"fmt"
	"math"
)

type Gender int32

const (
	GenderMale Gender = iota
	GenderFemale
)

type Passport struct {
	Number         string `json:"number" msgpack:"number" bson:"number" cbor:"number" avro:"number"`
	Authority      string `json:"authority" msgpack:"authority" bson:"authority" cbor:"authority" avro:"authority"`
	ExpirationDate string `json:"expiration_date" msgpack:"expiration_date" bson:"expiration_date" cbor:"expiration_date" avro:"expiration_date"`
}

type PoliceRecord struct {
	ID        int32  `json:"id" msgpack:"id" bson:"id" cbor:"id" avro:"id"`
	CrimeCode string `json:"crime_code" msgpack:"crime_code" bson:"crime_code" cbor:"crime_code" avro:"crime_code"`
}

type Person struct {
	FirstName     string         `json:"first_name" msgpack:"first_name" bson:"first_name" cbor:"first_name" avro:"first_name"`
	LastName      string         `json:"last_name" msgpack:"last_name" bson:"last_name" cbor:"last_name" avro:"last_name"`
	Age           int32          `json:"age" msgpack:"age" bson:"age" cbor:"age" avro:"age"`
	Gender        Gender         `json:"gender" msgpack:"gender" bson:"gender" cbor:"gender" avro:"gender"`
	Passport      *Passport      `json:"passport" msgpack:"passport" bson:"passport" cbor:"passport" avro:"passport"`
	PoliceRecords []PoliceRecord `json:"police_records" msgpack:"police_records" bson:"police_records" cbor:"police_records" avro:"police_records"`
}

type SimpleObject struct {
	ID        int32  `json:"id" msgpack:"id" bson:"id" cbor:"id" avro:"id"`
	Name      string `json:"name" msgpack:"name" bson:"name" cbor:"name" avro:"name"`
	Timestamp string `json:"timestamp" msgpack:"timestamp" bson:"timestamp" cbor:"timestamp" avro:"timestamp"`
	IsActive  bool   `json:"is_active" msgpack:"is_active" bson:"is_active" cbor:"is_active" avro:"is_active"`
}

type StringArrayObject struct {
	Items []string `json:"items" msgpack:"items" bson:"items" cbor:"items" avro:"items"`
}

type TelemetryData struct {
	ID                  string    `json:"id" msgpack:"id" bson:"id" cbor:"id" avro:"id"`
	DataSource          string    `json:"data_source" msgpack:"data_source" bson:"data_source" cbor:"data_source" avro:"data_source"`
	TimeStamp           string    `json:"time_stamp" msgpack:"time_stamp" bson:"time_stamp" cbor:"time_stamp" avro:"time_stamp"`
	Param1              int32     `json:"param1" msgpack:"param1" bson:"param1" cbor:"param1" avro:"param1"`
	Param2              int32     `json:"param2" msgpack:"param2" bson:"param2" cbor:"param2" avro:"param2"`
	Measurements        []float64 `json:"measurements" msgpack:"measurements" bson:"measurements" cbor:"measurements" avro:"measurements"`
	AssociatedProblemID int32     `json:"associated_problem_id" msgpack:"associated_problem_id" bson:"associated_problem_id" cbor:"associated_problem_id" avro:"associated_problem_id"`
	AssociatedLogID     int32     `json:"associated_log_id" msgpack:"associated_log_id" bson:"associated_log_id" cbor:"associated_log_id" avro:"associated_log_id"`
	WasProcessed        bool      `json:"was_processed" msgpack:"was_processed" bson:"was_processed" cbor:"was_processed" avro:"was_processed"`
}

type ServiceLine struct {
	ServiceCode       string  `json:"service_code" msgpack:"service_code" bson:"service_code" cbor:"service_code" avro:"service_code"`
	ChargeAmount      float64 `json:"charge_amount" msgpack:"charge_amount" bson:"charge_amount" cbor:"charge_amount" avro:"charge_amount"`
	AdjudicatedAmount float64 `json:"adjudicated_amount" msgpack:"adjudicated_amount" bson:"adjudicated_amount" cbor:"adjudicated_amount" avro:"adjudicated_amount"`
}

type Claim struct {
	ClaimID       string        `json:"claim_id" msgpack:"claim_id" bson:"claim_id" cbor:"claim_id" avro:"claim_id"`
	PatientName   string        `json:"patient_name" msgpack:"patient_name" bson:"patient_name" cbor:"patient_name" avro:"patient_name"`
	TotalCharge   float64       `json:"total_charge" msgpack:"total_charge" bson:"total_charge" cbor:"total_charge" avro:"total_charge"`
	PaymentAmount float64       `json:"payment_amount" msgpack:"payment_amount" bson:"payment_amount" cbor:"payment_amount" avro:"payment_amount"`
	Lines         []ServiceLine `json:"lines" msgpack:"lines" bson:"lines" cbor:"lines" avro:"lines"`
}

type Edi835 struct {
	PayerName                string  `json:"payer_name" msgpack:"payer_name" bson:"payer_name" cbor:"payer_name" avro:"payer_name"`
	PayeeName                string  `json:"payee_name" msgpack:"payee_name" bson:"payee_name" cbor:"payee_name" avro:"payee_name"`
	PaymentDate              string  `json:"payment_date" msgpack:"payment_date" bson:"payment_date" cbor:"payment_date" avro:"payment_date"`
	TotalActualAmount        float64 `json:"total_actual_amount" msgpack:"total_actual_amount" bson:"total_actual_amount" cbor:"total_actual_amount" avro:"total_actual_amount"`
	TransactionControlNumber string  `json:"transaction_control_number" msgpack:"transaction_control_number" bson:"transaction_control_number" cbor:"transaction_control_number" avro:"transaction_control_number"`
	Claims                   []Claim `json:"claims" msgpack:"claims" bson:"claims" cbor:"claims" avro:"claims"`
}

// IntegerValue wraps the primitive Integer fixture.
type IntegerValue struct {
	Value int32 `json:"value" msgpack:"value" bson:"value" cbor:"value" avro:"value"`
}

// Fixture is one named payload used by the runner.
type Fixture struct {
	Name  string
	Value any
}

// Rng is a deterministic xorshift generator (seed aligned with other harnesses).
type Rng struct {
	state uint64
}

func NewRng(seed uint64) *Rng {
	if seed == 0 {
		seed = 1
	}
	return &Rng{state: seed}
}

func (r *Rng) nextU64() uint64 {
	x := r.state
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	r.state = x
	return x
}

func (r *Rng) nextI32(lo, hi int32) int32 {
	if hi <= lo {
		return lo
	}
	span := uint64(hi - lo + 1)
	return lo + int32(r.nextU64()%span)
}

func (r *Rng) nextF64() float64 {
	return float64(r.nextU64()) / float64(^uint64(0))
}

func (r *Rng) nextBool() bool {
	return r.nextU64()&1 == 1
}

func (r *Rng) word(minLen, maxLen int) string {
	const pool = "abcdefghijklmnopqrstuvwxyz"
	n := int(r.nextI32(int32(minLen), int32(maxLen)))
	b := make([]byte, n)
	for i := 0; i < n; i++ {
		// mod on uint64 first — casting a full uint64 to int can be negative
		b[i] = pool[r.nextU64()%uint64(len(pool))]
	}
	return string(b)
}

func makePerson(rng *Rng) Person {
	records := make([]PoliceRecord, 5)
	for i := range records {
		records[i] = PoliceRecord{ID: int32(i), CrimeCode: rng.word(3, 8)}
	}
	g := GenderMale
	if rng.nextBool() {
		g = GenderFemale
	}
	return Person{
		FirstName: rng.word(3, 10),
		LastName:  rng.word(3, 10),
		Age:       rng.nextI32(1, 99),
		Gender:    g,
		Passport: &Passport{
			Number:         rng.word(8, 12),
			Authority:      rng.word(3, 10),
			ExpirationDate: "2030-01-01T00:00:00Z",
		},
		PoliceRecords: records,
	}
}

func makeSimple(rng *Rng) SimpleObject {
	return SimpleObject{
		ID:        rng.nextI32(0, 1_000_000),
		Name:      rng.word(3, 10),
		Timestamp: "2024-01-01T00:00:00Z",
		IsActive:  rng.nextBool(),
	}
}

func makeStringArray(rng *Rng) StringArrayObject {
	items := make([]string, 100)
	for i := range items {
		items[i] = rng.word(3, 10)
	}
	return StringArrayObject{Items: items}
}

func makeTelemetry(rng *Rng) TelemetryData {
	m := make([]float64, 100)
	for i := range m {
		m[i] = rng.nextF64() * 100
	}
	return TelemetryData{
		ID:                  rng.word(8, 12),
		DataSource:          rng.word(3, 10),
		TimeStamp:           "2024-01-01T00:00:00Z",
		Param1:              rng.nextI32(0, 1000),
		Param2:              rng.nextI32(0, 1000),
		Measurements:        m,
		AssociatedProblemID: rng.nextI32(0, 10000),
		AssociatedLogID:     rng.nextI32(0, 10000),
		WasProcessed:        rng.nextBool(),
	}
}

func makeEDI(rng *Rng) Edi835 {
	claims := make([]Claim, 5)
	for c := 0; c < 5; c++ {
		lines := make([]ServiceLine, 3)
		for i := range lines {
			lines[i] = ServiceLine{
				ServiceCode:       rng.word(3, 6),
				ChargeAmount:      rng.nextF64() * 1000,
				AdjudicatedAmount: rng.nextF64() * 1000,
			}
		}
		claims[c] = Claim{
			ClaimID:       fmt.Sprintf("C%d", c),
			PatientName:   rng.word(3, 10),
			TotalCharge:   rng.nextF64() * 5000,
			PaymentAmount: rng.nextF64() * 5000,
			Lines:         lines,
		}
	}
	return Edi835{
		PayerName:                rng.word(3, 10),
		PayeeName:                rng.word(3, 10),
		PaymentDate:              "2024-01-01T00:00:00Z",
		TotalActualAmount:        rng.nextF64() * 10000,
		TransactionControlNumber: rng.word(8, 12),
		Claims:                   claims,
	}
}

// AllFixtures returns the standard suite (ObjectGraph omitted — cycles unsupported by most formats).
func AllFixtures(seed uint64) []Fixture {
	rng := NewRng(seed)
	return []Fixture{
		{Name: "Person", Value: makePerson(rng)},
		{Name: "Integer", Value: IntegerValue{Value: rng.nextI32(0, 1_000_000)}},
		{Name: "Telemetry", Value: makeTelemetry(rng)},
		{Name: "SimpleObject", Value: makeSimple(rng)},
		{Name: "StringArray", Value: makeStringArray(rng)},
		{Name: "EDI_835", Value: makeEDI(rng)},
	}
}

// Fidelity checks semantic equality with float tolerance.
func Fidelity(expected, actual any) bool {
	switch av := expected.(type) {
	case Person:
		bv, ok := actual.(Person)
		if !ok {
			return false
		}
		if av.FirstName != bv.FirstName || av.LastName != bv.LastName || av.Age != bv.Age || av.Gender != bv.Gender {
			return false
		}
		if (av.Passport == nil) != (bv.Passport == nil) {
			return false
		}
		if av.Passport != nil && (av.Passport.Number != bv.Passport.Number || av.Passport.Authority != bv.Passport.Authority) {
			return false
		}
		if len(av.PoliceRecords) != len(bv.PoliceRecords) {
			return false
		}
		for i := range av.PoliceRecords {
			if av.PoliceRecords[i] != bv.PoliceRecords[i] {
				return false
			}
		}
		return true
	case IntegerValue:
		bv, ok := actual.(IntegerValue)
		return ok && av.Value == bv.Value
	case TelemetryData:
		bv, ok := actual.(TelemetryData)
		if !ok || av.ID != bv.ID || av.Param1 != bv.Param1 || len(av.Measurements) != len(bv.Measurements) {
			return false
		}
		for i := range av.Measurements {
			if math.Abs(av.Measurements[i]-bv.Measurements[i]) > 1e-9 {
				return false
			}
		}
		return true
	case SimpleObject:
		bv, ok := actual.(SimpleObject)
		return ok && av.ID == bv.ID && av.Name == bv.Name && av.IsActive == bv.IsActive
	case StringArrayObject:
		bv, ok := actual.(StringArrayObject)
		if !ok || len(av.Items) != len(bv.Items) {
			return false
		}
		for i := range av.Items {
			if av.Items[i] != bv.Items[i] {
				return false
			}
		}
		return true
	case Edi835:
		bv, ok := actual.(Edi835)
		if !ok || av.PayerName != bv.PayerName || av.PayeeName != bv.PayeeName || len(av.Claims) != len(bv.Claims) {
			return false
		}
		if math.Abs(av.TotalActualAmount-bv.TotalActualAmount) > 1e-6 {
			return false
		}
		return true
	default:
		return fmt.Sprintf("%#v", expected) == fmt.Sprintf("%#v", actual)
	}
}

// NewEmptyPtr allocates a pointer to a zero value of the same concrete type as v.
func NewEmptyPtr(v any) any {
	switch v.(type) {
	case Person:
		return &Person{}
	case IntegerValue:
		return &IntegerValue{}
	case TelemetryData:
		return &TelemetryData{}
	case SimpleObject:
		return &SimpleObject{}
	case StringArrayObject:
		return &StringArrayObject{}
	case Edi835:
		return &Edi835{}
	default:
		return nil
	}
}

// Deref converts an unmarshal target pointer back to a value.
func Deref(ptr any) any {
	switch p := ptr.(type) {
	case *Person:
		return *p
	case *IntegerValue:
		return *p
	case *TelemetryData:
		return *p
	case *SimpleObject:
		return *p
	case *StringArrayObject:
		return *p
	case *Edi835:
		return *p
	default:
		return ptr
	}
}
