package serializers

import (
	"bytes"
	"context"
	"fmt"
	"io"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/ipc"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/compress"
	"github.com/apache/arrow-go/v18/parquet/file"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// arrow-go v18 WriterProperties defaults to uncompressed. The suite parquet
// row sets Snappy explicitly so it matches the pyarrow default and differs
// from parquet-uncompressed. Schemas and writer properties are built once.
// Record batches are built inside SerializeBytes.

const (
	kindIPC int = iota
	kindParquet
)

var (
	arrowMem          = memory.DefaultAllocator
	schemaTable       *arrow.Schema
	schemaNested      *arrow.Schema
	schemaSignal      *arrow.Schema
	propsSnappy       *parquet.WriterProperties
	propsUncompressed *parquet.WriterProperties
)

func init() {
	schemaTable = tableArrowSchema()
	schemaNested = nestedArrowSchema()
	schemaSignal = signalArrowSchema()
	propsSnappy = parquet.NewWriterProperties(parquet.WithCompression(compress.Codecs.Snappy))
	propsUncompressed = parquet.NewWriterProperties(parquet.WithCompression(compress.Codecs.Uncompressed))
}

func f64Field(name string) arrow.Field {
	return arrow.Field{Name: name, Type: arrow.PrimitiveTypes.Float64, Nullable: true}
}

func i64Field(name string) arrow.Field {
	return arrow.Field{Name: name, Type: arrow.PrimitiveTypes.Int64, Nullable: true}
}

func i32Field(name string) arrow.Field {
	return arrow.Field{Name: name, Type: arrow.PrimitiveTypes.Int32, Nullable: true}
}

func strField(name string) arrow.Field {
	return arrow.Field{Name: name, Type: arrow.BinaryTypes.String, Nullable: true}
}

func tableArrowSchema() *arrow.Schema {
	fields := make([]arrow.Field, 0, 22)
	for i := 0; i < 16; i++ {
		fields = append(fields, f64Field(fmt.Sprintf("f_float_%d", i)))
	}
	for i := 0; i < 4; i++ {
		fields = append(fields, i64Field(fmt.Sprintf("f_int_%d", i)))
	}
	fields = append(fields, strField("f_str_0"), strField("f_str_1"))
	return arrow.NewSchema(fields, nil)
}

func nestedArrowSchema() *arrow.Schema {
	meta := arrow.StructOf(strField("region"), i32Field("version"))
	item := arrow.StructOf(strField("sku"), i32Field("qty"), i64Field("price_minor"))
	fields := []arrow.Field{
		strField("id"),
		i32Field("status"),
		{Name: "meta", Type: meta, Nullable: true},
		{Name: "items", Type: arrow.ListOf(item), Nullable: true},
	}
	return arrow.NewSchema(fields, nil)
}

func signalArrowSchema() *arrow.Schema {
	leg := arrow.StructOf(i64Field("leg_id"), i32Field("leg_qty"), i32Field("leg_pad"))
	fields := []arrow.Field{
		i64Field("seq"),
		i64Field("ts"),
		i64Field("price_mantissa"),
		i32Field("qty"),
		i32Field("flags"),
		strField("symbol"),
		strField("venue"),
		{Name: "legs", Type: arrow.ListOf(leg), Nullable: true},
	}
	return arrow.NewSchema(fields, nil)
}

// columnarArrow is arrow-ipc, parquet (Snappy), or parquet-uncompressed.
// Stream methods are adapted over the bytes API. table_project reads column 0
// only: parquet passes that index to GetRecordReader; IPC walks the record-batch
// buffer list (arrow-go's ipc.Reader has no included-fields option).
type columnarArrow struct {
	name    string
	kind    int
	props   *parquet.WriterProperties
	schema  *arrow.Schema
	fxName  string
	project bool
}

func newArrowIPC() *columnarArrow {
	return &columnarArrow{name: "arrow-ipc", kind: kindIPC}
}

func newParquet() *columnarArrow {
	return &columnarArrow{name: "parquet", kind: kindParquet, props: propsSnappy}
}

func newParquetUncompressed() *columnarArrow {
	return &columnarArrow{name: "parquet-uncompressed", kind: kindParquet, props: propsUncompressed}
}

func (s *columnarArrow) Name() string           { return s.name }
func (s *columnarArrow) Version() string        { return ModuleVersion("github.com/apache/arrow-go/v18") }
func (s *columnarArrow) StreamMode() StreamMode { return StreamAdapted }
func (s *columnarArrow) NativeKind() NativeKind { return NativeSchema }

func (s *columnarArrow) Supports(n string) bool {
	switch n {
	case "table", "table_project", "nested_table", "signal":
		return true
	default:
		return false
	}
}

func (s *columnarArrow) Prepare(fx model.Fixture) error {
	switch fx.Name {
	case "table", "table_project":
		s.schema = schemaTable
	case "nested_table":
		s.schema = schemaNested
	case "signal":
		s.schema = schemaSignal
	default:
		return fmt.Errorf("%s: unsupported type %s", s.name, fx.Name)
	}
	s.fxName = fx.Name
	s.project = fx.Name == "table_project"
	return nil
}

func (s *columnarArrow) SerializeBytes(fx model.Fixture) ([]byte, error) {
	rec, err := s.buildRecord(fx.Value)
	if err != nil {
		return nil, err
	}
	defer rec.Release()
	if s.kind == kindIPC {
		return writeIPC(s.schema, rec)
	}
	return writeParquet(s.schema, s.props, rec)
}

func (s *columnarArrow) DeserializeBytes(buf []byte) (any, error) {
	if s.schema == nil {
		return nil, fmt.Errorf("%s: prepare() required", s.name)
	}
	if s.project {
		if s.kind == kindIPC {
			return projectIPCFloat0(buf)
		}
		recs, release, err := readParquet(buf, []int{0})
		if err != nil {
			return nil, err
		}
		defer release()
		return floatsFromRecords(recs), nil
	}
	var (
		recs    []arrow.RecordBatch
		release func()
		err     error
	)
	if s.kind == kindIPC {
		recs, release, err = readIPC(buf, s.schema)
	} else {
		recs, release, err = readParquet(buf, nil)
	}
	if err != nil {
		return nil, err
	}
	defer release()
	return decodeRecords(s.fxName, recs)
}

func (s *columnarArrow) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *columnarArrow) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

func writeIPC(schema *arrow.Schema, rec arrow.RecordBatch) ([]byte, error) {
	var buf bytes.Buffer
	w := ipc.NewWriter(&buf, ipc.WithSchema(schema))
	if err := w.Write(rec); err != nil {
		_ = w.Close()
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeParquet(schema *arrow.Schema, props *parquet.WriterProperties, rec arrow.RecordBatch) ([]byte, error) {
	var buf bytes.Buffer
	fw, err := pqarrow.NewFileWriter(schema, &buf, props, pqarrow.DefaultWriterProps())
	if err != nil {
		return nil, err
	}
	if err := fw.Write(rec); err != nil {
		_ = fw.Close()
		return nil, err
	}
	if err := fw.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func readIPC(data []byte, schema *arrow.Schema) ([]arrow.RecordBatch, func(), error) {
	r, err := ipc.NewReader(bytes.NewReader(data), ipc.WithSchema(schema))
	if err != nil {
		return nil, nil, err
	}
	var recs []arrow.RecordBatch
	release := func() {
		for _, rec := range recs {
			rec.Release()
		}
		r.Release()
	}
	for {
		rec, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			release()
			return nil, nil, err
		}
		rec.Retain()
		recs = append(recs, rec)
	}
	return recs, release, nil
}

func readParquet(data []byte, cols []int) ([]arrow.RecordBatch, func(), error) {
	pf, err := file.NewParquetReader(bytes.NewReader(data))
	if err != nil {
		return nil, nil, err
	}
	fr, err := pqarrow.NewFileReader(pf, pqarrow.ArrowReadProperties{}, arrowMem)
	if err != nil {
		return nil, nil, err
	}
	rr, err := fr.GetRecordReader(context.Background(), cols, nil)
	if err != nil {
		return nil, nil, err
	}
	var recs []arrow.RecordBatch
	release := func() {
		for _, rec := range recs {
			rec.Release()
		}
		rr.Release()
	}
	for rr.Next() {
		rec := rr.RecordBatch()
		rec.Retain()
		recs = append(recs, rec)
	}
	if err := rr.Err(); err != nil {
		release()
		return nil, nil, err
	}
	return recs, release, nil
}

func (s *columnarArrow) buildRecord(v any) (arrow.RecordBatch, error) {
	switch s.fxName {
	case "table", "table_project":
		rows, err := asTableRows(v)
		if err != nil {
			return nil, err
		}
		return buildTableRecord(rows), nil
	case "nested_table":
		rows, err := asNestedRows(v)
		if err != nil {
			return nil, err
		}
		return buildNestedRecord(rows), nil
	case "signal":
		rows, err := asSignalRows(v)
		if err != nil {
			return nil, err
		}
		return buildSignalRecord(rows), nil
	default:
		return nil, fmt.Errorf("%s: unsupported type %s", s.name, s.fxName)
	}
}

func asTableRows(v any) ([]modelv2.TableRow, error) {
	switch t := v.(type) {
	case modelv2.TableRow:
		return []modelv2.TableRow{t}, nil
	case []modelv2.TableRow:
		return t, nil
	default:
		return nil, fmt.Errorf("arrow: want TableRow, got %T", v)
	}
}

func asNestedRows(v any) ([]modelv2.NestedRow, error) {
	switch t := v.(type) {
	case modelv2.NestedRow:
		return []modelv2.NestedRow{t}, nil
	case []modelv2.NestedRow:
		return t, nil
	default:
		return nil, fmt.Errorf("arrow: want NestedRow, got %T", v)
	}
}

func asSignalRows(v any) ([]modelv2.Signal, error) {
	switch t := v.(type) {
	case modelv2.Signal:
		return []modelv2.Signal{t}, nil
	case []modelv2.Signal:
		return t, nil
	default:
		return nil, fmt.Errorf("arrow: want Signal, got %T", v)
	}
}

func tableFloats(row modelv2.TableRow) [16]float64 {
	return [16]float64{
		row.FFloat0, row.FFloat1, row.FFloat2, row.FFloat3,
		row.FFloat4, row.FFloat5, row.FFloat6, row.FFloat7,
		row.FFloat8, row.FFloat9, row.FFloat10, row.FFloat11,
		row.FFloat12, row.FFloat13, row.FFloat14, row.FFloat15,
	}
}

func tableInts(row modelv2.TableRow) [4]int64 {
	return [4]int64{row.FInt0, row.FInt1, row.FInt2, row.FInt3}
}

func buildTableRecord(rows []modelv2.TableRow) arrow.RecordBatch {
	b := array.NewRecordBuilder(arrowMem, schemaTable)
	defer b.Release()
	fb := make([]*array.Float64Builder, 16)
	for i := range fb {
		fb[i] = b.Field(i).(*array.Float64Builder)
	}
	ib := make([]*array.Int64Builder, 4)
	for i := range ib {
		ib[i] = b.Field(16 + i).(*array.Int64Builder)
	}
	s0 := b.Field(20).(*array.StringBuilder)
	s1 := b.Field(21).(*array.StringBuilder)
	for _, row := range rows {
		floats := tableFloats(row)
		for i := range fb {
			fb[i].Append(floats[i])
		}
		ints := tableInts(row)
		for i := range ib {
			ib[i].Append(ints[i])
		}
		s0.Append(row.FStr0)
		s1.Append(row.FStr1)
	}
	return b.NewRecordBatch()
}

func buildNestedRecord(rows []modelv2.NestedRow) arrow.RecordBatch {
	b := array.NewRecordBuilder(arrowMem, schemaNested)
	defer b.Release()
	id := b.Field(0).(*array.StringBuilder)
	status := b.Field(1).(*array.Int32Builder)
	meta := b.Field(2).(*array.StructBuilder)
	region := meta.FieldBuilder(0).(*array.StringBuilder)
	version := meta.FieldBuilder(1).(*array.Int32Builder)
	items := b.Field(3).(*array.ListBuilder)
	item := items.ValueBuilder().(*array.StructBuilder)
	sku := item.FieldBuilder(0).(*array.StringBuilder)
	qty := item.FieldBuilder(1).(*array.Int32Builder)
	price := item.FieldBuilder(2).(*array.Int64Builder)
	for _, row := range rows {
		id.Append(row.ID)
		status.Append(row.Status)
		meta.Append(true)
		region.Append(row.Meta.Region)
		version.Append(row.Meta.Version)
		items.Append(true)
		for _, it := range row.Items {
			item.Append(true)
			sku.Append(it.SKU)
			qty.Append(it.Qty)
			price.Append(it.PriceMinor)
		}
	}
	return b.NewRecordBatch()
}

func buildSignalRecord(rows []modelv2.Signal) arrow.RecordBatch {
	b := array.NewRecordBuilder(arrowMem, schemaSignal)
	defer b.Release()
	seq := b.Field(0).(*array.Int64Builder)
	ts := b.Field(1).(*array.Int64Builder)
	price := b.Field(2).(*array.Int64Builder)
	qty := b.Field(3).(*array.Int32Builder)
	flags := b.Field(4).(*array.Int32Builder)
	symbol := b.Field(5).(*array.StringBuilder)
	venue := b.Field(6).(*array.StringBuilder)
	legs := b.Field(7).(*array.ListBuilder)
	leg := legs.ValueBuilder().(*array.StructBuilder)
	legID := leg.FieldBuilder(0).(*array.Int64Builder)
	legQty := leg.FieldBuilder(1).(*array.Int32Builder)
	legPad := leg.FieldBuilder(2).(*array.Int32Builder)
	for _, row := range rows {
		seq.Append(row.Seq)
		ts.Append(row.TS)
		price.Append(row.PriceMantissa)
		qty.Append(row.Qty)
		flags.Append(row.Flags)
		symbol.Append(row.Symbol)
		venue.Append(row.Venue)
		legs.Append(true)
		for _, lg := range row.Legs {
			leg.Append(true)
			legID.Append(lg.LegID)
			legQty.Append(lg.LegQty)
			legPad.Append(lg.LegPad)
		}
	}
	return b.NewRecordBatch()
}

func decodeRecords(name string, recs []arrow.RecordBatch) (any, error) {
	switch name {
	case "table", "table_project":
		var rows []modelv2.TableRow
		for _, rec := range recs {
			part, err := tableFromRecord(rec)
			if err != nil {
				return nil, err
			}
			rows = append(rows, part...)
		}
		if name == "table_project" {
			return modelv2.ProjectFFloat0(rows), nil
		}
		if len(rows) == 1 {
			return rows[0], nil
		}
		return rows, nil
	case "nested_table":
		var rows []modelv2.NestedRow
		for _, rec := range recs {
			part, err := nestedFromRecord(rec)
			if err != nil {
				return nil, err
			}
			rows = append(rows, part...)
		}
		if len(rows) == 1 {
			return rows[0], nil
		}
		return rows, nil
	case "signal":
		var rows []modelv2.Signal
		for _, rec := range recs {
			part, err := signalFromRecord(rec)
			if err != nil {
				return nil, err
			}
			rows = append(rows, part...)
		}
		if len(rows) == 1 {
			return rows[0], nil
		}
		return rows, nil
	default:
		return nil, fmt.Errorf("arrow: decode %s", name)
	}
}

func floatsFromRecords(recs []arrow.RecordBatch) []float64 {
	n := 0
	for _, rec := range recs {
		n += int(rec.NumRows())
	}
	out := make([]float64, 0, n)
	for _, rec := range recs {
		if rec.NumCols() < 1 {
			continue
		}
		col := rec.Column(0).(*array.Float64)
		out = append(out, col.Float64Values()...)
	}
	return out
}

func tableFromRecord(rec arrow.RecordBatch) ([]modelv2.TableRow, error) {
	if rec.NumCols() != 22 {
		return nil, fmt.Errorf("arrow: table columns %d", rec.NumCols())
	}
	n := int(rec.NumRows())
	floats := make([][]float64, 16)
	for i := range floats {
		floats[i] = rec.Column(i).(*array.Float64).Float64Values()
	}
	ints := make([][]int64, 4)
	for i := range ints {
		ints[i] = rec.Column(16 + i).(*array.Int64).Int64Values()
	}
	s0 := rec.Column(20).(*array.String)
	s1 := rec.Column(21).(*array.String)
	out := make([]modelv2.TableRow, n)
	for i := 0; i < n; i++ {
		out[i] = modelv2.TableRow{
			FFloat0: floats[0][i], FFloat1: floats[1][i], FFloat2: floats[2][i], FFloat3: floats[3][i],
			FFloat4: floats[4][i], FFloat5: floats[5][i], FFloat6: floats[6][i], FFloat7: floats[7][i],
			FFloat8: floats[8][i], FFloat9: floats[9][i], FFloat10: floats[10][i], FFloat11: floats[11][i],
			FFloat12: floats[12][i], FFloat13: floats[13][i], FFloat14: floats[14][i], FFloat15: floats[15][i],
			FInt0: ints[0][i], FInt1: ints[1][i], FInt2: ints[2][i], FInt3: ints[3][i],
			FStr0: s0.Value(i), FStr1: s1.Value(i),
		}
	}
	return out, nil
}

func logicalIndex(arr arrow.Array, physical int) int {
	return physical - arr.Data().Offset()
}

func nestedFromRecord(rec arrow.RecordBatch) ([]modelv2.NestedRow, error) {
	if rec.NumCols() != 4 {
		return nil, fmt.Errorf("arrow: nested columns %d", rec.NumCols())
	}
	n := int(rec.NumRows())
	id := rec.Column(0).(*array.String)
	status := rec.Column(1).(*array.Int32)
	meta := rec.Column(2).(*array.Struct)
	region := meta.Field(0).(*array.String)
	version := meta.Field(1).(*array.Int32)
	items := rec.Column(3).(*array.List)
	vals := items.ListValues().(*array.Struct)
	sku := vals.Field(0).(*array.String)
	qty := vals.Field(1).(*array.Int32)
	price := vals.Field(2).(*array.Int64)
	out := make([]modelv2.NestedRow, n)
	for i := 0; i < n; i++ {
		start, end := items.ValueOffsets(i)
		kids := make([]modelv2.NestedItem, 0, end-start)
		for j := start; j < end; j++ {
			k := logicalIndex(vals, int(j))
			kids = append(kids, modelv2.NestedItem{
				SKU: sku.Value(k), Qty: qty.Value(k), PriceMinor: price.Value(k),
			})
		}
		out[i] = modelv2.NestedRow{
			ID: id.Value(i), Status: status.Value(i),
			Meta:  modelv2.NestedMeta{Region: region.Value(i), Version: version.Value(i)},
			Items: kids,
		}
	}
	return out, nil
}

func signalFromRecord(rec arrow.RecordBatch) ([]modelv2.Signal, error) {
	if rec.NumCols() != 8 {
		return nil, fmt.Errorf("arrow: signal columns %d", rec.NumCols())
	}
	n := int(rec.NumRows())
	seq := rec.Column(0).(*array.Int64)
	ts := rec.Column(1).(*array.Int64)
	price := rec.Column(2).(*array.Int64)
	qty := rec.Column(3).(*array.Int32)
	flags := rec.Column(4).(*array.Int32)
	symbol := rec.Column(5).(*array.String)
	venue := rec.Column(6).(*array.String)
	legs := rec.Column(7).(*array.List)
	vals := legs.ListValues().(*array.Struct)
	legID := vals.Field(0).(*array.Int64)
	legQty := vals.Field(1).(*array.Int32)
	legPad := vals.Field(2).(*array.Int32)
	out := make([]modelv2.Signal, n)
	for i := 0; i < n; i++ {
		start, end := legs.ValueOffsets(i)
		group := make([]modelv2.SignalLeg, 0, end-start)
		for j := start; j < end; j++ {
			k := logicalIndex(vals, int(j))
			group = append(group, modelv2.SignalLeg{
				LegID: legID.Value(k), LegQty: legQty.Value(k), LegPad: legPad.Value(k),
			})
		}
		out[i] = modelv2.Signal{
			Seq: seq.Value(i), TS: ts.Value(i), PriceMantissa: price.Value(i),
			Qty: qty.Value(i), Flags: flags.Value(i),
			Symbol: symbol.Value(i), Venue: venue.Value(i), Legs: group,
		}
	}
	return out, nil
}
