// Package v2 implements Data Model v2 make_one generators (within-language deterministic).
// Wire into the main harness via BENCHMARK_DATA_MODEL=v2 when the runner supports it.
// Cross-language payload identity is not required.
package v2



// Message is a single-level mixed-primitive record.
type Message struct {
	FBool    bool    `json:"f_bool" avro:"f_bool" msgpack:"f_bool"`
	FInt32   int32   `json:"f_int32" avro:"f_int32" msgpack:"f_int32"`
	FInt64   int64   `json:"f_int64" avro:"f_int64" msgpack:"f_int64"`
	FFloat64 float64 `json:"f_float64" avro:"f_float64" msgpack:"f_float64"`
	FString  string  `json:"f_string" avro:"f_string" msgpack:"f_string"`
	FBool2   bool    `json:"f_bool_2" avro:"f_bool_2" msgpack:"f_bool_2"`
	FInt32_2 int32   `json:"f_int32_2" avro:"f_int32_2" msgpack:"f_int32_2"`
	FString2 string  `json:"f_string_2" avro:"f_string_2" msgpack:"f_string_2"`
}

type DocumentMeta struct {
	Region  string `json:"region" avro:"region" msgpack:"region"`
	Version int32  `json:"version" avro:"version" msgpack:"version"`
}

type DocumentItem struct {
	SKU        string `json:"sku" avro:"sku" msgpack:"sku"`
	Qty        int32  `json:"qty" avro:"qty" msgpack:"qty"`
	PriceMinor int64  `json:"price_minor" avro:"price_minor" msgpack:"price_minor"`
}

type Document struct {
	ID     string         `json:"id" avro:"id" msgpack:"id"`
	Status int32          `json:"status" avro:"status" msgpack:"status"`
	Meta   DocumentMeta   `json:"meta" avro:"meta" msgpack:"meta"`
	Items  []DocumentItem `json:"items" avro:"items" msgpack:"items"`
}

type Telemetry struct {
	Source string    `json:"source" avro:"source" msgpack:"source"`
	TS     int64     `json:"ts" avro:"ts" msgpack:"ts"`
	Tags   []string  `json:"tags" avro:"tags" msgpack:"tags"`
	Values []float64 `json:"values" avro:"values" msgpack:"values"`
}

type Strings struct {
	Items []string `json:"items" avro:"items" msgpack:"items"`
}

type EventAttr struct {
	Key   string `json:"key" avro:"key" msgpack:"key"`
	Value string `json:"value" avro:"value" msgpack:"value"`
}

type Event struct {
	EventID     string      `json:"event_id" avro:"event_id" msgpack:"event_id"`
	EventType   string      `json:"event_type" avro:"event_type" msgpack:"event_type"`
	OccurredAt  int64       `json:"occurred_at" avro:"occurred_at" msgpack:"occurred_at"`
	Producer    string      `json:"producer" avro:"producer" msgpack:"producer"`
	Attrs       []EventAttr `json:"attrs" avro:"attrs" msgpack:"attrs"`
}

const baseTSMS int64 = 1704067200000

// Deterministic xorshift64* (within-language only). Zero seed uses floor(2^64/φ)
// = 0x9E3779B97F4A7C15 (golden ratio; nothing-up-my-sleeve avalanche constant).
type rng struct{ state uint64 }

func newRNG(seed uint64) *rng {
	if seed == 0 {
		seed = 0x9E3779B97F4A7C15 // floor(2^64/φ)
	}
	return &rng{state: seed}
}

func (r *rng) nextU64() uint64 {
	x := r.state
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	r.state = x
	return x
}

func (r *rng) nextInt(lo, hi int) int {
	if hi <= lo {
		return lo
	}
	return lo + int(r.nextU64()%uint64(hi-lo+1))
}

func (r *rng) nextBool() bool { return r.nextU64()&1 == 1 }

func (r *rng) nextF64() float64 {
	return float64(r.nextU64()>>11) / float64(uint64(1)<<53)
}

func (r *rng) word(minL, maxL int) string {
	n := r.nextInt(minL, maxL)
	const alpha = "abcdefghijklmnopqrstuvwxyz"
	b := make([]byte, n)
	for i := 0; i < n; i++ {
		b[i] = alpha[r.nextU64()%26]
	}
	return string(b)
}

func mixSeed(seed uint64, typeID string, idx int) uint64 {
	h := seed
	for i := 0; i < len(typeID); i++ {
		h = (h ^ uint64(typeID[i])) * 0x100000001B3
	}
	h ^= uint64(idx) * 0x9E3779B97F4A7C15
	if h == 0 {
		return 1
	}
	return h
}

// MakeOne builds one instance for typeID. typeConfig keys match the Python catalog.
func MakeOne(typeID string, typeConfig map[string]any, seed uint64, instanceIndex int) any {
	r := newRNG(mixSeed(seed, typeID, instanceIndex))
	switch typeID {
	case "message":
		return makeMessage(r, typeConfig)
	case "document":
		return makeDocument(r, typeConfig)
	case "telemetry":
		return makeTelemetry(r, typeConfig)
	case "strings":
		return makeStrings(r, typeConfig)
	case "event":
		return makeEvent(r, typeConfig)
	default:
		return nil
	}
}

func cfgInt(m map[string]any, key string, def int) int {
	if m == nil {
		return def
	}
	v, ok := m[key]
	if !ok || v == nil {
		return def
	}
	switch t := v.(type) {
	case int:
		return t
	case int64:
		return int(t)
	case float64:
		return int(t)
	default:
		return def
	}
}

func makeMessage(r *rng, cfg map[string]any) Message {
	_ = cfg
	return Message{
		FBool: r.nextBool(), FInt32: int32(r.nextInt(0, 1_000_000)),
		FInt64: int64(r.nextInt(0, 1_000_000)), FFloat64: r.nextF64() * 1000,
		FString: r.word(3, 16), FBool2: r.nextBool(),
		FInt32_2: int32(r.nextInt(0, 1_000_000)), FString2: r.word(3, 16),
	}
}

func makeDocument(r *rng, cfg map[string]any) Document {
	n := cfgInt(cfg, "children", 8)
	items := make([]DocumentItem, n)
	for i := range items {
		items[i] = DocumentItem{SKU: r.word(3, 12), Qty: int32(r.nextInt(1, 100)), PriceMinor: int64(r.nextInt(0, 100000))}
	}
	return Document{ID: r.word(8, 12), Status: int32(r.nextInt(0, 5)),
		Meta: DocumentMeta{Region: r.word(2, 4), Version: int32(r.nextInt(1, 10))}, Items: items}
}

func makeTelemetry(r *rng, cfg map[string]any) Telemetry {
	pts := cfgInt(cfg, "points", 32)
	tagsN := cfgInt(cfg, "tag_count", 2)
	tags := make([]string, tagsN)
	for i := range tags {
		tags[i] = r.word(3, 10)
	}
	vals := make([]float64, pts)
	for i := range vals {
		vals[i] = r.nextF64() * 100
	}
	return Telemetry{Source: r.word(3, 10), TS: baseTSMS + int64(r.nextInt(0, 86400000)), Tags: tags, Values: vals}
}

func makeStrings(r *rng, cfg map[string]any) Strings {
	n := cfgInt(cfg, "count", 32)
	items := make([]string, n)
	for i := range items {
		items[i] = r.word(3, 16)
	}
	return Strings{Items: items}
}

func makeEvent(r *rng, cfg map[string]any) Event {
	n := cfgInt(cfg, "attr_count", 4)
	attrs := make([]EventAttr, n)
	for i := range attrs {
		attrs[i] = EventAttr{Key: r.word(3, 12), Value: r.word(3, 12)}
	}
	return Event{
		EventID: r.word(8, 12), EventType: r.word(3, 12),
		OccurredAt: baseTSMS + int64(r.nextInt(0, 86400000)),
		Producer: r.word(3, 12), Attrs: attrs,
	}
}

// Instances returns N instances for one ser/deser call.
func Instances(typeID string, typeConfig map[string]any, seed uint64, n int) []any {
	out := make([]any, n)
	for i := 0; i < n; i++ {
		out[i] = MakeOne(typeID, typeConfig, seed, i)
	}
	return out
}
