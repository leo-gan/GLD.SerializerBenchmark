//! gld-kiln adapter for the five suite structs and the tensor set.
//!
//! `prepare_many` builds the positional schema and the owned [`kiln::Value`]
//! once. N=1 is the struct alone. N>1 is one `list` of that struct. Timed
//! encode appends with `encode_into` into the harness buffer.
//! `tensor_view` decode borrows the f32 payload; it does not copy the matrix.

use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, InferenceRequest, Message,
    Prompt, Shard, Strings, Telemetry, TensorMatrix,
};
use crate::serializers::{BenchSerializer, NativeKind, StreamMode};
use anyhow::{bail, Context, Result};
use kiln::{decode, encode_into, Reader, Schema, Value, DEFAULT_CAP};
use std::io::Read;

const SUITE: &[&str] = &["message", "document", "telemetry", "strings", "event"];
const TENSOR: &[&str] = &["tensor", "tensor_view", "prompt", "shard", "request"];

fn prompt_schema() -> Schema {
    Schema::struct_fields([
        ("batch", Schema::I32),
        ("seq", Schema::I32),
        ("input_ids", Schema::list(Schema::I64)),
        ("attention_mask", Schema::list(Schema::I64)),
        ("position_ids", Schema::list(Schema::I64)),
    ])
}

fn schema_for(kind: &str) -> Result<Schema> {
    Ok(match kind {
        "message" => Schema::struct_fields([
            ("f_bool", Schema::Bool),
            ("f_int32", Schema::I32),
            ("f_int64", Schema::I64),
            ("f_float64", Schema::F64),
            ("f_string", Schema::Str),
            ("f_bool_2", Schema::Bool),
            ("f_int32_2", Schema::I32),
            ("f_string_2", Schema::Str),
        ]),
        "document" => Schema::struct_fields([
            ("id", Schema::Str),
            ("status", Schema::I32),
            (
                "meta",
                Schema::struct_fields([("region", Schema::Str), ("version", Schema::I32)]),
            ),
            (
                "items",
                Schema::list(Schema::struct_fields([
                    ("sku", Schema::Str),
                    ("qty", Schema::I32),
                    ("price_minor", Schema::I64),
                ])),
            ),
        ]),
        "telemetry" => Schema::struct_fields([
            ("source", Schema::Str),
            ("ts", Schema::I64),
            ("tags", Schema::list(Schema::Str)),
            ("values", Schema::list(Schema::F64)),
        ]),
        "strings" => Schema::struct_fields([("items", Schema::list(Schema::Str))]),
        "event" => Schema::struct_fields([
            ("event_id", Schema::Str),
            ("event_type", Schema::Str),
            ("occurred_at", Schema::I64),
            ("producer", Schema::Str),
            (
                "attrs",
                Schema::list(Schema::struct_fields([
                    ("key", Schema::Str),
                    ("value", Schema::Str),
                ])),
            ),
        ]),
        "tensor" | "tensor_view" => Schema::struct_fields([
            ("rows", Schema::I32),
            ("cols", Schema::I32),
            ("values", Schema::list(Schema::F32)),
        ]),
        "prompt" => prompt_schema(),
        "shard" => Schema::struct_fields([
            ("vocab", Schema::I32),
            ("hidden", Schema::I32),
            ("ffn", Schema::I32),
            ("tok_emb", Schema::list(Schema::F32)),
            ("attn", Schema::list(Schema::F32)),
            ("ffn_weight", Schema::list(Schema::F32)),
            ("norm", Schema::list(Schema::F32)),
        ]),
        "request" => Schema::struct_fields([
            ("request_id", Schema::I64),
            ("model", Schema::Str),
            ("temperature", Schema::F32),
            ("inputs", prompt_schema()),
        ]),
        other => bail!("gld-kiln: unsupported {other}"),
    })
}

fn f32_list(values: &crate::data::F32Payload) -> Value<'static> {
    let mut items = Vec::with_capacity(values.len());
    for i in 0..values.len() {
        items.push(Value::F32(values.bit(i)));
    }
    Value::List(items)
}

fn i64_list(values: &[i64]) -> Value<'static> {
    Value::List(values.iter().copied().map(Value::I64).collect())
}

fn prompt_value(prompt: &Prompt) -> Value<'static> {
    Value::Struct(vec![
        Value::I32(prompt.batch),
        Value::I32(prompt.seq),
        i64_list(&prompt.input_ids),
        i64_list(&prompt.attention_mask),
        i64_list(&prompt.position_ids),
    ])
}

fn to_value(fx: &Fixture) -> Result<Value<'static>> {
    Ok(match fx {
        Fixture::Message(m) => Value::Struct(vec![
            Value::Bool(m.f_bool),
            Value::I32(m.f_int32),
            Value::I64(m.f_int64),
            Value::from_f64(m.f_float64),
            Value::str(m.f_string.clone()),
            Value::Bool(m.f_bool_2),
            Value::I32(m.f_int32_2),
            Value::str(m.f_string_2.clone()),
        ]),
        Fixture::Document(d) => Value::Struct(vec![
            Value::str(d.id.clone()),
            Value::I32(d.status),
            Value::Struct(vec![
                Value::str(d.meta.region.clone()),
                Value::I32(d.meta.version),
            ]),
            Value::List(
                d.items
                    .iter()
                    .map(|item| {
                        Value::Struct(vec![
                            Value::str(item.sku.clone()),
                            Value::I32(item.qty),
                            Value::I64(item.price_minor),
                        ])
                    })
                    .collect(),
            ),
        ]),
        Fixture::Telemetry(t) => Value::Struct(vec![
            Value::str(t.source.clone()),
            Value::I64(t.ts),
            Value::List(t.tags.iter().map(|s| Value::str(s.clone())).collect()),
            Value::List(t.values.iter().copied().map(Value::from_f64).collect()),
        ]),
        Fixture::Strings(s) => Value::Struct(vec![Value::List(
            s.items
                .iter()
                .map(|item| Value::str(item.clone()))
                .collect(),
        )]),
        Fixture::Event(e) => Value::Struct(vec![
            Value::str(e.event_id.clone()),
            Value::str(e.event_type.clone()),
            Value::I64(e.occurred_at),
            Value::str(e.producer.clone()),
            Value::List(
                e.attrs
                    .iter()
                    .map(|attr| {
                        Value::Struct(vec![
                            Value::str(attr.key.clone()),
                            Value::str(attr.value.clone()),
                        ])
                    })
                    .collect(),
            ),
        ]),
        Fixture::Tensor(matrix) | Fixture::TensorView(matrix) => Value::Struct(vec![
            Value::I32(matrix.rows),
            Value::I32(matrix.cols),
            f32_list(&matrix.values),
        ]),
        Fixture::Prompt(prompt) => prompt_value(prompt),
        Fixture::Shard(shard) => Value::Struct(vec![
            Value::I32(shard.vocab),
            Value::I32(shard.hidden),
            Value::I32(shard.ffn),
            f32_list_owned(&shard.tok_emb),
            f32_list_owned(&shard.attn),
            f32_list_owned(&shard.ffn_weight),
            f32_list_owned(&shard.norm),
        ]),
        Fixture::Request(request) => Value::Struct(vec![
            Value::I64(request.request_id),
            Value::str(request.model.clone()),
            Value::from_f32(request.temperature),
            prompt_value(&request.inputs),
        ]),
        other => bail!("gld-kiln: unsupported fixture {}", other.name()),
    })
}

fn f32_list_owned(values: &[f32]) -> Value<'static> {
    Value::List(values.iter().copied().map(Value::from_f32).collect())
}

fn as_struct<'a, 'b>(value: &'a Value<'b>) -> Result<&'a [Value<'b>]> {
    match value {
        Value::Struct(fields) => Ok(fields),
        _ => bail!("gld-kiln: expected struct"),
    }
}

fn as_list<'a, 'b>(value: &'a Value<'b>) -> Result<&'a [Value<'b>]> {
    match value {
        Value::List(items) => Ok(items),
        _ => bail!("gld-kiln: expected list"),
    }
}

fn field<'a, 'b>(fields: &'a [Value<'b>], index: usize) -> Result<&'a Value<'b>> {
    fields.get(index).context("gld-kiln: missing field")
}

fn exact(fields: &[Value<'_>], n: usize) -> Result<()> {
    if fields.len() != n {
        bail!("gld-kiln: field count {} != {n}", fields.len());
    }
    Ok(())
}

fn as_bool(value: &Value<'_>) -> Result<bool> {
    match value {
        Value::Bool(v) => Ok(*v),
        _ => bail!("gld-kiln: expected bool"),
    }
}

fn as_i32(value: &Value<'_>) -> Result<i32> {
    match value {
        Value::I32(v) => Ok(*v),
        _ => bail!("gld-kiln: expected i32"),
    }
}

fn as_i64(value: &Value<'_>) -> Result<i64> {
    match value {
        Value::I64(v) => Ok(*v),
        _ => bail!("gld-kiln: expected i64"),
    }
}

fn as_f32(value: &Value<'_>) -> Result<f32> {
    match value {
        Value::F32(bits) => Ok(f32::from_bits(*bits)),
        _ => bail!("gld-kiln: expected f32"),
    }
}

fn as_f64(value: &Value<'_>) -> Result<f64> {
    match value {
        Value::F64(bits) => Ok(f64::from_bits(*bits)),
        _ => bail!("gld-kiln: expected f64"),
    }
}

fn as_string(value: &Value<'_>) -> Result<String> {
    match value {
        Value::Str(s) => Ok(s.as_ref().to_owned()),
        _ => bail!("gld-kiln: expected str"),
    }
}

fn message_from(value: &Value<'_>) -> Result<Message> {
    let fields = as_struct(value)?;
    exact(fields, 8)?;
    Ok(Message {
        f_bool: as_bool(field(fields, 0)?)?,
        f_int32: as_i32(field(fields, 1)?)?,
        f_int64: as_i64(field(fields, 2)?)?,
        f_float64: as_f64(field(fields, 3)?)?,
        f_string: as_string(field(fields, 4)?)?,
        f_bool_2: as_bool(field(fields, 5)?)?,
        f_int32_2: as_i32(field(fields, 6)?)?,
        f_string_2: as_string(field(fields, 7)?)?,
    })
}

fn document_from(value: &Value<'_>) -> Result<Document> {
    let fields = as_struct(value)?;
    exact(fields, 4)?;
    let meta = as_struct(field(fields, 2)?)?;
    exact(meta, 2)?;
    let mut items = Vec::new();
    for item in as_list(field(fields, 3)?)? {
        let item_fields = as_struct(item)?;
        exact(item_fields, 3)?;
        items.push(DocumentItem {
            sku: as_string(field(item_fields, 0)?)?,
            qty: as_i32(field(item_fields, 1)?)?,
            price_minor: as_i64(field(item_fields, 2)?)?,
        });
    }
    Ok(Document {
        id: as_string(field(fields, 0)?)?,
        status: as_i32(field(fields, 1)?)?,
        meta: DocumentMeta {
            region: as_string(field(meta, 0)?)?,
            version: as_i32(field(meta, 1)?)?,
        },
        items,
    })
}

fn telemetry_from(value: &Value<'_>) -> Result<Telemetry> {
    let fields = as_struct(value)?;
    exact(fields, 4)?;
    Ok(Telemetry {
        source: as_string(field(fields, 0)?)?,
        ts: as_i64(field(fields, 1)?)?,
        tags: as_list(field(fields, 2)?)?
            .iter()
            .map(as_string)
            .collect::<Result<Vec<_>>>()?,
        values: as_list(field(fields, 3)?)?
            .iter()
            .map(as_f64)
            .collect::<Result<Vec<_>>>()?,
    })
}

fn strings_from(value: &Value<'_>) -> Result<Strings> {
    let fields = as_struct(value)?;
    exact(fields, 1)?;
    Ok(Strings {
        items: as_list(field(fields, 0)?)?
            .iter()
            .map(as_string)
            .collect::<Result<Vec<_>>>()?,
    })
}

fn event_from(value: &Value<'_>) -> Result<Event> {
    let fields = as_struct(value)?;
    exact(fields, 5)?;
    let mut attrs = Vec::new();
    for attr in as_list(field(fields, 4)?)? {
        let attr_fields = as_struct(attr)?;
        exact(attr_fields, 2)?;
        attrs.push(EventAttr {
            key: as_string(field(attr_fields, 0)?)?,
            value: as_string(field(attr_fields, 1)?)?,
        });
    }
    Ok(Event {
        event_id: as_string(field(fields, 0)?)?,
        event_type: as_string(field(fields, 1)?)?,
        occurred_at: as_i64(field(fields, 2)?)?,
        producer: as_string(field(fields, 3)?)?,
        attrs,
    })
}

fn f32_list_from(value: &Value<'_>) -> Result<Vec<f32>> {
    let mut out = Vec::with_capacity(as_list(value)?.len());
    for item in as_list(value)? {
        out.push(as_f32(item)?);
    }
    Ok(out)
}

fn i64_list_from(value: &Value<'_>) -> Result<Vec<i64>> {
    as_list(value)?.iter().map(as_i64).collect()
}

fn tensor_from(value: &Value<'_>) -> Result<TensorMatrix> {
    let fields = as_struct(value)?;
    exact(fields, 3)?;
    Ok(TensorMatrix::owned(
        as_i32(field(fields, 0)?)?,
        as_i32(field(fields, 1)?)?,
        f32_list_from(field(fields, 2)?)?,
    ))
}

fn prompt_from(value: &Value<'_>) -> Result<Prompt> {
    let fields = as_struct(value)?;
    exact(fields, 5)?;
    Ok(Prompt {
        batch: as_i32(field(fields, 0)?)?,
        seq: as_i32(field(fields, 1)?)?,
        input_ids: i64_list_from(field(fields, 2)?)?,
        attention_mask: i64_list_from(field(fields, 3)?)?,
        position_ids: i64_list_from(field(fields, 4)?)?,
    })
}

fn shard_from(value: &Value<'_>) -> Result<Shard> {
    let fields = as_struct(value)?;
    exact(fields, 7)?;
    Ok(Shard {
        vocab: as_i32(field(fields, 0)?)?,
        hidden: as_i32(field(fields, 1)?)?,
        ffn: as_i32(field(fields, 2)?)?,
        tok_emb: f32_list_from(field(fields, 3)?)?,
        attn: f32_list_from(field(fields, 4)?)?,
        ffn_weight: f32_list_from(field(fields, 5)?)?,
        norm: f32_list_from(field(fields, 6)?)?,
    })
}

fn request_from(value: &Value<'_>) -> Result<InferenceRequest> {
    let fields = as_struct(value)?;
    exact(fields, 4)?;
    Ok(InferenceRequest {
        request_id: as_i64(field(fields, 0)?)?,
        model: as_string(field(fields, 1)?)?,
        temperature: as_f32(field(fields, 2)?)?,
        inputs: prompt_from(field(fields, 3)?)?,
    })
}

/// Rows, cols, count, then the f32 body. The body is a pointer into `data`.
fn tensor_view_fixture(data: &[u8]) -> Result<Fixture> {
    let mut reader = Reader::new(data);
    let rows = reader
        .i32()
        .map_err(|e| anyhow::anyhow!("gld-kiln tensor_view: {e}"))?;
    let cols = reader
        .i32()
        .map_err(|e| anyhow::anyhow!("gld-kiln tensor_view: {e}"))?;
    let n = reader
        .list_count(4)
        .map_err(|e| anyhow::anyhow!("gld-kiln tensor_view: {e}"))? as usize;
    let nbytes = n.checked_mul(4).context("gld-kiln tensor_view length")?;
    let total = nbytes
        .checked_add(12)
        .context("gld-kiln tensor_view length")?;
    if data.len() != total {
        bail!("gld-kiln tensor_view length");
    }
    let payload = reader
        .raw(nbytes)
        .map_err(|e| anyhow::anyhow!("gld-kiln tensor_view: {e}"))?;
    Ok(Fixture::TensorView(TensorMatrix::borrowed(
        rows, cols, payload,
    )))
}

fn fixture_from(kind: &str, value: &Value<'_>) -> Result<Fixture> {
    Ok(match kind {
        "message" => Fixture::Message(message_from(value)?),
        "document" => Fixture::Document(document_from(value)?),
        "telemetry" => Fixture::Telemetry(telemetry_from(value)?),
        "strings" => Fixture::Strings(strings_from(value)?),
        "event" => Fixture::Event(event_from(value)?),
        "tensor" => Fixture::Tensor(tensor_from(value)?),
        "prompt" => Fixture::Prompt(prompt_from(value)?),
        "shard" => Fixture::Shard(shard_from(value)?),
        "request" => Fixture::Request(request_from(value)?),
        other => bail!("gld-kiln: unsupported {other}"),
    })
}

pub struct KilnSer {
    schema: Option<Schema>,
    value: Option<Value<'static>>,
    kind: &'static str,
    batch: bool,
}

impl Default for KilnSer {
    fn default() -> Self {
        Self {
            schema: None,
            value: None,
            kind: "message",
            batch: false,
        }
    }
}

impl KilnSer {
    fn write_prepared(&self, out: &mut Vec<u8>) -> Result<()> {
        let schema = self
            .schema
            .as_ref()
            .context("gld-kiln prepare was not called")?;
        let value = self
            .value
            .as_ref()
            .context("gld-kiln prepare was not called")?;
        encode_into(schema, value, out, DEFAULT_CAP)
            .map_err(|e| anyhow::anyhow!("gld-kiln encode: {e}"))?;
        Ok(())
    }
}

impl BenchSerializer for KilnSer {
    fn name(&self) -> &'static str {
        "gld-kiln"
    }

    fn version(&self) -> &'static str {
        super::ver("gld-kiln")
    }

    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }

    fn native_kind(&self) -> NativeKind {
        NativeKind::Message
    }

    fn supports(&self, test_data_name: &str) -> bool {
        SUITE.contains(&test_data_name) || TENSOR.contains(&test_data_name)
    }

    /// N>1 is one list payload, not the harness length-prefix frame.
    fn one_cell_payload(&self) -> bool {
        self.batch
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.prepare_many(std::slice::from_ref(fixture))
    }

    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        if fixtures.is_empty() {
            bail!("gld-kiln: empty cell");
        }
        let kind = fixtures[0].name();
        if !self.supports(kind) {
            bail!("gld-kiln: unsupported {kind}");
        }
        if kind == "tensor_view" && fixtures.len() != 1 {
            bail!("gld-kiln: tensor_view is one borrowed matrix");
        }
        if fixtures.iter().any(|fx| fx.name() != kind) {
            bail!("gld-kiln: mixed cell");
        }
        let batch = fixtures.len() > 1;
        let base = schema_for(kind)?;
        let schema = if batch { Schema::list(base) } else { base };
        let value = if batch {
            Value::List(fixtures.iter().map(to_value).collect::<Result<Vec<_>>>()?)
        } else {
            to_value(&fixtures[0])?
        };
        self.kind = kind;
        self.batch = batch;
        self.schema = Some(schema);
        self.value = Some(value);
        Ok(())
    }

    fn serialize_into(&mut self, _fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        if self.batch {
            bail!("gld-kiln: batch cell is one list; call serialize_fixtures");
        }
        self.write_prepared(out)
    }

    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        if self.batch {
            if fixtures.len() <= 1 {
                bail!("gld-kiln: prepared a list but cell has {}", fixtures.len());
            }
            return self.write_prepared(out);
        }
        if fixtures.len() != 1 {
            bail!("gld-kiln: N>1 requires prepare_many so the schema is a list");
        }
        self.serialize_into(&fixtures[0], out)
    }

    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        if self.kind == "tensor_view" {
            bail!("gld-kiln: tensor_view borrows the bytes buffer");
        }
        let mut data = Vec::new();
        r.read_to_end(&mut data)?;
        self.deserialize_bytes(&data)
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let schema = self
            .schema
            .as_ref()
            .context("gld-kiln prepare was not called")?;
        if self.kind == "tensor_view" {
            if self.batch {
                bail!("gld-kiln: tensor_view batch is not a borrowed matrix");
            }
            return tensor_view_fixture(data);
        }
        let value = decode(schema, data).map_err(|e| anyhow::anyhow!("gld-kiln decode: {e}"))?;
        if self.batch {
            let items = as_list(&value)?;
            let mut rows = Vec::with_capacity(items.len());
            for item in items {
                rows.push(fixture_from(self.kind, item)?);
            }
            return Ok(Fixture::Rows(rows));
        }
        fixture_from(self.kind, &value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{check_cell_fidelity, make_one, TypeConfig};

    #[test]
    fn suite_roundtrip_one_and_batch_list() {
        let cfg = TypeConfig::default();
        for kind in SUITE {
            let one = make_one(kind, 42, 0, &cfg).unwrap();
            let mut ser = KilnSer::default();
            assert!(ser.supports(kind));
            ser.prepare(&one).unwrap();
            assert!(!ser.one_cell_payload());
            let bytes = ser.serialize_bytes(&one).unwrap();
            let got = ser.deserialize_bytes(&bytes).unwrap();
            check_cell_fidelity(kind, std::slice::from_ref(&one), std::slice::from_ref(&got))
                .unwrap();

            let many: Vec<_> = (0..100)
                .map(|i| make_one(kind, 9, i, &cfg).unwrap())
                .collect();
            let mut ser = KilnSer::default();
            ser.prepare_many(&many).unwrap();
            assert!(ser.one_cell_payload());
            let mut buf = Vec::new();
            ser.serialize_fixtures(&many, &mut buf).unwrap();
            let got = ser.deserialize_bytes(&buf).unwrap();
            check_cell_fidelity(kind, &many, std::slice::from_ref(&got)).unwrap();
            let cap = buf.capacity();
            buf.clear();
            ser.serialize_fixtures(&many, &mut buf).unwrap();
            assert!(buf.capacity() >= cap);
            assert!(buf.len() > 4);
        }
        let ser = KilnSer::default();
        assert!(!ser.supports("graph"));
        assert!(!ser.supports("table"));
        assert!(!ser.supports("grid"));
        assert!(ser.supports("tensor"));
        assert!(ser.supports("tensor_view"));
        assert!(ser.supports("prompt"));
        assert!(ser.supports("shard"));
        assert!(ser.supports("request"));
    }

    fn small_cfg(kind: &str) -> TypeConfig {
        let value = match kind {
            "tensor" | "tensor_view" => serde_json::json!({"rows": 4, "cols": 4}),
            "prompt" | "request" => serde_json::json!({
                "batch": 2,
                "seq": 4,
                "vocab": 32,
                "string_len": {"min": 4, "max": 6}
            }),
            "shard" => serde_json::json!({"vocab": 4, "hidden": 3, "ffn": 5}),
            _ => serde_json::json!({}),
        };
        TypeConfig::from_value(value)
    }

    #[test]
    fn tensor_set_roundtrip_and_view_borrows() {
        for kind in TENSOR {
            let one = make_one(kind, 7, 0, &small_cfg(kind)).unwrap();
            let mut ser = KilnSer::default();
            ser.prepare(&one).unwrap();
            let bytes = ser.serialize_bytes(&one).unwrap();
            let got = ser.deserialize_bytes(&bytes).unwrap();
            check_cell_fidelity(kind, std::slice::from_ref(&one), std::slice::from_ref(&got))
                .unwrap();
            if *kind == "tensor_view" {
                let Fixture::TensorView(view) = &got else {
                    panic!("{}", got.name());
                };
                assert!(view.values.is_borrowed());
                assert!(view.values.borrowed_in(&bytes));
                assert_eq!(view.values.bit(0), 0x8000_0000);
                assert_eq!(view.values.bit(1), 0x7fc0_0000);
                let owned = decode(ser.schema.as_ref().unwrap(), &bytes).unwrap();
                let decoded = tensor_from(&owned).unwrap();
                assert!(!decoded.values.is_borrowed());
                assert_eq!(decoded.values, view.values);
            }
            if *kind == "tensor" {
                assert_eq!(bytes.len(), 12 + 16 * 4);
                let Fixture::Tensor(matrix) = &got else {
                    panic!("{}", got.name());
                };
                assert!(!matrix.values.is_borrowed());
                assert!(!matrix.values.borrowed_in(&bytes));
            }
        }
    }

    #[test]
    fn catalog_tensor_wire_is_4194316() {
        let cfg = TypeConfig::default();
        let one = make_one("tensor", 1, 0, &cfg).unwrap();
        let mut ser = KilnSer::default();
        ser.prepare(&one).unwrap();
        let bytes = ser.serialize_bytes(&one).unwrap();
        assert_eq!(bytes.len(), 4_194_316);
        let got = ser.deserialize_bytes(&bytes).unwrap();
        check_cell_fidelity(
            "tensor",
            std::slice::from_ref(&one),
            std::slice::from_ref(&got),
        )
        .unwrap();
        let view = make_one("tensor_view", 1, 0, &cfg).unwrap();
        let mut view_ser = KilnSer::default();
        view_ser.prepare(&view).unwrap();
        let view_bytes = view_ser.serialize_bytes(&view).unwrap();
        assert_eq!(view_bytes, bytes);
        let borrowed = view_ser.deserialize_bytes(&view_bytes).unwrap();
        check_cell_fidelity(
            "tensor_view",
            std::slice::from_ref(&view),
            std::slice::from_ref(&borrowed),
        )
        .unwrap();
        let Fixture::TensorView(matrix) = &borrowed else {
            panic!("{}", borrowed.name());
        };
        assert!(matrix.values.borrowed_in(&view_bytes));
        assert_eq!(matrix.values.len(), 1024 * 1024);
    }
}
