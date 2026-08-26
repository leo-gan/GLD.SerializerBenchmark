//! prost (protobuf) path: schemas/v2/protobuf/benchmark_v2.proto.

use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, Message, Strings, Telemetry,
};
use anyhow::{anyhow, Result};

use super::{ver, BenchSerializer, NativeKind};

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

enum PreparedPb {
    Message(Vec<pb::Message>),
    Document(Vec<pb::Document>),
    Telemetry(Vec<pb::Telemetry>),
    Strings(Vec<pb::Strings>),
    Event(Vec<pb::Event>),
}

pub struct ProstSer {
    kind: &'static str,
    prepared: PreparedPb,
    enc_i: usize,
}
impl Default for ProstSer {
    fn default() -> Self {
        Self {
            kind: "message",
            prepared: PreparedPb::Message(Vec::new()),
            enc_i: 0,
        }
    }
}

fn encode_msg<M: prost::Message>(msg: &M, out: &mut Vec<u8>) -> Result<()> {
    use prost::Message as ProstMessage;
    out.reserve(ProstMessage::encoded_len(msg));
    ProstMessage::encode(msg, out)?;
    Ok(())
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
        self.prepare_many(std::slice::from_ref(fixture))
    }
    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        if fixtures.is_empty() {
            return Err(anyhow!("prost: empty cell"));
        }
        self.kind = fixtures[0].name();
        self.enc_i = 0;
        self.prepared = match fixtures[0] {
            Fixture::Message(_) => PreparedPb::Message(
                fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::Message(m) = f else {
                            return Err(anyhow!("prost: expected Message"));
                        };
                        Ok(message_to_pb(m))
                    })
                    .collect::<Result<Vec<_>>>()?,
            ),
            Fixture::Document(_) => PreparedPb::Document(
                fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::Document(d) = f else {
                            return Err(anyhow!("prost: expected Document"));
                        };
                        Ok(document_to_pb(d))
                    })
                    .collect::<Result<Vec<_>>>()?,
            ),
            Fixture::Telemetry(_) => PreparedPb::Telemetry(
                fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::Telemetry(t) = f else {
                            return Err(anyhow!("prost: expected Telemetry"));
                        };
                        Ok(telemetry_to_pb(t))
                    })
                    .collect::<Result<Vec<_>>>()?,
            ),
            Fixture::Strings(_) => PreparedPb::Strings(
                fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::Strings(s) = f else {
                            return Err(anyhow!("prost: expected Strings"));
                        };
                        Ok(strings_to_pb(s))
                    })
                    .collect::<Result<Vec<_>>>()?,
            ),
            Fixture::Event(_) => PreparedPb::Event(
                fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::Event(e) = f else {
                            return Err(anyhow!("prost: expected Event"));
                        };
                        Ok(event_to_pb(e))
                    })
                    .collect::<Result<Vec<_>>>()?,
            ),
        };
        Ok(())
    }
    fn begin_cell_encode(&mut self) {
        self.enc_i = 0;
    }
    fn serialize_into(&mut self, _fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let i = self.enc_i;
        self.enc_i += 1;
        match &self.prepared {
            PreparedPb::Message(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::Document(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::Telemetry(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::Strings(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::Event(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
        }
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
