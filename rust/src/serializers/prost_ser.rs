//! prost (protobuf) path: schemas/v2/protobuf/benchmark_v2.proto.

use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, Message, NestedItem,
    NestedMeta, NestedRow, Signal, SignalLeg, Strings, TableRow, Telemetry,
};
use anyhow::{anyhow, Result};
use std::io::Write;

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

fn table_to_pb(row: &TableRow) -> pb::Table {
    pb::Table {
        f_float_0: row.f_float_0,
        f_float_1: row.f_float_1,
        f_float_2: row.f_float_2,
        f_float_3: row.f_float_3,
        f_float_4: row.f_float_4,
        f_float_5: row.f_float_5,
        f_float_6: row.f_float_6,
        f_float_7: row.f_float_7,
        f_float_8: row.f_float_8,
        f_float_9: row.f_float_9,
        f_float_10: row.f_float_10,
        f_float_11: row.f_float_11,
        f_float_12: row.f_float_12,
        f_float_13: row.f_float_13,
        f_float_14: row.f_float_14,
        f_float_15: row.f_float_15,
        f_int_0: row.f_int_0,
        f_int_1: row.f_int_1,
        f_int_2: row.f_int_2,
        f_int_3: row.f_int_3,
        f_str_0: row.f_str_0.clone(),
        f_str_1: row.f_str_1.clone(),
    }
}
fn table_from_pb(row: pb::Table) -> TableRow {
    TableRow {
        f_float_0: row.f_float_0,
        f_float_1: row.f_float_1,
        f_float_2: row.f_float_2,
        f_float_3: row.f_float_3,
        f_float_4: row.f_float_4,
        f_float_5: row.f_float_5,
        f_float_6: row.f_float_6,
        f_float_7: row.f_float_7,
        f_float_8: row.f_float_8,
        f_float_9: row.f_float_9,
        f_float_10: row.f_float_10,
        f_float_11: row.f_float_11,
        f_float_12: row.f_float_12,
        f_float_13: row.f_float_13,
        f_float_14: row.f_float_14,
        f_float_15: row.f_float_15,
        f_int_0: row.f_int_0,
        f_int_1: row.f_int_1,
        f_int_2: row.f_int_2,
        f_int_3: row.f_int_3,
        f_str_0: row.f_str_0,
        f_str_1: row.f_str_1,
    }
}

fn nested_to_pb(row: &NestedRow) -> pb::NestedRow {
    pb::NestedRow {
        id: row.id.clone(),
        status: row.status,
        meta: Some(pb::NestedMeta {
            region: row.meta.region.clone(),
            version: row.meta.version,
        }),
        items: row
            .items
            .iter()
            .map(|it| pb::NestedItem {
                sku: it.sku.clone(),
                qty: it.qty,
                price_minor: it.price_minor,
            })
            .collect(),
    }
}
fn nested_from_pb(row: pb::NestedRow) -> NestedRow {
    let meta = row.meta.unwrap_or_default();
    NestedRow {
        id: row.id,
        status: row.status,
        meta: NestedMeta {
            region: meta.region,
            version: meta.version,
        },
        items: row
            .items
            .into_iter()
            .map(|it| NestedItem {
                sku: it.sku,
                qty: it.qty,
                price_minor: it.price_minor,
            })
            .collect(),
    }
}

fn signal_to_pb(sig: &Signal) -> pb::Signal {
    pb::Signal {
        seq: sig.seq,
        ts: sig.ts,
        price_mantissa: sig.price_mantissa,
        qty: sig.qty,
        flags: sig.flags,
        symbol: sig.symbol.clone(),
        venue: sig.venue.clone(),
        legs: sig
            .legs
            .iter()
            .map(|leg| pb::SignalLeg {
                leg_id: leg.leg_id,
                leg_qty: leg.leg_qty,
                leg_pad: leg.leg_pad,
            })
            .collect(),
    }
}
fn signal_from_pb(sig: pb::Signal) -> Signal {
    Signal {
        seq: sig.seq,
        ts: sig.ts,
        price_mantissa: sig.price_mantissa,
        qty: sig.qty,
        flags: sig.flags,
        symbol: sig.symbol,
        venue: sig.venue,
        legs: sig
            .legs
            .into_iter()
            .map(|leg| SignalLeg {
                leg_id: leg.leg_id,
                leg_qty: leg.leg_qty,
                leg_pad: leg.leg_pad,
            })
            .collect(),
    }
}

fn tables_from(fixtures: &[Fixture]) -> Result<Vec<pb::Table>> {
    fixtures
        .iter()
        .map(|f| match f {
            Fixture::Table(r) | Fixture::TableProject(r) => Ok(table_to_pb(r)),
            _ => Err(anyhow!("prost: expected table row")),
        })
        .collect()
}

enum PreparedPb {
    Message(Vec<pb::Message>),
    Document(Vec<pb::Document>),
    Telemetry(Vec<pb::Telemetry>),
    Strings(Vec<pb::Strings>),
    Event(Vec<pb::Event>),
    Table(Vec<pb::Table>),
    TableBatch(pb::BatchTable),
    Nested(Vec<pb::NestedRow>),
    NestedBatch(pb::BatchNestedRow),
    Signal(Vec<pb::Signal>),
    SignalBatch(pb::BatchSignal),
}

pub struct ProstSer {
    kind: &'static str,
    batch: bool,
    prepared: PreparedPb,
    enc_i: usize,
}
impl Default for ProstSer {
    fn default() -> Self {
        Self {
            kind: "message",
            batch: false,
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
            "message"
                | "document"
                | "telemetry"
                | "strings"
                | "event"
                | "table"
                | "table_project"
                | "nested_table"
                | "signal"
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
        self.batch = fixtures.len() > 1 && crate::data::is_columnar_id(self.kind);
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
            Fixture::Table(_) | Fixture::TableProject(_) => {
                let tables = tables_from(fixtures)?;
                if self.batch {
                    PreparedPb::TableBatch(pb::BatchTable { items: tables })
                } else {
                    PreparedPb::Table(tables)
                }
            }
            Fixture::NestedTable(_) => {
                let rows = fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::NestedTable(row) = f else {
                            return Err(anyhow!("prost: expected NestedTable"));
                        };
                        Ok(nested_to_pb(row))
                    })
                    .collect::<Result<Vec<_>>>()?;
                if self.batch {
                    PreparedPb::NestedBatch(pb::BatchNestedRow { items: rows })
                } else {
                    PreparedPb::Nested(rows)
                }
            }
            Fixture::Signal(_) => {
                let rows = fixtures
                    .iter()
                    .map(|f| {
                        let Fixture::Signal(row) = f else {
                            return Err(anyhow!("prost: expected Signal"));
                        };
                        Ok(signal_to_pb(row))
                    })
                    .collect::<Result<Vec<_>>>()?;
                if self.batch {
                    PreparedPb::SignalBatch(pb::BatchSignal { items: rows })
                } else {
                    PreparedPb::Signal(rows)
                }
            }
            Fixture::Rows(_) | Fixture::Projected(_) | Fixture::Graph(_) | Fixture::Grid(_) => {
                return Err(anyhow!("prost: unexpected fixture shape"));
            }
        };
        Ok(())
    }
    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        if crate::data::is_columnar_id(self.kind) {
            if fixtures.is_empty() {
                return Err(anyhow!("prost: empty cell"));
            }
            self.begin_cell_encode();
            return self.serialize_into(&fixtures[0], out);
        }
        if fixtures.len() == 1 {
            return self.serialize_into(&fixtures[0], out);
        }
        let rows = Fixture::Rows(fixtures.to_vec());
        self.serialize_into(&rows, out)
    }
    fn begin_cell_encode(&mut self) {
        self.enc_i = 0;
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        // Each stream call is its own pass. The bytes cell path resets in
        // begin_cell_encode / serialize_fixtures; this matches that for N=1.
        self.begin_cell_encode();
        let mut data = Vec::with_capacity(4096);
        self.serialize_into(fixture, &mut data)?;
        w.write_all(&data)?;
        Ok(data.len())
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
            PreparedPb::Table(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::TableBatch(msg) => encode_msg(msg, out),
            PreparedPb::Nested(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::NestedBatch(msg) => encode_msg(msg, out),
            PreparedPb::Signal(v) => encode_msg(v.get(i).ok_or_else(|| anyhow!("prost: encode index"))?, out),
            PreparedPb::SignalBatch(msg) => encode_msg(msg, out),
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
            "table" => {
                if self.batch {
                    let m = <pb::BatchTable as ProstMessage>::decode(data)?;
                    let rows = m.items.into_iter().map(|t| Fixture::Table(table_from_pb(t))).collect();
                    Ok(Fixture::Rows(rows))
                } else {
                    let m = <pb::Table as ProstMessage>::decode(data)?;
                    Ok(Fixture::Table(table_from_pb(m)))
                }
            }
            "table_project" => {
                let values = if self.batch {
                    let m = <pb::BatchTable as ProstMessage>::decode(data)?;
                    m.items.into_iter().map(|t| t.f_float_0).collect()
                } else {
                    let m = <pb::Table as ProstMessage>::decode(data)?;
                    vec![m.f_float_0]
                };
                Ok(Fixture::Projected(values))
            }
            "nested_table" => {
                if self.batch {
                    let m = <pb::BatchNestedRow as ProstMessage>::decode(data)?;
                    let rows = m
                        .items
                        .into_iter()
                        .map(|row| Fixture::NestedTable(nested_from_pb(row)))
                        .collect();
                    Ok(Fixture::Rows(rows))
                } else {
                    let m = <pb::NestedRow as ProstMessage>::decode(data)?;
                    Ok(Fixture::NestedTable(nested_from_pb(m)))
                }
            }
            "signal" => {
                if self.batch {
                    let m = <pb::BatchSignal as ProstMessage>::decode(data)?;
                    let rows = m
                        .items
                        .into_iter()
                        .map(|row| Fixture::Signal(signal_from_pb(row)))
                        .collect();
                    Ok(Fixture::Rows(rows))
                } else {
                    let m = <pb::Signal as ProstMessage>::decode(data)?;
                    Ok(Fixture::Signal(signal_from_pb(m)))
                }
            }
            other => Err(anyhow!("prost: unsupported kind {other}")),
        }
    }
}
