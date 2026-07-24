//! Apache Avro (`apache-avro`) — schemaless single-object binary via prepared schema.
//!
//! Optimal path: parse schema once in `prepare`; timed path uses
//! `write_avro_datum_ref` / `from_avro_datum` + `from_value` (no OCF headers).
//! https://docs.rs/apache-avro

use crate::data::{Document, Event, Fixture, Message, Strings, Telemetry};
use anyhow::{anyhow, Context, Result};
use apache_avro::{from_avro_datum, from_value, write_avro_datum_ref, Schema};
use std::io::{Cursor, Read, Write};
use std::sync::OnceLock;

use super::{ver, BenchSerializer, CountWrite, NativeKind, StreamMode};

// ---------------------------------------------------------------------------
// Schemas (field names match serde / data catalog snake_case)
// ---------------------------------------------------------------------------

fn schema_message() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        Schema::parse_str(
            r#"{
            "type":"record","name":"Message","fields":[
                {"name":"f_bool","type":"boolean"},{"name":"f_int32","type":"int"},
                {"name":"f_int64","type":"long"},{"name":"f_float64","type":"double"},
                {"name":"f_string","type":"string"},{"name":"f_bool_2","type":"boolean"},
                {"name":"f_int32_2","type":"int"},{"name":"f_string_2","type":"string"}
            ]
        }"#,
        )
        .expect("message avro schema")
    })
}

fn schema_document() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        Schema::parse_str(
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
        }"#,
        )
        .expect("document avro schema")
    })
}

fn schema_telemetry() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        Schema::parse_str(
            r#"{
            "type":"record","name":"Telemetry","fields":[
                {"name":"source","type":"string"},{"name":"ts","type":"long"},
                {"name":"tags","type":{"type":"array","items":"string"}},
                {"name":"values","type":{"type":"array","items":"double"}}
            ]
        }"#,
        )
        .expect("telemetry avro schema")
    })
}

fn schema_strings() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        Schema::parse_str(
            r#"{
            "type":"record","name":"Strings","fields":[
                {"name":"items","type":{"type":"array","items":"string"}}
            ]
        }"#,
        )
        .expect("strings avro schema")
    })
}

fn schema_event() -> &'static Schema {
    static S: OnceLock<Schema> = OnceLock::new();
    S.get_or_init(|| {
        Schema::parse_str(
            r#"{
            "type":"record","name":"Event","fields":[
                {"name":"event_id","type":"string"},{"name":"event_type","type":"string"},
                {"name":"occurred_at","type":"long"},{"name":"producer","type":"string"},
                {"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":[
                    {"name":"key","type":"string"},{"name":"value","type":"string"}
                ]}}}
            ]
        }"#,
        )
        .expect("event avro schema")
    })
}

fn schema_for(name: &str) -> Result<&'static Schema> {
    Ok(match name {
        "message" => schema_message(),
        "document" => schema_document(),
        "telemetry" => schema_telemetry(),
        "strings" => schema_strings(),
        "event" => schema_event(),
        other => return Err(anyhow!("apache-avro: no schema for {other}")),
    })
}

// ---------------------------------------------------------------------------
// Codec
// ---------------------------------------------------------------------------

pub struct ApacheAvroSer {
    schema: Option<&'static Schema>,
    kind: &'static str,
}

impl Default for ApacheAvroSer {
    fn default() -> Self {
        Self {
            schema: None,
            kind: "message",
        }
    }
}

impl BenchSerializer for ApacheAvroSer {
    fn name(&self) -> &'static str {
        "apache-avro"
    }
    fn version(&self) -> &'static str {
        ver("apache-avro")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Serde
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.kind = fixture.name();
        self.schema = Some(schema_for(self.kind)?);
        Ok(())
    }

    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let schema = self.schema.context("apache-avro: prepare not called")?;
        match fixture {
            Fixture::Message(m) => write_one(schema, m, out),
            Fixture::Document(d) => write_one(schema, d, out),
            Fixture::Telemetry(t) => write_one(schema, t, out),
            Fixture::Strings(s) => write_one(schema, s, out),
            Fixture::Event(e) => write_one(schema, e, out),
        }
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let schema = self.schema.context("apache-avro: prepare not called")?;
        let mut cur = Cursor::new(data);
        self.read_from(schema, &mut cur)
    }

    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let schema = self.schema.context("apache-avro: prepare not called")?;
        let mut counter = CountWrite { inner: w, n: 0 };
        match fixture {
            Fixture::Message(m) => {
                write_avro_datum_ref(schema, m, &mut counter).context("apache-avro stream write")?;
            }
            Fixture::Document(d) => {
                write_avro_datum_ref(schema, d, &mut counter).context("apache-avro stream write")?;
            }
            Fixture::Telemetry(t) => {
                write_avro_datum_ref(schema, t, &mut counter).context("apache-avro stream write")?;
            }
            Fixture::Strings(s) => {
                write_avro_datum_ref(schema, s, &mut counter).context("apache-avro stream write")?;
            }
            Fixture::Event(e) => {
                write_avro_datum_ref(schema, e, &mut counter).context("apache-avro stream write")?;
            }
        }
        Ok(counter.n)
    }

    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        let schema = self.schema.context("apache-avro: prepare not called")?;
        self.read_from(schema, r)
    }
}

impl ApacheAvroSer {
    fn read_from(&self, schema: &Schema, r: &mut dyn Read) -> Result<Fixture> {
        // from_avro_datum requires R: Read + Sized; wrap the dyn Read.
        struct DynR<'a>(&'a mut dyn Read);
        impl Read for DynR<'_> {
            fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
                self.0.read(buf)
            }
        }
        let val = from_avro_datum(schema, &mut DynR(r), None).context("apache-avro read")?;
        Ok(match self.kind {
            "message" => Fixture::Message(from_value::<Message>(&val)?),
            "document" => Fixture::Document(from_value::<Document>(&val)?),
            "telemetry" => Fixture::Telemetry(from_value::<Telemetry>(&val)?),
            "strings" => Fixture::Strings(from_value::<Strings>(&val)?),
            "event" => Fixture::Event(from_value::<Event>(&val)?),
            other => return Err(anyhow!("apache-avro: unknown kind {other}")),
        })
    }
}

fn write_one<T: serde::Serialize>(schema: &Schema, value: &T, out: &mut Vec<u8>) -> Result<()> {
    write_avro_datum_ref(schema, value, out).context("apache-avro write")?;
    Ok(())
}
