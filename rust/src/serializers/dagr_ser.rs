//! Dagr path: schemas/v2/dagr/schema.py → `dagr build` → rust/dagr_gen (crate `benchmark_v2`).
//!
//! One DataGraph per suite type, all nodes `packed`. Serialize uses the generated
//! **direct builder** (plain borrowed value structs → buffer, no arena) into one
//! `DagrBuilder` reused across calls; the bytes are copied into the harness buffer
//! because Dagr writes back-to-front. Deserialize uses the generated **lazy reader**
//! and materializes the owned domain value for the fidelity check (the decode + the
//! domain build are both timed, like prost's `decode` + `from_pb`).
//!
//! The borrowed direct structs are built from the domain value inside the timed path
//! (that includes one small `Vec` per array field) — there is no untimed native model.

use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, Message, Strings, Telemetry,
};
use anyhow::{anyhow, Result};
use benchmark_v2::dagr_runtime::{DagrBuilder, DagrError, PackedSink};
use benchmark_v2::{
    document_graph_core as doc_core, document_graph_lazy as doc_lazy,
    event_graph_core as ev_core, event_graph_lazy as ev_lazy, message_graph_core as msg_core,
    message_graph_lazy as msg_lazy, strings_graph_core as str_core,
    strings_graph_lazy as str_lazy, telemetry_graph_core as tel_core,
    telemetry_graph_lazy as tel_lazy,
};

use super::{BenchSerializer, NativeKind};

fn err(e: DagrError) -> anyhow::Error {
    anyhow!("dagr: {e:?}")
}

fn s(v: Option<&str>) -> String {
    v.unwrap_or_default().to_owned()
}

// ── encode (direct builder) ─────────────────────────────────────────────────

fn encode_message(b: &mut DagrBuilder, m: &Message) -> Result<(), DagrError> {
    let v = msg_core::direct::Message {
        f_bool: Some(m.f_bool),
        f_int32: Some(m.f_int32),
        f_int64: Some(m.f_int64),
        f_float64: Some(m.f_float64),
        f_string: Some(&m.f_string),
        f_bool_2: Some(m.f_bool_2),
        f_int32_2: Some(m.f_int32_2),
        f_string_2: Some(&m.f_string_2),
    };
    msg_core::direct::write_into(&v, b).map(|_| ())
}

fn encode_document(b: &mut DagrBuilder, d: &Document) -> Result<(), DagrError> {
    let meta = doc_core::direct::DocumentMeta {
        region: Some(&d.meta.region),
        version: Some(d.meta.version),
    };
    let items: Vec<doc_core::direct::DocumentItem> = d
        .items
        .iter()
        .map(|it| doc_core::direct::DocumentItem {
            sku: Some(&it.sku),
            qty: Some(it.qty),
            price_minor: Some(it.price_minor),
        })
        .collect();
    let v = doc_core::direct::Document {
        id: Some(&d.id),
        status: Some(d.status),
        meta: Some(&meta),
        items: &items,
    };
    doc_core::direct::write_into(&v, b).map(|_| ())
}

fn encode_telemetry(b: &mut DagrBuilder, t: &Telemetry) -> Result<(), DagrError> {
    let tags: Vec<&str> = t.tags.iter().map(String::as_str).collect();
    let v = tel_core::direct::Telemetry {
        source: Some(&t.source),
        ts: Some(t.ts),
        tags: &tags,
        values: &t.values,
    };
    tel_core::direct::write_into(&v, b).map(|_| ())
}

fn encode_strings(b: &mut DagrBuilder, st: &Strings) -> Result<(), DagrError> {
    let items: Vec<&str> = st.items.iter().map(String::as_str).collect();
    let v = str_core::direct::Strings { items: &items };
    str_core::direct::write_into(&v, b).map(|_| ())
}

fn encode_event(b: &mut DagrBuilder, e: &Event) -> Result<(), DagrError> {
    let attrs: Vec<ev_core::direct::EventAttr> = e
        .attrs
        .iter()
        .map(|a| ev_core::direct::EventAttr {
            key: Some(&a.key),
            value: Some(&a.value),
        })
        .collect();
    let v = ev_core::direct::Event {
        event_id: Some(&e.event_id),
        event_type: Some(&e.event_type),
        occurred_at: Some(e.occurred_at),
        producer: Some(&e.producer),
        attrs: &attrs,
    };
    ev_core::direct::write_into(&v, b).map(|_| ())
}

// ── decode (lazy reader → owned domain value) ───────────────────────────────

fn decode_message(data: &[u8]) -> Result<Fixture, DagrError> {
    let m = msg_lazy::read_root(data)?;
    Ok(Fixture::Message(Message {
        f_bool: m.f_bool().unwrap_or_default(),
        f_int32: m.f_int32().unwrap_or_default(),
        f_int64: m.f_int64().unwrap_or_default(),
        f_float64: m.f_float64().unwrap_or_default(),
        f_string: s(m.f_string()),
        f_bool_2: m.f_bool_2().unwrap_or_default(),
        f_int32_2: m.f_int32_2().unwrap_or_default(),
        f_string_2: s(m.f_string_2()),
    }))
}

fn decode_document(data: &[u8]) -> Result<Fixture, DagrError> {
    let d = doc_lazy::read_root(data)?;
    let meta = d.meta();
    Ok(Fixture::Document(Document {
        id: s(d.id()),
        status: d.status().unwrap_or_default(),
        meta: DocumentMeta {
            region: s(meta.as_ref().and_then(|m| m.region())),
            version: meta.as_ref().and_then(|m| m.version()).unwrap_or_default(),
        },
        items: d
            .items()?
            .iter()
            .map(|it| {
                it.map(|it| DocumentItem {
                    sku: s(it.sku()),
                    qty: it.qty().unwrap_or_default(),
                    price_minor: it.price_minor().unwrap_or_default(),
                })
            })
            .collect::<Result<_, _>>()?,
    }))
}

fn decode_telemetry(data: &[u8]) -> Result<Fixture, DagrError> {
    let t = tel_lazy::read_root(data)?;
    Ok(Fixture::Telemetry(Telemetry {
        source: s(t.source()),
        ts: t.ts().unwrap_or_default(),
        tags: t
            .tags()?
            .iter()
            .map(|r| r.map(str::to_owned))
            .collect::<Result<_, _>>()?,
        values: t.values()?.iter().collect::<Result<_, _>>()?,
    }))
}

fn decode_strings(data: &[u8]) -> Result<Fixture, DagrError> {
    let st = str_lazy::read_root(data)?;
    Ok(Fixture::Strings(Strings {
        items: st
            .items()?
            .iter()
            .map(|r| r.map(str::to_owned))
            .collect::<Result<_, _>>()?,
    }))
}

fn decode_event(data: &[u8]) -> Result<Fixture, DagrError> {
    let e = ev_lazy::read_root(data)?;
    Ok(Fixture::Event(Event {
        event_id: s(e.event_id()),
        event_type: s(e.event_type()),
        occurred_at: e.occurred_at().unwrap_or_default(),
        producer: s(e.producer()),
        attrs: e
            .attrs()?
            .iter()
            .map(|a| {
                a.map(|a| EventAttr {
                    key: s(a.key()),
                    value: s(a.value()),
                })
            })
            .collect::<Result<_, _>>()?,
    }))
}

// ── BenchSerializer ─────────────────────────────────────────────────────────

type EncodeFn = fn(&mut DagrBuilder, &Fixture) -> Result<(), DagrError>;
type DecodeFn = fn(&[u8]) -> Result<Fixture, DagrError>;

macro_rules! encode_fn {
    ($variant:ident, $f:ident) => {
        (|b: &mut DagrBuilder, fx: &Fixture| match fx {
            Fixture::$variant(v) => $f(b, v),
            _ => Err(DagrError::InvalidData),
        }) as EncodeFn
    };
}

pub struct DagrSer {
    builder: DagrBuilder,
    encode: EncodeFn,
    decode: DecodeFn,
}

impl Default for DagrSer {
    fn default() -> Self {
        Self {
            builder: DagrBuilder::with_capacity(4096),
            encode: encode_fn!(Message, encode_message),
            decode: decode_message,
        }
    }
}

impl BenchSerializer for DagrSer {
    fn name(&self) -> &'static str {
        "dagr"
    }
    fn version(&self) -> &'static str {
        // Generator version recorded in schemas/v2/dagr/dagr.lock.json (build.rs).
        env!("DAGR_VERSION")
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Direct
    }
    fn supports(&self, test_data_name: &str) -> bool {
        matches!(
            test_data_name,
            "message" | "document" | "telemetry" | "strings" | "event"
        )
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        let (encode, decode): (EncodeFn, DecodeFn) = match fixture {
            Fixture::Message(_) => (encode_fn!(Message, encode_message), decode_message),
            Fixture::Document(_) => (encode_fn!(Document, encode_document), decode_document),
            Fixture::Telemetry(_) => (encode_fn!(Telemetry, encode_telemetry), decode_telemetry),
            Fixture::Strings(_) => (encode_fn!(Strings, encode_strings), decode_strings),
            Fixture::Event(_) => (encode_fn!(Event, encode_event), decode_event),
        };
        self.encode = encode;
        self.decode = decode;
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let b = &mut self.builder;
        PackedSink::reset(b);
        (self.encode)(b, fixture).map_err(err)?;
        out.extend_from_slice(b.record_bytes());
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        (self.decode)(data).map_err(err)
    }
}
