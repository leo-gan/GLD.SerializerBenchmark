//! High-performance Avro binary via **`serde_avro_fast`** (schemaless single-object datum).
//!
//! ## Why not official `apache-avro`?
//!
//! `apache-avro`’s public datum path deserializes through an intermediate
//! [`Value`](https://docs.rs/apache-avro) (`from_avro_datum` + `from_value`). That
//! two-step API is correct and wire-compatible, but on suite `message` it is
//! **slower than `serde_json` / `sonic-rs`** (~0.9 µs total vs ~0.4 µs) because
//! almost all cost is deser (heap `Value` graph). Serialize alone is competitive.
//!
//! [`serde_avro_fast`](https://docs.rs/serde_avro_fast) removes `Value`, does one-pass
//! serde encode/decode, and produces **identical datum bytes** for suite schemas
//! (verified cross-compat with `apache-avro`). Its own benches claim ~10–20× vs
//! apache-avro; local microbench on `Message` saw ~4× total (~210 ns vs ~790 ns).
//!
//! Optimal harness path (crate docs):
//! - parse [`Schema`] once; reuse [`ser::SerializerConfig`] across serializations
//! - timed: [`to_datum`] into the harness `Vec` / `Write` (clear+reuse buffer)
//! - timed: [`from_datum_slice`] (prefer slice over reader when bytes are in memory)
//!
//! https://github.com/Ten0/serde_avro_fast

use crate::data::{
    is_columnar_id, Document, Event, Fixture, Message, NestedRow, Signal,
    Strings, TableRow, Telemetry,
};
use anyhow::{anyhow, Context, Result};
use serde::de::DeserializeOwned;
use serde_avro_fast::ser::SerializerConfig;
use serde_avro_fast::{from_datum_reader, from_datum_slice, to_datum, Schema};
use std::io::{BufReader, Cursor, Read, Write};
use std::sync::OnceLock;

use super::{ver, BenchSerializer, CountWrite, NativeKind, StreamMode};

// ---------------------------------------------------------------------------
// Schemas (field names match serde / data catalog snake_case)
// ---------------------------------------------------------------------------

fn schema_message() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        r#"{
            "type":"record","name":"Message","fields":[
                {"name":"f_bool","type":"boolean"},{"name":"f_int32","type":"int"},
                {"name":"f_int64","type":"long"},{"name":"f_float64","type":"double"},
                {"name":"f_string","type":"string"},{"name":"f_bool_2","type":"boolean"},
                {"name":"f_int32_2","type":"int"},{"name":"f_string_2","type":"string"}
            ]
        }"#
        .parse()
        .expect("message avro schema")
    })
}

fn schema_document() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        r#"{
            "type":"record","name":"Document","fields":[
                {"name":"id","type":"string"},{"name":"status","type":"int"},
                {"name":"meta","type":{"type":"record","name":"DocumentMeta","fields":[
                    {"name":"region","type":"string"},{"name":"version","type":"int"}
                ]}},
                {"name":"items","type":{"type":"array","items":{"type":"record","name":"DocumentItem","fields":[
                    {"name":"sku","type":"string"},{"name":"qty","type":"int"},{"name":"price_minor","type":"long"}
                ]}}}
            ]
        }"#
        .parse()
        .expect("document avro schema")
    })
}

fn schema_telemetry() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        r#"{
            "type":"record","name":"Telemetry","fields":[
                {"name":"source","type":"string"},{"name":"ts","type":"long"},
                {"name":"tags","type":{"type":"array","items":"string"}},
                {"name":"values","type":{"type":"array","items":"double"}}
            ]
        }"#
        .parse()
        .expect("telemetry avro schema")
    })
}

fn schema_strings() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        r#"{
            "type":"record","name":"Strings","fields":[
                {"name":"items","type":{"type":"array","items":"string"}}
            ]
        }"#
        .parse()
        .expect("strings avro schema")
    })
}

fn schema_event() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        r#"{
            "type":"record","name":"Event","fields":[
                {"name":"event_id","type":"string"},{"name":"event_type","type":"string"},
                {"name":"occurred_at","type":"long"},{"name":"producer","type":"string"},
                {"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":[
                    {"name":"key","type":"string"},{"name":"value","type":"string"}
                ]}}}
            ]
        }"#
        .parse()
        .expect("event avro schema")
    })
}

fn schema_table() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        include_str!("../../../schemas/v2/avro/table.avsc")
            .parse()
            .expect("table avsc")
    })
}

fn schema_nested() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        include_str!("../../../schemas/v2/avro/nested_table.avsc")
            .parse()
            .expect("nested_table avsc")
    })
}

fn schema_signal() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        include_str!("../../../schemas/v2/avro/signal.avsc")
            .parse()
            .expect("signal avsc")
    })
}

fn schema_for(name: &str) -> Result<&'static Schema> {
    Ok(match name {
        "message" => schema_message(),
        "document" => schema_document(),
        "telemetry" => schema_telemetry(),
        "strings" => schema_strings(),
        "event" => schema_event(),
        // table_project reuses the table record.
        "table" | "table_project" => schema_table(),
        "nested_table" => schema_nested(),
        "signal" => schema_signal(),
        other => return Err(anyhow!("serde_avro_fast: no schema for {other}")),
    })
}

fn write_datum<W: Write>(
    cfg: &mut SerializerConfig<'_>,
    fixture: &Fixture,
    w: W,
) -> Result<W> {
    let written = match fixture {
        Fixture::Message(m) => to_datum(m, w, cfg),
        Fixture::Document(d) => to_datum(d, w, cfg),
        Fixture::Telemetry(t) => to_datum(t, w, cfg),
        Fixture::Strings(s) => to_datum(s, w, cfg),
        Fixture::Event(e) => to_datum(e, w, cfg),
        Fixture::Table(r) | Fixture::TableProject(r) => to_datum(r, w, cfg),
        Fixture::NestedTable(r) => to_datum(r, w, cfg),
        Fixture::Signal(s) => to_datum(s, w, cfg),
        Fixture::Rows(_) | Fixture::Projected(_) => {
            return Err(anyhow!(
                "serde_avro_fast: encode rows with serialize_fixtures"
            ));
        }
        Fixture::Graph(_) => {
            return Err(anyhow!("serde_avro_fast: graph is not a tree"));
        }
    };
    written.context("serde_avro_fast to_datum")
}

// ---------------------------------------------------------------------------
// Codec
// ---------------------------------------------------------------------------

pub struct AvroFastSer {
    schema: Option<&'static Schema>,
    /// Reused across serializations (~40% gain per crate docs).
    ser_config: Option<SerializerConfig<'static>>,
    kind: &'static str,
    /// How many datums `prepare_many` saw. Columnar N>1 is concatenated datums.
    count: usize,
}

impl Default for AvroFastSer {
    fn default() -> Self {
        Self {
            schema: None,
            ser_config: None,
            kind: "message",
            count: 1,
        }
    }
}

impl BenchSerializer for AvroFastSer {
    fn name(&self) -> &'static str {
        "serde_avro_fast"
    }
    fn version(&self) -> &'static str {
        ver("serde_avro_fast")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Serde
    }

    fn supports(&self, test_data_name: &str) -> bool {
        if test_data_name == "graph" {
            return false;
        }
        !is_columnar_id(test_data_name)
            || matches!(
                test_data_name,
                "table" | "table_project" | "nested_table" | "signal"
            )
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.prepare_many(std::slice::from_ref(fixture))
    }

    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        if fixtures.is_empty() {
            return Err(anyhow!("serde_avro_fast: empty cell"));
        }
        self.kind = fixtures[0].name();
        self.count = fixtures.len();
        let schema = schema_for(self.kind)?;
        self.schema = Some(schema);
        self.ser_config = Some(SerializerConfig::new(schema));
        Ok(())
    }

    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let cfg = self
            .ser_config
            .as_mut()
            .context("serde_avro_fast: prepare not called")?;
        // Reuse capacity: to_datum takes the Vec and appends one datum.
        let buf = std::mem::take(out);
        *out = write_datum(cfg, fixture, buf)?;
        Ok(())
    }

    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        self.count = fixtures.len();
        for fx in fixtures {
            self.serialize_into(fx, out)?;
        }
        Ok(())
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let schema = self.schema.context("serde_avro_fast: prepare not called")?;
        if is_columnar_id(self.kind) {
            return self.decode_columnar(data);
        }
        Ok(match self.kind {
            "message" => Fixture::Message(
                from_datum_slice::<Message>(data, schema).context("serde_avro_fast from_datum")?,
            ),
            "document" => Fixture::Document(
                from_datum_slice::<Document>(data, schema).context("serde_avro_fast from_datum")?,
            ),
            "telemetry" => Fixture::Telemetry(
                from_datum_slice::<Telemetry>(data, schema).context("serde_avro_fast from_datum")?,
            ),
            "strings" => Fixture::Strings(
                from_datum_slice::<Strings>(data, schema).context("serde_avro_fast from_datum")?,
            ),
            "event" => Fixture::Event(
                from_datum_slice::<Event>(data, schema).context("serde_avro_fast from_datum")?,
            ),
            other => return Err(anyhow!("serde_avro_fast: unknown kind {other}")),
        })
    }

    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let cfg = self
            .ser_config
            .as_mut()
            .context("serde_avro_fast: prepare not called")?;
        let mut counter = CountWrite { inner: w, n: 0 };
        write_datum(cfg, fixture, &mut counter)?;
        Ok(counter.n)
    }

    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        if is_columnar_id(self.kind) && self.count > 1 {
            let mut data = Vec::new();
            r.read_to_end(&mut data)?;
            return self.deserialize_bytes(&data);
        }
        let schema = self.schema.context("serde_avro_fast: prepare not called")?;
        // from_datum_reader requires BufRead.
        let mut br = BufReader::new(r);
        let fx = match self.kind {
            "message" => Fixture::Message(
                from_datum_reader::<_, Message>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "document" => Fixture::Document(
                from_datum_reader::<_, Document>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "telemetry" => Fixture::Telemetry(
                from_datum_reader::<_, Telemetry>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "strings" => Fixture::Strings(
                from_datum_reader::<_, Strings>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "event" => Fixture::Event(
                from_datum_reader::<_, Event>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "table" => Fixture::Table(
                from_datum_reader::<_, TableRow>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "table_project" => {
                let row = from_datum_reader::<_, TableRow>(&mut br, schema)
                    .context("serde_avro_fast stream read")?;
                return Ok(Fixture::Projected(vec![row.f_float_0]));
            }
            "nested_table" => Fixture::NestedTable(
                from_datum_reader::<_, NestedRow>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            "signal" => Fixture::Signal(
                from_datum_reader::<_, Signal>(&mut br, schema)
                    .context("serde_avro_fast stream read")?,
            ),
            other => return Err(anyhow!("serde_avro_fast: unknown kind {other}")),
        };
        Ok(fx)
    }
}

impl AvroFastSer {
    fn read_all<T: DeserializeOwned>(&self, data: &[u8]) -> Result<Vec<T>> {
        let schema = self.schema.context("serde_avro_fast: prepare not called")?;
        let mut cur = Cursor::new(data);
        let mut out = Vec::new();
        while (cur.position() as usize) < data.len() {
            let before = cur.position();
            let item = from_datum_reader::<_, T>(&mut cur, schema)
                .context("serde_avro_fast from_datum_reader")?;
            if cur.position() <= before {
                anyhow::bail!("serde_avro_fast: reader made no progress at {before}");
            }
            out.push(item);
        }
        if out.is_empty() {
            anyhow::bail!("serde_avro_fast: empty payload");
        }
        Ok(out)
    }

    fn decode_columnar(&self, data: &[u8]) -> Result<Fixture> {
        match self.kind {
            "table" => {
                let rows = self
                    .read_all::<TableRow>(data)?
                    .into_iter()
                    .map(Fixture::Table)
                    .collect::<Vec<_>>();
                Ok(one_or_rows(rows))
            }
            "table_project" => {
                let values = self
                    .read_all::<TableRow>(data)?
                    .into_iter()
                    .map(|row| row.f_float_0)
                    .collect();
                Ok(Fixture::Projected(values))
            }
            "nested_table" => {
                let rows = self
                    .read_all::<NestedRow>(data)?
                    .into_iter()
                    .map(Fixture::NestedTable)
                    .collect::<Vec<_>>();
                Ok(one_or_rows(rows))
            }
            "signal" => {
                let rows = self
                    .read_all::<Signal>(data)?
                    .into_iter()
                    .map(Fixture::Signal)
                    .collect::<Vec<_>>();
                Ok(one_or_rows(rows))
            }
            other => Err(anyhow!("serde_avro_fast: unknown kind {other}")),
        }
    }
}

fn one_or_rows(rows: Vec<Fixture>) -> Fixture {
    if rows.len() == 1 {
        rows.into_iter().next().unwrap()
    } else {
        Fixture::Rows(rows)
    }
}
