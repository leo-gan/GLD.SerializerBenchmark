//! Arrow IPC stream and Parquet on the columnar type ids.
//!
//! Schema objects and writer properties are built in `prepare` (untimed).
//! Building the `RecordBatch` is inside `serialize_into` / `serialize_fixtures`.
//! Bytes mode writes an IPC stream, not an Arrow file. `table_project` reads
//! `f_float_0` only (`StreamReader` field 0, or a Parquet projection mask).
//!
//! parquet 60 `DEFAULT_COMPRESSION` is `UNCOMPRESSED`. The `parquet` row sets
//! Snappy page compression so it matches the suite codec. Encodings stay on
//! the builder default. `parquet-uncompressed` sets `Compression::UNCOMPRESSED`.

use crate::data::{
    is_columnar_id, Fixture, NestedItem, NestedMeta, NestedRow, Signal, SignalLeg, TableRow,
};
use anyhow::{anyhow, Context, Result};
use arrow::array::{
    Array, ArrayRef, Float64Array, Int32Array, Int64Array, ListArray, RecordBatch, StringArray,
    StructArray,
};
use arrow::buffer::{OffsetBuffer, ScalarBuffer};
use arrow::datatypes::{DataType, Field, Fields, Schema, SchemaRef};
use arrow::record_batch::RecordBatchReader;
use arrow::ipc::reader::StreamReader;
use arrow::ipc::writer::StreamWriter;
use parquet::arrow::arrow_reader::ParquetRecordBatchReaderBuilder;
use parquet::arrow::arrow_writer::ArrowWriter;
use parquet::arrow::ProjectionMask;
use parquet::basic::Compression;
use parquet::file::properties::WriterProperties;
use std::io::Cursor;
use std::sync::{Arc, OnceLock};

use super::{ver, BenchSerializer, NativeKind};

fn table_schema() -> SchemaRef {
    static S: OnceLock<SchemaRef> = OnceLock::new();
    S.get_or_init(|| {
        let mut fields = Vec::with_capacity(22);
        for i in 0..16 {
            fields.push(Field::new(
                format!("f_float_{i}"),
                DataType::Float64,
                false,
            ));
        }
        for i in 0..4 {
            fields.push(Field::new(format!("f_int_{i}"), DataType::Int64, false));
        }
        fields.push(Field::new("f_str_0", DataType::Utf8, false));
        fields.push(Field::new("f_str_1", DataType::Utf8, false));
        Arc::new(Schema::new(fields))
    })
    .clone()
}

fn nested_item_fields() -> Fields {
    Fields::from(vec![
        Field::new("sku", DataType::Utf8, false),
        Field::new("qty", DataType::Int32, false),
        Field::new("price_minor", DataType::Int64, false),
    ])
}

fn signal_leg_fields() -> Fields {
    Fields::from(vec![
        Field::new("leg_id", DataType::Int64, false),
        Field::new("leg_qty", DataType::Int32, false),
        Field::new("leg_pad", DataType::Int32, false),
    ])
}

fn nested_schema() -> SchemaRef {
    static S: OnceLock<SchemaRef> = OnceLock::new();
    S.get_or_init(|| {
        let meta = DataType::Struct(Fields::from(vec![
            Field::new("region", DataType::Utf8, false),
            Field::new("version", DataType::Int32, false),
        ]));
        let item = Arc::new(Field::new(
            "item",
            DataType::Struct(nested_item_fields()),
            false,
        ));
        Arc::new(Schema::new(vec![
            Field::new("id", DataType::Utf8, false),
            Field::new("status", DataType::Int32, false),
            Field::new("meta", meta, false),
            Field::new("items", DataType::List(item), false),
        ]))
    })
    .clone()
}

fn signal_schema() -> SchemaRef {
    static S: OnceLock<SchemaRef> = OnceLock::new();
    S.get_or_init(|| {
        let leg = Arc::new(Field::new(
            "item",
            DataType::Struct(signal_leg_fields()),
            false,
        ));
        Arc::new(Schema::new(vec![
            Field::new("seq", DataType::Int64, false),
            Field::new("ts", DataType::Int64, false),
            Field::new("price_mantissa", DataType::Int64, false),
            Field::new("qty", DataType::Int32, false),
            Field::new("flags", DataType::Int32, false),
            Field::new("symbol", DataType::Utf8, false),
            Field::new("venue", DataType::Utf8, false),
            Field::new("legs", DataType::List(leg), false),
        ]))
    })
    .clone()
}

fn schema_for(kind: &str) -> Result<SchemaRef> {
    Ok(match kind {
        "table" | "table_project" => table_schema(),
        "nested_table" => nested_schema(),
        "signal" => signal_schema(),
        other => return Err(anyhow!("columnar: no schema for {other}")),
    })
}

/// Snappy page compression. Built once, outside serialize.
fn snappy_props() -> &'static WriterProperties {
    static P: OnceLock<WriterProperties> = OnceLock::new();
    P.get_or_init(|| {
        WriterProperties::builder()
            .set_compression(Compression::SNAPPY)
            .build()
    })
}

/// Compression off. Encodings stay at the builder default. Built once.
fn uncompressed_props() -> &'static WriterProperties {
    static P: OnceLock<WriterProperties> = OnceLock::new();
    P.get_or_init(|| {
        WriterProperties::builder()
            .set_compression(Compression::UNCOMPRESSED)
            .build()
    })
}

fn take_f64(array: &dyn Array) -> Result<Vec<f64>> {
    let casted = arrow::compute::cast(array, &DataType::Float64).context("cast f64")?;
    let prim = casted
        .as_any()
        .downcast_ref::<Float64Array>()
        .context("f64 column")?;
    Ok(prim.values().to_vec())
}

fn take_i64(array: &dyn Array) -> Result<Vec<i64>> {
    let casted = arrow::compute::cast(array, &DataType::Int64).context("cast i64")?;
    let prim = casted
        .as_any()
        .downcast_ref::<Int64Array>()
        .context("i64 column")?;
    Ok(prim.values().to_vec())
}

fn take_i32(array: &dyn Array) -> Result<Vec<i32>> {
    let casted = arrow::compute::cast(array, &DataType::Int32).context("cast i32")?;
    let prim = casted
        .as_any()
        .downcast_ref::<Int32Array>()
        .context("i32 column")?;
    Ok(prim.values().to_vec())
}

fn take_utf8(array: &dyn Array) -> Result<Vec<String>> {
    let casted = arrow::compute::cast(array, &DataType::Utf8).context("cast utf8")?;
    let strings = casted
        .as_any()
        .downcast_ref::<StringArray>()
        .context("utf8 column")?;
    Ok((0..strings.len())
        .map(|i| strings.value(i).to_string())
        .collect())
}

fn col<'a>(batch: &'a RecordBatch, name: &str) -> Result<&'a dyn Array> {
    batch
        .column_by_name(name)
        .map(|c| c.as_ref())
        .with_context(|| format!("missing column {name}"))
}

fn struct_col<'a>(parent: &'a StructArray, name: &str) -> Result<&'a dyn Array> {
    parent
        .column_by_name(name)
        .map(|c| c.as_ref())
        .with_context(|| format!("missing struct field {name}"))
}

fn list_struct(array: &dyn Array) -> Result<(&ListArray, StructArray)> {
    let list = array
        .as_any()
        .downcast_ref::<ListArray>()
        .context("list column")?;
    let values = list
        .values()
        .as_any()
        .downcast_ref::<StructArray>()
        .context("list values are not a struct")?
        .clone();
    Ok((list, values))
}

fn table_batch(rows: &[&TableRow], schema: SchemaRef) -> Result<RecordBatch> {
    let mut cols: Vec<ArrayRef> = Vec::with_capacity(22);
    for i in 0..16 {
        let values: Vec<f64> = rows.iter().map(|r| r.floats()[i]).collect();
        cols.push(Arc::new(Float64Array::from(values)));
    }
    for i in 0..4 {
        let values: Vec<i64> = rows.iter().map(|r| r.ints()[i]).collect();
        cols.push(Arc::new(Int64Array::from(values)));
    }
    let s0: Vec<&str> = rows.iter().map(|r| r.f_str_0.as_str()).collect();
    let s1: Vec<&str> = rows.iter().map(|r| r.f_str_1.as_str()).collect();
    cols.push(Arc::new(StringArray::from(s0)));
    cols.push(Arc::new(StringArray::from(s1)));
    RecordBatch::try_new(schema, cols).context("table record batch")
}

fn struct_array(fields: Fields, cols: Vec<ArrayRef>) -> Result<StructArray> {
    StructArray::try_new(fields, cols, None).context("struct array")
}

fn list_array(item_ty: DataType, values: ArrayRef, offsets: Vec<i32>) -> Result<ArrayRef> {
    let field = Arc::new(Field::new("item", item_ty, false));
    let offsets = OffsetBuffer::new(ScalarBuffer::from(offsets));
    let list = ListArray::try_new(field, offsets, values, None).context("list array")?;
    Ok(Arc::new(list))
}

fn nested_batch(rows: &[&NestedRow], schema: SchemaRef) -> Result<RecordBatch> {
    let ids: Vec<&str> = rows.iter().map(|r| r.id.as_str()).collect();
    let status: Vec<i32> = rows.iter().map(|r| r.status).collect();
    let regions: Vec<&str> = rows.iter().map(|r| r.meta.region.as_str()).collect();
    let versions: Vec<i32> = rows.iter().map(|r| r.meta.version).collect();
    let meta = struct_array(
        Fields::from(vec![
            Field::new("region", DataType::Utf8, false),
            Field::new("version", DataType::Int32, false),
        ]),
        vec![
            Arc::new(StringArray::from(regions)),
            Arc::new(Int32Array::from(versions)),
        ],
    )?;
    let mut skus = Vec::new();
    let mut qtys = Vec::new();
    let mut prices = Vec::new();
    let mut offsets = vec![0i32];
    for row in rows {
        for item in &row.items {
            skus.push(item.sku.as_str());
            qtys.push(item.qty);
            prices.push(item.price_minor);
        }
        offsets.push(skus.len() as i32);
    }
    let item_fields = nested_item_fields();
    let items = struct_array(
        item_fields.clone(),
        vec![
            Arc::new(StringArray::from(skus)),
            Arc::new(Int32Array::from(qtys)),
            Arc::new(Int64Array::from(prices)),
        ],
    )?;
    let list = list_array(DataType::Struct(item_fields), Arc::new(items), offsets)?;
    RecordBatch::try_new(
        schema,
        vec![
            Arc::new(StringArray::from(ids)),
            Arc::new(Int32Array::from(status)),
            Arc::new(meta),
            list,
        ],
    )
    .context("nested record batch")
}

fn signal_batch(rows: &[&Signal], schema: SchemaRef) -> Result<RecordBatch> {
    let seq: Vec<i64> = rows.iter().map(|r| r.seq).collect();
    let ts: Vec<i64> = rows.iter().map(|r| r.ts).collect();
    let price: Vec<i64> = rows.iter().map(|r| r.price_mantissa).collect();
    let qty: Vec<i32> = rows.iter().map(|r| r.qty).collect();
    let flags: Vec<i32> = rows.iter().map(|r| r.flags).collect();
    let symbol: Vec<&str> = rows.iter().map(|r| r.symbol.as_str()).collect();
    let venue: Vec<&str> = rows.iter().map(|r| r.venue.as_str()).collect();
    let mut leg_id = Vec::new();
    let mut leg_qty = Vec::new();
    let mut leg_pad = Vec::new();
    let mut offsets = vec![0i32];
    for row in rows {
        for leg in &row.legs {
            leg_id.push(leg.leg_id);
            leg_qty.push(leg.leg_qty);
            leg_pad.push(leg.leg_pad);
        }
        offsets.push(leg_id.len() as i32);
    }
    let leg_fields = signal_leg_fields();
    let legs = struct_array(
        leg_fields.clone(),
        vec![
            Arc::new(Int64Array::from(leg_id)),
            Arc::new(Int32Array::from(leg_qty)),
            Arc::new(Int32Array::from(leg_pad)),
        ],
    )?;
    let list = list_array(DataType::Struct(leg_fields), Arc::new(legs), offsets)?;
    RecordBatch::try_new(
        schema,
        vec![
            Arc::new(Int64Array::from(seq)),
            Arc::new(Int64Array::from(ts)),
            Arc::new(Int64Array::from(price)),
            Arc::new(Int32Array::from(qty)),
            Arc::new(Int32Array::from(flags)),
            Arc::new(StringArray::from(symbol)),
            Arc::new(StringArray::from(venue)),
            list,
        ],
    )
    .context("signal record batch")
}

fn batch_for(kind: &str, fixtures: &[Fixture], schema: SchemaRef) -> Result<RecordBatch> {
    match kind {
        "table" | "table_project" => {
            let mut rows = Vec::with_capacity(fixtures.len());
            for fx in fixtures {
                match fx {
                    Fixture::Table(r) | Fixture::TableProject(r) => rows.push(r),
                    other => {
                        return Err(anyhow!("columnar: expected table row, got {}", other.name()))
                    }
                }
            }
            table_batch(&rows, schema)
        }
        "nested_table" => {
            let mut rows = Vec::with_capacity(fixtures.len());
            for fx in fixtures {
                match fx {
                    Fixture::NestedTable(r) => rows.push(r),
                    other => {
                        return Err(anyhow!(
                            "columnar: expected nested_table, got {}",
                            other.name()
                        ))
                    }
                }
            }
            nested_batch(&rows, schema)
        }
        "signal" => {
            let mut rows = Vec::with_capacity(fixtures.len());
            for fx in fixtures {
                match fx {
                    Fixture::Signal(r) => rows.push(r),
                    other => return Err(anyhow!("columnar: expected signal, got {}", other.name())),
                }
            }
            signal_batch(&rows, schema)
        }
        other => Err(anyhow!("columnar: unsupported kind {other}")),
    }
}

fn concat_batches(schema: SchemaRef, batches: Vec<RecordBatch>) -> Result<RecordBatch> {
    if batches.len() == 1 {
        return Ok(batches.into_iter().next().unwrap());
    }
    if batches.is_empty() {
        return Err(anyhow!("columnar: reader produced no batches"));
    }
    arrow::compute::concat_batches(&schema, &batches).context("concat batches")
}

/// IPC stream reader. `project` passes field index 0 (`f_float_0`).
fn read_ipc(data: &[u8], project: bool) -> Result<(SchemaRef, RecordBatch)> {
    let projection = if project { Some(vec![0usize]) } else { None };
    let reader = StreamReader::try_new(Cursor::new(data), projection)
        .context("arrow ipc StreamReader::try_new")?;
    let schema = reader.schema();
    let mut batches = Vec::new();
    for batch in reader {
        batches.push(batch.context("arrow ipc batch")?);
    }
    let batch = concat_batches(schema.clone(), batches)?;
    Ok((schema, batch))
}

/// Parquet reader. `project` selects `columns=["f_float_0"]` via `ProjectionMask`.
fn read_parquet(data: &[u8], project: bool) -> Result<(SchemaRef, RecordBatch)> {
    let bytes = bytes::Bytes::from(data.to_vec());
    let mut builder = ParquetRecordBatchReaderBuilder::try_new(bytes).context("parquet reader")?;
    if project {
        let mask = ProjectionMask::columns(builder.parquet_schema(), ["f_float_0"]);
        builder = builder.with_projection(mask);
    }
    let reader = builder.build().context("parquet build")?;
    let schema = reader.schema();
    let mut batches = Vec::new();
    for batch in reader {
        batches.push(batch.context("parquet batch")?);
    }
    let batch = concat_batches(schema.clone(), batches)?;
    Ok((schema, batch))
}

fn rows_from_table(batch: &RecordBatch) -> Result<Vec<TableRow>> {
    let mut floats = Vec::with_capacity(16);
    for i in 0..16 {
        floats.push(take_f64(col(batch, &format!("f_float_{i}"))?)?);
    }
    let mut ints = Vec::with_capacity(4);
    for i in 0..4 {
        ints.push(take_i64(col(batch, &format!("f_int_{i}"))?)?);
    }
    let s0 = take_utf8(col(batch, "f_str_0")?)?;
    let s1 = take_utf8(col(batch, "f_str_1")?)?;
    let n = s0.len();
    let mut rows = Vec::with_capacity(n);
    for i in 0..n {
        rows.push(TableRow {
            f_float_0: floats[0][i],
            f_float_1: floats[1][i],
            f_float_2: floats[2][i],
            f_float_3: floats[3][i],
            f_float_4: floats[4][i],
            f_float_5: floats[5][i],
            f_float_6: floats[6][i],
            f_float_7: floats[7][i],
            f_float_8: floats[8][i],
            f_float_9: floats[9][i],
            f_float_10: floats[10][i],
            f_float_11: floats[11][i],
            f_float_12: floats[12][i],
            f_float_13: floats[13][i],
            f_float_14: floats[14][i],
            f_float_15: floats[15][i],
            f_int_0: ints[0][i],
            f_int_1: ints[1][i],
            f_int_2: ints[2][i],
            f_int_3: ints[3][i],
            f_str_0: s0[i].clone(),
            f_str_1: s1[i].clone(),
        });
    }
    Ok(rows)
}

fn rows_from_nested(batch: &RecordBatch) -> Result<Vec<NestedRow>> {
    let ids = take_utf8(col(batch, "id")?)?;
    let status = take_i32(col(batch, "status")?)?;
    let meta = col(batch, "meta")?
        .as_any()
        .downcast_ref::<StructArray>()
        .context("meta struct")?
        .clone();
    let regions = take_utf8(struct_col(&meta, "region")?)?;
    let versions = take_i32(struct_col(&meta, "version")?)?;
    let (list, items) = list_struct(col(batch, "items")?)?;
    let skus = take_utf8(struct_col(&items, "sku")?)?;
    let qtys = take_i32(struct_col(&items, "qty")?)?;
    let prices = take_i64(struct_col(&items, "price_minor")?)?;
    let offs = list.offsets();
    let mut rows = Vec::with_capacity(ids.len());
    for i in 0..ids.len() {
        let start = offs[i] as usize;
        let end = offs[i + 1] as usize;
        let mut children = Vec::with_capacity(end - start);
        for j in start..end {
            children.push(NestedItem {
                sku: skus[j].clone(),
                qty: qtys[j],
                price_minor: prices[j],
            });
        }
        rows.push(NestedRow {
            id: ids[i].clone(),
            status: status[i],
            meta: NestedMeta {
                region: regions[i].clone(),
                version: versions[i],
            },
            items: children,
        });
    }
    Ok(rows)
}

fn rows_from_signal(batch: &RecordBatch) -> Result<Vec<Signal>> {
    let seq = take_i64(col(batch, "seq")?)?;
    let ts = take_i64(col(batch, "ts")?)?;
    let price = take_i64(col(batch, "price_mantissa")?)?;
    let qty = take_i32(col(batch, "qty")?)?;
    let flags = take_i32(col(batch, "flags")?)?;
    let symbol = take_utf8(col(batch, "symbol")?)?;
    let venue = take_utf8(col(batch, "venue")?)?;
    let (list, legs) = list_struct(col(batch, "legs")?)?;
    let leg_id = take_i64(struct_col(&legs, "leg_id")?)?;
    let leg_qty = take_i32(struct_col(&legs, "leg_qty")?)?;
    let leg_pad = take_i32(struct_col(&legs, "leg_pad")?)?;
    let offs = list.offsets();
    let mut rows = Vec::with_capacity(seq.len());
    for i in 0..seq.len() {
        let start = offs[i] as usize;
        let end = offs[i + 1] as usize;
        let mut group = Vec::with_capacity(end - start);
        for j in start..end {
            group.push(SignalLeg {
                leg_id: leg_id[j],
                leg_qty: leg_qty[j],
                leg_pad: leg_pad[j],
            });
        }
        rows.push(Signal {
            seq: seq[i],
            ts: ts[i],
            price_mantissa: price[i],
            qty: qty[i],
            flags: flags[i],
            symbol: symbol[i].clone(),
            venue: venue[i].clone(),
            legs: group,
        });
    }
    Ok(rows)
}

fn materialize(kind: &str, batch: &RecordBatch) -> Result<Fixture> {
    if kind == "table_project" {
        let values = if batch.num_columns() == 1 {
            take_f64(batch.column(0).as_ref())?
        } else {
            take_f64(col(batch, "f_float_0")?)?
        };
        return Ok(Fixture::Projected(values));
    }
    let rows = match kind {
        "table" => rows_from_table(batch)?
            .into_iter()
            .map(Fixture::Table)
            .collect::<Vec<_>>(),
        "nested_table" => rows_from_nested(batch)?
            .into_iter()
            .map(Fixture::NestedTable)
            .collect::<Vec<_>>(),
        "signal" => rows_from_signal(batch)?
            .into_iter()
            .map(Fixture::Signal)
            .collect::<Vec<_>>(),
        other => return Err(anyhow!("columnar: cannot materialize {other}")),
    };
    if rows.len() == 1 {
        Ok(rows.into_iter().next().unwrap())
    } else {
        Ok(Fixture::Rows(rows))
    }
}

fn write_ipc(batch: &RecordBatch, out: &mut Vec<u8>) -> Result<()> {
    let mut writer = StreamWriter::try_new(&mut *out, batch.schema().as_ref())
        .context("arrow ipc StreamWriter")?;
    writer.write(batch).context("arrow ipc write")?;
    writer.finish().context("arrow ipc finish")?;
    Ok(())
}

fn write_parquet(batch: &RecordBatch, props: &WriterProperties, out: &mut Vec<u8>) -> Result<()> {
    let mut writer = ArrowWriter::try_new(&mut *out, batch.schema(), Some(props.clone()))
        .context("parquet ArrowWriter")?;
    writer.write(batch).context("parquet write")?;
    writer.close().context("parquet close")?;
    Ok(())
}

pub struct ArrowIpc {
    kind: &'static str,
    schema: Option<SchemaRef>,
}

impl Default for ArrowIpc {
    fn default() -> Self {
        Self {
            kind: "table",
            schema: None,
        }
    }
}

impl ArrowIpc {
    fn write_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        let schema = self
            .schema
            .clone()
            .context("arrow-ipc: prepare not called")?;
        let batch = batch_for(self.kind, fixtures, schema)?;
        write_ipc(&batch, out)
    }
}

impl BenchSerializer for ArrowIpc {
    fn name(&self) -> &'static str {
        "arrow-ipc"
    }
    fn version(&self) -> &'static str {
        ver("arrow")
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Table
    }
    fn supports(&self, test_data_name: &str) -> bool {
        is_columnar_id(test_data_name)
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.kind = fixture.name();
        self.schema = Some(schema_for(self.kind)?);
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        match fixture {
            Fixture::Rows(rows) => self.write_fixtures(rows, out),
            one => self.write_fixtures(std::slice::from_ref(one), out),
        }
    }
    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        self.write_fixtures(fixtures, out)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let project = self.kind == "table_project";
        let (schema, batch) = read_ipc(data, project)?;
        if project {
            let names: Vec<_> = schema.fields().iter().map(|f| f.name().as_str()).collect();
            if names != ["f_float_0"] {
                return Err(anyhow!(
                    "arrow-ipc projection schema is {names:?}, expected [f_float_0]"
                ));
            }
        }
        materialize(self.kind, &batch)
    }
}

pub struct ParquetSer {
    uncompressed: bool,
    kind: &'static str,
    schema: Option<SchemaRef>,
    props: Option<&'static WriterProperties>,
}

impl Default for ParquetSer {
    fn default() -> Self {
        Self {
            uncompressed: false,
            kind: "table",
            schema: None,
            props: None,
        }
    }
}

impl ParquetSer {
    pub fn uncompressed() -> Self {
        Self {
            uncompressed: true,
            ..Self::default()
        }
    }

    fn write_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        let schema = self.schema.clone().context("parquet: prepare not called")?;
        let props = self.props.context("parquet: prepare not called")?;
        let batch = batch_for(self.kind, fixtures, schema)?;
        write_parquet(&batch, props, out)
    }
}

impl BenchSerializer for ParquetSer {
    fn name(&self) -> &'static str {
        if self.uncompressed {
            "parquet-uncompressed"
        } else {
            "parquet"
        }
    }
    fn version(&self) -> &'static str {
        ver("parquet")
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Table
    }
    fn supports(&self, test_data_name: &str) -> bool {
        is_columnar_id(test_data_name)
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.kind = fixture.name();
        self.schema = Some(schema_for(self.kind)?);
        // Touch the OnceLock here so property construction stays untimed.
        self.props = Some(if self.uncompressed {
            uncompressed_props()
        } else {
            snappy_props()
        });
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        match fixture {
            Fixture::Rows(rows) => self.write_fixtures(rows, out),
            one => self.write_fixtures(std::slice::from_ref(one), out),
        }
    }
    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        self.write_fixtures(fixtures, out)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let project = self.kind == "table_project";
        let (schema, batch) = read_parquet(data, project)?;
        if project {
            let names: Vec<_> = schema.fields().iter().map(|f| f.name().as_str()).collect();
            if names != ["f_float_0"] {
                return Err(anyhow!(
                    "parquet projection schema is {names:?}, expected [f_float_0]"
                ));
            }
        }
        materialize(self.kind, &batch)
    }
}

/// Column codec of the first chunk. Used to prove Snappy vs uncompressed.
pub(crate) fn parquet_column_compression(data: &[u8]) -> Result<Compression> {
    let bytes = bytes::Bytes::from(data.to_vec());
    let builder = ParquetRecordBatchReaderBuilder::try_new(bytes).context("parquet footer")?;
    let meta = builder.metadata();
    let groups = meta.row_groups();
    let col = groups
        .first()
        .and_then(|g| g.columns().first())
        .context("parquet metadata has no column")?;
    Ok(col.compression())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{make_one, check_cell_fidelity, TypeConfig};
    use std::hint::black_box;
    use std::time::Instant;

    fn fixtures(type_id: &str, n: i32) -> Vec<Fixture> {
        let cfg = TypeConfig::default();
        (0..n)
            .map(|i| make_one(type_id, 11, i, &cfg).unwrap())
            .collect()
    }

    #[test]
    fn parquet_snappy_differs_from_uncompressed_at_n100() {
        let rows = fixtures("table", 100);
        let mut snappy = ParquetSer::default();
        let mut raw = ParquetSer::uncompressed();
        snappy.prepare_many(&rows).unwrap();
        raw.prepare_many(&rows).unwrap();
        let mut a = Vec::new();
        let mut b = Vec::new();
        snappy.serialize_fixtures(&rows, &mut a).unwrap();
        raw.serialize_fixtures(&rows, &mut b).unwrap();
        assert_ne!(a, b, "snappy and uncompressed payloads matched");
        assert_eq!(parquet_column_compression(&a).unwrap(), Compression::SNAPPY);
        assert_eq!(
            parquet_column_compression(&b).unwrap(),
            Compression::UNCOMPRESSED
        );
    }

    #[test]
    fn projection_schema_is_f_float_0_only() {
        let rows = fixtures("table", 3);
        let projected: Vec<_> = rows
            .iter()
            .map(|fx| match fx {
                Fixture::Table(r) => Fixture::TableProject(r.clone()),
                other => panic!("{}", other.name()),
            })
            .collect();
        let mut arrow = ArrowIpc::default();
        let mut pq = ParquetSer::default();
        arrow.prepare_many(&rows).unwrap();
        pq.prepare_many(&rows).unwrap();
        let mut ipc = Vec::new();
        let mut bytes = Vec::new();
        arrow.serialize_fixtures(&rows, &mut ipc).unwrap();
        pq.serialize_fixtures(&rows, &mut bytes).unwrap();

        let mut arrow_p = ArrowIpc::default();
        let mut pq_p = ParquetSer::default();
        arrow_p.prepare_many(&projected).unwrap();
        pq_p.prepare_many(&projected).unwrap();
        let (schema, batch) = read_ipc(&ipc, true).unwrap();
        assert_eq!(
            schema.fields().iter().map(|f| f.name().as_str()).collect::<Vec<_>>(),
            vec!["f_float_0"]
        );
        assert_eq!(batch.num_columns(), 1);
        let (schema, batch) = read_parquet(&bytes, true).unwrap();
        assert_eq!(
            schema.fields().iter().map(|f| f.name().as_str()).collect::<Vec<_>>(),
            vec!["f_float_0"]
        );
        assert_eq!(batch.num_columns(), 1);
        let got = arrow_p.deserialize_bytes(&ipc).unwrap();
        check_cell_fidelity("table_project", &projected, &[got]).unwrap();
        let got = pq_p.deserialize_bytes(&bytes).unwrap();
        check_cell_fidelity("table_project", &projected, &[got]).unwrap();
    }

    fn median_deser(ser: &mut dyn BenchSerializer, bytes: &[u8], reps: usize) -> u128 {
        let mut samples = Vec::with_capacity(reps);
        for _ in 0..reps {
            let t = Instant::now();
            let fx = ser.deserialize_bytes(black_box(bytes)).unwrap();
            let ns = t.elapsed().as_nanos();
            black_box(&fx);
            samples.push(ns);
        }
        samples.sort_unstable();
        samples[samples.len() / 2]
    }

    #[test]
    fn n10000_projection_deser_is_cheaper_than_full_row() {
        let rows = fixtures("table", 10_000);
        let projected: Vec<_> = rows
            .iter()
            .map(|fx| match fx {
                Fixture::Table(r) => Fixture::TableProject(r.clone()),
                _ => unreachable!(),
            })
            .collect();
        let mut arrow = ArrowIpc::default();
        let mut pq = ParquetSer::default();
        arrow.prepare_many(&rows).unwrap();
        pq.prepare_many(&rows).unwrap();
        let mut ipc = Vec::new();
        let mut pq_bytes = Vec::new();
        arrow.serialize_fixtures(&rows, &mut ipc).unwrap();
        pq.serialize_fixtures(&rows, &mut pq_bytes).unwrap();

        let mut arrow_full = ArrowIpc::default();
        let mut arrow_proj = ArrowIpc::default();
        let mut pq_full = ParquetSer::default();
        let mut pq_proj = ParquetSer::default();
        arrow_full.prepare_many(&rows).unwrap();
        arrow_proj.prepare_many(&projected).unwrap();
        pq_full.prepare_many(&rows).unwrap();
        pq_proj.prepare_many(&projected).unwrap();

        let reps = 3;
        let arrow_full_ns = median_deser(&mut arrow_full, &ipc, reps);
        let arrow_proj_ns = median_deser(&mut arrow_proj, &ipc, reps);
        let pq_full_ns = median_deser(&mut pq_full, &pq_bytes, reps);
        let pq_proj_ns = median_deser(&mut pq_proj, &pq_bytes, reps);
        eprintln!(
            "N10000 deser median ns arrow-ipc full={arrow_full_ns} project={arrow_proj_ns} parquet full={pq_full_ns} project={pq_proj_ns} api=StreamReader::try_new(_, Some(vec![0])) / ProjectionMask::columns(_, [\"f_float_0\"])"
        );
        let got = arrow_proj.deserialize_bytes(&ipc).unwrap();
        check_cell_fidelity("table_project", &projected, &[got]).unwrap();
        let got = pq_proj.deserialize_bytes(&pq_bytes).unwrap();
        check_cell_fidelity("table_project", &projected, &[got]).unwrap();
        assert!(
            pq_proj_ns * 10 < pq_full_ns * 9,
            "parquet projection {pq_proj_ns} ns is not cheaper than full {pq_full_ns} ns"
        );
        assert!(
            arrow_proj_ns * 10 < arrow_full_ns * 9,
            "arrow-ipc projection {arrow_proj_ns} ns is not cheaper than full {arrow_full_ns} ns; StreamReader field projection is still materializing every column"
        );
    }
}
