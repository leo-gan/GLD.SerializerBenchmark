//! Dagr path: schemas/v2/dagr/schema.py → `dagr build` → rust/dagr_gen (crate `benchmark_v2`).
//!
//! One DataGraph per suite type, all nodes `packed`. Serialize uses the generated
//! **direct builder** (plain borrowed value structs → buffer, no arena) into one
//! `DagrBuilder` reused across calls; the bytes are copied into the harness buffer
//! because Dagr writes back-to-front. Deserialize uses the generated **lazy reader**
//! and materializes the owned domain value for the fidelity check (the decode + the
//! domain build are both timed, like prost's `decode` + `from_pb`).
//!
//! Like prost's generated messages, the direct builder's value structs are this codec's
//! native model: they are built from the suite values in `prepare_many` (untimed), and the
//! timed `serialize_into` only runs `write_into`.

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
//
// The direct builder's value structs are this codec's native model — the counterpart of
// prost's generated messages — so, like prost, they are built from the suite values in
// `prepare_many` (untimed) and the timed `serialize_into` only runs `write_into`.

use doc_core::direct as dd;
use ev_core::direct as ed;

/// Extend a borrow of `Prepared`'s own heap storage to `'static`.
///
/// SAFETY (for every use below): the target lives in a heap allocation owned by the same
/// `Prepared` (the boxed fixture copy, or a boxed side table) that is never mutated,
/// reallocated or dropped while `values` exists — `values` is declared first, so it drops
/// first, and nothing is pushed into a side table after a value borrows from it.
unsafe fn erase<T: ?Sized>(r: &T) -> &'static T {
    unsafe { &*(r as *const T) }
}

enum Values {
    None,
    Message(Vec<msg_core::direct::Message<'static>>),
    Document(Vec<dd::Document<'static>>),
    Telemetry(Vec<tel_core::direct::Telemetry<'static>>),
    Strings(Vec<str_core::direct::Strings<'static>>),
    Event(Vec<ed::Event<'static>>),
}

/// The prepared direct value structs of one cell and the storage they borrow from.
struct Prepared {
    values: Values,
    _metas: Vec<Box<dd::DocumentMeta<'static>>>,
    _items: Vec<Box<[dd::DocumentItem<'static>]>>,
    _attrs: Vec<Box<[ed::EventAttr<'static>]>>,
    _strs: Vec<Box<[&'static str]>>,
    _owner: Box<[Fixture]>,
}

impl Prepared {
    fn empty() -> Self {
        Self { values: Values::None, _metas: Vec::new(), _items: Vec::new(), _attrs: Vec::new(),
               _strs: Vec::new(), _owner: Box::new([]) }
    }

    fn build(fixtures: &[Fixture]) -> Result<Self> {
        let mut p = Self::empty();
        p._owner = fixtures.to_vec().into_boxed_slice();
        // SAFETY: see `erase` — `_owner` is not touched again once values borrow from it.
        let owner: &'static [Fixture] = unsafe { erase(&*p._owner) };
        let strs = |p: &mut Self, v: &'static [String]| -> &'static [&'static str] {
            p._strs.push(v.iter().map(String::as_str).collect());
            unsafe { erase(&**p._strs.last().unwrap()) }
        };
        let kind_err = || anyhow!("dagr: mixed fixture kinds in one cell");
        p.values = match owner.first() {
            None => Values::None,
            Some(Fixture::Message(_)) => Values::Message(owner.iter().map(|f| match f {
                Fixture::Message(m) => Ok(msg_core::direct::Message {
                    f_bool: Some(m.f_bool), f_int32: Some(m.f_int32), f_int64: Some(m.f_int64),
                    f_float64: Some(m.f_float64), f_string: Some(&m.f_string), f_bool_2: Some(m.f_bool_2),
                    f_int32_2: Some(m.f_int32_2), f_string_2: Some(&m.f_string_2),
                }),
                _ => Err(kind_err()),
            }).collect::<Result<_>>()?),
            Some(Fixture::Document(_)) => {
                let mut docs = Vec::with_capacity(owner.len());
                for f in owner {
                    let Fixture::Document(d) = f else { return Err(kind_err()) };
                    p._metas.push(Box::new(dd::DocumentMeta { region: Some(&d.meta.region), version: Some(d.meta.version) }));
                    p._items.push(d.items.iter().map(|it| dd::DocumentItem {
                        sku: Some(&it.sku), qty: Some(it.qty), price_minor: Some(it.price_minor) }).collect());
                    let meta = unsafe { erase(&**p._metas.last().unwrap()) };
                    let items = unsafe { erase(&**p._items.last().unwrap()) };
                    docs.push(dd::Document { id: Some(&d.id), status: Some(d.status), meta: Some(meta), items });
                }
                Values::Document(docs)
            }
            Some(Fixture::Telemetry(_)) => {
                let mut ts = Vec::with_capacity(owner.len());
                for f in owner {
                    let Fixture::Telemetry(t) = f else { return Err(kind_err()) };
                    let tags = strs(&mut p, &t.tags);
                    ts.push(tel_core::direct::Telemetry { source: Some(&t.source), ts: Some(t.ts), tags, values: &t.values });
                }
                Values::Telemetry(ts)
            }
            Some(Fixture::Strings(_)) => {
                let mut ss = Vec::with_capacity(owner.len());
                for f in owner {
                    let Fixture::Strings(st) = f else { return Err(kind_err()) };
                    ss.push(str_core::direct::Strings { items: strs(&mut p, &st.items) });
                }
                Values::Strings(ss)
            }
            Some(Fixture::Event(_)) => {
                let mut es = Vec::with_capacity(owner.len());
                for f in owner {
                    let Fixture::Event(e) = f else { return Err(kind_err()) };
                    p._attrs.push(e.attrs.iter().map(|a| ed::EventAttr { key: Some(&a.key), value: Some(&a.value) }).collect());
                    let attrs = unsafe { erase(&**p._attrs.last().unwrap()) };
                    es.push(ed::Event { event_id: Some(&e.event_id), event_type: Some(&e.event_type),
                        occurred_at: Some(e.occurred_at), producer: Some(&e.producer), attrs });
                }
                Values::Event(es)
            }
        };
        Ok(p)
    }

    /// Timed: store prepared value `i` into `b` (the direct builder's `write_into`).
    #[inline]
    fn write(&self, i: usize, b: &mut DagrBuilder) -> Result<(), DagrError> {
        let missing = DagrError::InvalidData;
        match &self.values {
            Values::Message(v) => msg_core::direct::write_into(v.get(i).ok_or(missing)?, b),
            Values::Document(v) => doc_core::direct::write_into(v.get(i).ok_or(missing)?, b),
            Values::Telemetry(v) => tel_core::direct::write_into(v.get(i).ok_or(missing)?, b),
            Values::Strings(v) => str_core::direct::write_into(v.get(i).ok_or(missing)?, b),
            Values::Event(v) => ev_core::direct::write_into(v.get(i).ok_or(missing)?, b),
            Values::None => Err(missing),
        }
        .map(|_| ())
    }
}

// ── decode (lazy reader → owned domain value) ───────────────────────────────

/// `collect::<Result<Vec<_>, _>>()` can't see the array's length (the `Result` adapter
/// hides the size hint), so the Vec grows 4 → 8 → …; pre-size it from the accessor's `len()`.
fn collect_exact<T, E>(len: usize, it: impl Iterator<Item = Result<T, E>>) -> Result<Vec<T>, E> {
    let mut v = Vec::with_capacity(len);
    for x in it {
        v.push(x?);
    }
    Ok(v)
}

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
        items: {
            let arr = d.items()?;
            collect_exact(
                arr.len(),
                arr.iter().map(|it| {
                    it.map(|it| DocumentItem {
                        sku: s(it.sku()),
                        qty: it.qty().unwrap_or_default(),
                        price_minor: it.price_minor().unwrap_or_default(),
                    })
                }),
            )?
        },
    }))
}

fn decode_telemetry(data: &[u8]) -> Result<Fixture, DagrError> {
    let t = tel_lazy::read_root(data)?;
    Ok(Fixture::Telemetry(Telemetry {
        source: s(t.source()),
        ts: t.ts().unwrap_or_default(),
        tags: {
            let arr = t.tags()?;
            collect_exact(arr.len(), arr.iter().map(|r| r.map(str::to_owned)))?
        },
        values: {
            let arr = t.values()?;
            collect_exact(arr.len(), arr.iter())?
        },
    }))
}

fn decode_strings(data: &[u8]) -> Result<Fixture, DagrError> {
    let st = str_lazy::read_root(data)?;
    Ok(Fixture::Strings(Strings {
        items: {
            let arr = st.items()?;
            collect_exact(arr.len(), arr.iter().map(|r| r.map(str::to_owned)))?
        },
    }))
}

fn decode_event(data: &[u8]) -> Result<Fixture, DagrError> {
    let e = ev_lazy::read_root(data)?;
    Ok(Fixture::Event(Event {
        event_id: s(e.event_id()),
        event_type: s(e.event_type()),
        occurred_at: e.occurred_at().unwrap_or_default(),
        producer: s(e.producer()),
        attrs: {
            let arr = e.attrs()?;
            collect_exact(
                arr.len(),
                arr.iter().map(|a| {
                    a.map(|a| EventAttr {
                        key: s(a.key()),
                        value: s(a.value()),
                    })
                }),
            )?
        },
    }))
}

// ── BenchSerializer ─────────────────────────────────────────────────────────

type DecodeFn = fn(&[u8]) -> Result<Fixture, DagrError>;

pub struct DagrSer {
    builder: DagrBuilder,
    prepared: Prepared,
    enc_i: usize,
    decode: DecodeFn,
}

impl Default for DagrSer {
    fn default() -> Self {
        Self {
            builder: DagrBuilder::with_capacity(4096),
            prepared: Prepared::empty(),
            enc_i: 0,
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
        self.prepare_many(std::slice::from_ref(fixture))
    }
    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        let first = fixtures.first().ok_or_else(|| anyhow!("dagr: empty cell"))?;
        self.decode = match first {
            Fixture::Message(_) => decode_message,
            Fixture::Document(_) => decode_document,
            Fixture::Telemetry(_) => decode_telemetry,
            Fixture::Strings(_) => decode_strings,
            Fixture::Event(_) => decode_event,
        };
        self.prepared = Prepared::build(fixtures)?;
        self.enc_i = 0;
        Ok(())
    }
    fn begin_cell_encode(&mut self) {
        self.enc_i = 0;
    }
    fn serialize_into(&mut self, _fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let i = self.enc_i;
        self.enc_i += 1;
        let b = &mut self.builder;
        PackedSink::reset(b);
        self.prepared.write(i, b).map_err(err)?;
        out.extend_from_slice(b.record_bytes());
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        (self.decode)(data).map_err(err)
    }
}
