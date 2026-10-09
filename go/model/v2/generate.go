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
	EventID    string      `json:"event_id" avro:"event_id" msgpack:"event_id"`
	EventType  string      `json:"event_type" avro:"event_type" msgpack:"event_type"`
	OccurredAt int64       `json:"occurred_at" avro:"occurred_at" msgpack:"occurred_at"`
	Producer   string      `json:"producer" avro:"producer" msgpack:"producer"`
	Attrs      []EventAttr `json:"attrs" avro:"attrs" msgpack:"attrs"`
}

// TableRow is one wide flat row. Proto, Avro, and SBE name the record Table.
// Field order is 16 float64, 4 int64, then 2 strings.
type TableRow struct {
	FFloat0  float64 `json:"f_float_0" avro:"f_float_0" msgpack:"f_float_0"`
	FFloat1  float64 `json:"f_float_1" avro:"f_float_1" msgpack:"f_float_1"`
	FFloat2  float64 `json:"f_float_2" avro:"f_float_2" msgpack:"f_float_2"`
	FFloat3  float64 `json:"f_float_3" avro:"f_float_3" msgpack:"f_float_3"`
	FFloat4  float64 `json:"f_float_4" avro:"f_float_4" msgpack:"f_float_4"`
	FFloat5  float64 `json:"f_float_5" avro:"f_float_5" msgpack:"f_float_5"`
	FFloat6  float64 `json:"f_float_6" avro:"f_float_6" msgpack:"f_float_6"`
	FFloat7  float64 `json:"f_float_7" avro:"f_float_7" msgpack:"f_float_7"`
	FFloat8  float64 `json:"f_float_8" avro:"f_float_8" msgpack:"f_float_8"`
	FFloat9  float64 `json:"f_float_9" avro:"f_float_9" msgpack:"f_float_9"`
	FFloat10 float64 `json:"f_float_10" avro:"f_float_10" msgpack:"f_float_10"`
	FFloat11 float64 `json:"f_float_11" avro:"f_float_11" msgpack:"f_float_11"`
	FFloat12 float64 `json:"f_float_12" avro:"f_float_12" msgpack:"f_float_12"`
	FFloat13 float64 `json:"f_float_13" avro:"f_float_13" msgpack:"f_float_13"`
	FFloat14 float64 `json:"f_float_14" avro:"f_float_14" msgpack:"f_float_14"`
	FFloat15 float64 `json:"f_float_15" avro:"f_float_15" msgpack:"f_float_15"`
	FInt0    int64   `json:"f_int_0" avro:"f_int_0" msgpack:"f_int_0"`
	FInt1    int64   `json:"f_int_1" avro:"f_int_1" msgpack:"f_int_1"`
	FInt2    int64   `json:"f_int_2" avro:"f_int_2" msgpack:"f_int_2"`
	FInt3    int64   `json:"f_int_3" avro:"f_int_3" msgpack:"f_int_3"`
	FStr0    string  `json:"f_str_0" avro:"f_str_0" msgpack:"f_str_0"`
	FStr1    string  `json:"f_str_1" avro:"f_str_1" msgpack:"f_str_1"`
}

type NestedMeta struct {
	Region  string `json:"region" avro:"region" msgpack:"region"`
	Version int32  `json:"version" avro:"version" msgpack:"version"`
}

type NestedItem struct {
	SKU        string `json:"sku" avro:"sku" msgpack:"sku"`
	Qty        int32  `json:"qty" avro:"qty" msgpack:"qty"`
	PriceMinor int64  `json:"price_minor" avro:"price_minor" msgpack:"price_minor"`
}

type NestedRow struct {
	ID     string       `json:"id" avro:"id" msgpack:"id"`
	Status int32        `json:"status" avro:"status" msgpack:"status"`
	Meta   NestedMeta   `json:"meta" avro:"meta" msgpack:"meta"`
	Items  []NestedItem `json:"items" avro:"items" msgpack:"items"`
}

type SignalLeg struct {
	LegID  int64 `json:"leg_id" avro:"leg_id" msgpack:"leg_id"`
	LegQty int32 `json:"leg_qty" avro:"leg_qty" msgpack:"leg_qty"`
	LegPad int32 `json:"leg_pad" avro:"leg_pad" msgpack:"leg_pad"`
}

// Signal domain order is fixed fields, then strings, then legs.
// The SBE body puts the legs group before the strings.
type Signal struct {
	Seq           int64       `json:"seq" avro:"seq" msgpack:"seq"`
	TS            int64       `json:"ts" avro:"ts" msgpack:"ts"`
	PriceMantissa int64       `json:"price_mantissa" avro:"price_mantissa" msgpack:"price_mantissa"`
	Qty           int32       `json:"qty" avro:"qty" msgpack:"qty"`
	Flags         int32       `json:"flags" avro:"flags" msgpack:"flags"`
	Symbol        string      `json:"symbol" avro:"symbol" msgpack:"symbol"`
	Venue         string      `json:"venue" avro:"venue" msgpack:"venue"`
	Legs          []SignalLeg `json:"legs" avro:"legs" msgpack:"legs"`
}

// Region is a shared node. Several orders in one Book hold this same pointer.
type Region struct {
	Code    string `json:"code" avro:"code" msgpack:"code"`
	Note    string `json:"note" avro:"note" msgpack:"note"`
	Version int32  `json:"version" avro:"version" msgpack:"version"`
}

// Order points at a Region. The pointer is shared; the order itself is not.
type Order struct {
	SKU    string  `json:"sku" avro:"sku" msgpack:"sku"`
	Qty    int32   `json:"qty" avro:"qty" msgpack:"qty"`
	Region *Region `json:"region" avro:"region" msgpack:"region"`
}

// Person is one node of a ring. Next may point at this same person when the ring size is 1.
type Person struct {
	Name string  `json:"name" avro:"name" msgpack:"name"`
	Next *Person `json:"next" avro:"next" msgpack:"next"`
}

// Book is one graph: shared region nodes and a person ring. Graphs do not share nodes.
type Book struct {
	Orders []Order   `json:"orders" avro:"orders" msgpack:"orders"`
	People []*Person `json:"people" avro:"people" msgpack:"people"`
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
	case "table", "table_project":
		smin, smax := slen(typeConfig, 3, 16)
		vocab := sharedVocab(seed, typeID, smin, smax)
		return makeTable(r, typeConfig, vocab)
	case "nested_table":
		return makeNestedTable(r, typeConfig)
	case "signal":
		return makeSignal(r, typeConfig)
	case "graph":
		return makeGraph(r, typeConfig)
	default:
		return nil
	}
}

func cfgFloat(m map[string]any, key string, def float64) float64 {
	if m == nil {
		return def
	}
	v, ok := m[key]
	if !ok || v == nil {
		return def
	}
	switch t := v.(type) {
	case float64:
		return t
	case float32:
		return float64(t)
	case int:
		return float64(t)
	case int64:
		return float64(t)
	default:
		return def
	}
}

func cfgMap(m map[string]any, key string) map[string]any {
	if m == nil {
		return nil
	}
	v, ok := m[key]
	if !ok || v == nil {
		return nil
	}
	t, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	return t
}

func slen(cfg map[string]any, defMin, defMax int) (int, int) {
	sl := cfgMap(cfg, "string_len")
	return cfgInt(sl, "min", defMin), cfgInt(sl, "max", defMax)
}

func irange(cfg map[string]any) (int, int) {
	ir := cfgMap(cfg, "int_range")
	return cfgInt(ir, "min", 0), cfgInt(ir, "max", 1_000_000)
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
		Producer:   r.word(3, 12), Attrs: attrs,
	}
}

func sharedVocab(seed uint64, typeID string, smin, smax int) []string {
	vr := newRNG(mixSeed(seed, typeID+"#vocab", 0))
	out := make([]string, 32)
	for i := range out {
		out[i] = vr.word(smin, smax)
	}
	return out
}

func pickWord(r *rng, vocab []string, duplication float64, smin, smax int) string {
	if len(vocab) > 0 && r.nextF64() < duplication {
		return vocab[r.nextInt(0, len(vocab)-1)]
	}
	return r.word(smin, smax)
}

func makeTable(r *rng, cfg map[string]any, vocab []string) TableRow {
	lo, hi := irange(cfg)
	smin, smax := slen(cfg, 3, 16)
	dup := cfgFloat(cfg, "duplication", 0.5)
	var floats [16]float64
	for i := range floats {
		floats[i] = r.nextF64() * 1000
	}
	var ints [4]int64
	for i := range ints {
		ints[i] = int64(r.nextInt(lo, hi))
	}
	return TableRow{
		FFloat0: floats[0], FFloat1: floats[1], FFloat2: floats[2], FFloat3: floats[3],
		FFloat4: floats[4], FFloat5: floats[5], FFloat6: floats[6], FFloat7: floats[7],
		FFloat8: floats[8], FFloat9: floats[9], FFloat10: floats[10], FFloat11: floats[11],
		FFloat12: floats[12], FFloat13: floats[13], FFloat14: floats[14], FFloat15: floats[15],
		FInt0: ints[0], FInt1: ints[1], FInt2: ints[2], FInt3: ints[3],
		FStr0: pickWord(r, vocab, dup, smin, smax),
		FStr1: pickWord(r, vocab, dup, smin, smax),
	}
}

func makeNestedTable(r *rng, cfg map[string]any) NestedRow {
	smin, smax := slen(cfg, 3, 12)
	n := cfgInt(cfg, "children", 4)
	row := NestedRow{
		ID:     r.word(8, 12),
		Status: int32(r.nextInt(0, 5)),
		Meta: NestedMeta{
			Region:  r.word(2, 4),
			Version: int32(r.nextInt(1, 10)),
		},
	}
	row.Items = make([]NestedItem, n)
	for i := range row.Items {
		row.Items[i] = NestedItem{
			SKU:        r.word(smin, smax),
			Qty:        int32(r.nextInt(1, 100)),
			PriceMinor: int64(r.nextInt(0, 100000)),
		}
	}
	return row
}

func makeSignal(r *rng, cfg map[string]any) Signal {
	smin, smax := slen(cfg, 3, 12)
	n := cfgInt(cfg, "group_count", 4)
	sig := Signal{
		Seq:           int64(r.nextInt(0, 1_000_000_000)),
		TS:            baseTSMS + int64(r.nextInt(0, 86_400_000)),
		PriceMantissa: int64(r.nextInt(0, 1_000_000_000)),
		Qty:           int32(r.nextInt(0, 10_000)),
		Flags:         int32(r.nextInt(0, 65_535)),
		Symbol:        r.word(smin, smax),
		Venue:         r.word(smin, smax),
	}
	sig.Legs = make([]SignalLeg, n)
	for i := range sig.Legs {
		sig.Legs[i] = SignalLeg{
			LegID:  int64(r.nextInt(0, 1_000_000)),
			LegQty: int32(r.nextInt(0, 10_000)),
			LegPad: 0,
		}
	}
	return sig
}

// makeGraph builds one graph. Call order is the generator contract: every region
// (code, 64-char note, version), then every order (sku, qty; region i%region_count
// is the same pointer), then person names, then the ring. The ring draws no RNG.
func makeGraph(r *rng, cfg map[string]any) Book {
	smin, smax := slen(cfg, 8, 16)
	nOrders := cfgInt(cfg, "order_count", 32)
	nRegions := cfgInt(cfg, "region_count", 4)
	ring := cfgInt(cfg, "ring_size", 8)
	if nRegions < 1 || ring < 1 {
		panic("graph: region_count and ring_size must be >= 1")
	}
	regions := make([]*Region, nRegions)
	for i := range regions {
		regions[i] = &Region{
			Code:    r.word(smin, smax),
			Note:    r.word(64, 64),
			Version: int32(r.nextInt(1, 10)),
		}
	}
	orders := make([]Order, nOrders)
	for i := range orders {
		orders[i] = Order{
			SKU:    r.word(smin, smax),
			Qty:    int32(r.nextInt(1, 100)),
			Region: regions[i%nRegions],
		}
	}
	people := make([]*Person, ring)
	for i := range people {
		people[i] = &Person{Name: r.word(smin, smax)}
	}
	for i := range people {
		people[i].Next = people[(i+1)%ring]
	}
	return Book{Orders: orders, People: people}
}

// ProjectFFloat0 returns f_float_0 for one row or a batch.
// table_project compares this slice, including when N is 1.
func ProjectFFloat0(v any) []float64 {
	switch t := v.(type) {
	case TableRow:
		return []float64{t.FFloat0}
	case *TableRow:
		if t == nil {
			return nil
		}
		return []float64{t.FFloat0}
	case []TableRow:
		out := make([]float64, len(t))
		for i := range t {
			out[i] = t[i].FFloat0
		}
		return out
	case []float64:
		return t
	default:
		return nil
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
