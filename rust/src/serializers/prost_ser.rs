//! prost (protobuf) path: schemas/v2/protobuf/benchmark_v2.proto.

use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, Message, Strings, Telemetry,
};
use anyhow::{anyhow, Result};

use super::{take_rearm, ver, BenchSerializer, NativeKind};

// package benchmark.v2 → OUT_DIR/benchmark.v2.rs
pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/benchmark.v2.rs"));
}

fn message_to_pb(m: &Message) -> pb::Message {
    pb::Message {
        f_bool: m.f_bool,
        f_int32: m.f_int32,
        f_int64: m.f_int64,
        f_float64: m.f_float64,
        f_string: m.f_string.clone(),
        f_bool_2: m.f_bool_2,
        f_int32_2: m.f_int32_2,
        f_string_2: m.f_string_2.clone(),
    }
}
fn message_from_pb(m: pb::Message) -> Message {
    Message {
        f_bool: m.f_bool,
        f_int32: m.f_int32,
        f_int64: m.f_int64,
        f_float64: m.f_float64,
        f_string: m.f_string,
        f_bool_2: m.f_bool_2,
        f_int32_2: m.f_int32_2,
        f_string_2: m.f_string_2,
    }
}

fn document_to_pb(d: &Document) -> pb::Document {
    pb::Document {
        id: d.id.clone(),
        status: d.status,
        meta: Some(pb::DocumentMeta {
            region: d.meta.region.clone(),
            version: d.meta.version,
        }),
        items: d
            .items
            .iter()
            .map(|it| pb::DocumentItem {
                sku: it.sku.clone(),
                qty: it.qty,
                price_minor: it.price_minor,
            })
            .collect(),
    }
}
fn document_from_pb(d: pb::Document) -> Document {
    let meta = d.meta.unwrap_or_default();
    Document {
        id: d.id,
        status: d.status,
        meta: DocumentMeta {
            region: meta.region,
            version: meta.version,
        },
        items: d
            .items
            .into_iter()
            .map(|it| DocumentItem {
                sku: it.sku,
                qty: it.qty,
                price_minor: it.price_minor,
            })
            .collect(),
    }
}

fn telemetry_to_pb(t: &Telemetry) -> pb::Telemetry {
    pb::Telemetry {
        source: t.source.clone(),
        ts: t.ts,
        tags: t.tags.clone(),
        values: t.values.clone(),
    }
}
fn telemetry_from_pb(t: pb::Telemetry) -> Telemetry {
    Telemetry {
        source: t.source,
        ts: t.ts,
        tags: t.tags,
        values: t.values,
    }
}

fn strings_to_pb(s: &Strings) -> pb::Strings {
    pb::Strings {
        items: s.items.clone(),
    }
}
fn strings_from_pb(s: pb::Strings) -> Strings {
    Strings { items: s.items }
}

fn event_to_pb(e: &Event) -> pb::Event {
    pb::Event {
        event_id: e.event_id.clone(),
        event_type: e.event_type.clone(),
        occurred_at: e.occurred_at,
        producer: e.producer.clone(),
        attrs: e
            .attrs
            .iter()
            .map(|a| pb::EventAttr {
                key: a.key.clone(),
                value: a.value.clone(),
            })
            .collect(),
    }
}
fn event_from_pb(e: pb::Event) -> Event {
    Event {
        event_id: e.event_id,
        event_type: e.event_type,
        occurred_at: e.occurred_at,
        producer: e.producer,
        attrs: e
            .attrs
            .into_iter()
            .map(|a| EventAttr {
                key: a.key,
                value: a.value,
            })
            .collect(),
    }
}

enum ProstMsg {
    Message(pb::Message),
    Document(pb::Document),
    Telemetry(pb::Telemetry),
    Strings(pb::Strings),
    Event(pb::Event),
}

pub struct ProstSer {
    kind: &'static str,
    buf: Vec<u8>,
}
impl Default for ProstSer {
    fn default() -> Self {
        Self {
            kind: "message",
            buf: Vec::with_capacity(4096),
        }
    }
}

fn fixture_to_prost(fixture: &Fixture) -> ProstMsg {
    match fixture {
        Fixture::Message(m) => ProstMsg::Message(message_to_pb(m)),
        Fixture::Document(d) => ProstMsg::Document(document_to_pb(d)),
        Fixture::Telemetry(t) => ProstMsg::Telemetry(telemetry_to_pb(t)),
        Fixture::Strings(s) => ProstMsg::Strings(strings_to_pb(s)),
        Fixture::Event(e) => ProstMsg::Event(event_to_pb(e)),
    }
}

impl BenchSerializer for ProstSer {
    fn name(&self) -> &'static str {
        "prost"
    }
    fn version(&self) -> &'static str {
        ver("prost")
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Message
    }
    fn supports(&self, test_data_name: &str) -> bool {
        matches!(
            test_data_name,
            "message" | "document" | "telemetry" | "strings" | "event"
        )
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        // Kind tracking for decode; domain→pb conversion happens per serialize so N>1 batches stay correct.
        self.kind = fixture.name();
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        use prost::Message as ProstMessage;
        let msg = fixture_to_prost(fixture);
        let len = match &msg {
            ProstMsg::Message(m) => m.encoded_len(),
            ProstMsg::Document(m) => m.encoded_len(),
            ProstMsg::Telemetry(m) => m.encoded_len(),
            ProstMsg::Strings(m) => m.encoded_len(),
            ProstMsg::Event(m) => m.encoded_len(),
        };
        self.buf.clear();
        self.buf.reserve(len);
        match &msg {
            ProstMsg::Message(m) => m.encode(&mut self.buf)?,
            ProstMsg::Document(m) => m.encode(&mut self.buf)?,
            ProstMsg::Telemetry(m) => m.encode(&mut self.buf)?,
            ProstMsg::Strings(m) => m.encode(&mut self.buf)?,
            ProstMsg::Event(m) => m.encode(&mut self.buf)?,
        }
        Ok(take_rearm(&mut self.buf))
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        // Alias avoids clash with domain `Message`.
        use prost::Message as ProstMessage;
        match self.kind {
            "message" => {
                let m = <pb::Message as ProstMessage>::decode(data)?;
                Ok(Fixture::Message(message_from_pb(m)))
            }
            "document" => {
                let m = <pb::Document as ProstMessage>::decode(data)?;
                Ok(Fixture::Document(document_from_pb(m)))
            }
            "telemetry" => {
                let m = <pb::Telemetry as ProstMessage>::decode(data)?;
                Ok(Fixture::Telemetry(telemetry_from_pb(m)))
            }
            "strings" => {
                let m = <pb::Strings as ProstMessage>::decode(data)?;
                Ok(Fixture::Strings(strings_from_pb(m)))
            }
            "event" => {
                let m = <pb::Event as ProstMessage>::decode(data)?;
                Ok(Fixture::Event(event_from_pb(m)))
            }
            other => Err(anyhow!("prost: unsupported kind {other}")),
        }
    }
}
