//! Dagr path: schemas/v2/dagr/schema.py → `dagr build` → rust/dagr_gen (crate `dagr_benchmark_v2`).
//!
//! The schema emits every suite type in four node layouts (Dagr `spec/16-choosing-a-node-layout.md`),
//! one DataGraph each, so there are four rows:
//!
//! | row                  | graphs                       | native model (built in `prepare_many`) |
//! |----------------------|------------------------------|----------------------------------------|
//! | `dagr-packed`        | `MessageGraph`, …            | direct-builder value structs (packed)  |
//! | `dagr-regular`       | `MessageRegularGraph`, …     | generated arena (vtable nodes)         |
//! | `dagr-frozen`        | `MessageFrozenGraph`, …      | generated arena (frozen nodes)         |
//! | `dagr-frozen-packed` | `MessageFrozenPackedGraph`, …| direct-builder value structs           |
//!
//! Like prost's generated messages, the native model is built from the suite values in
//! `prepare_many` (untimed); the timed `serialize_into` only encodes the i-th prepared value
//! (`begin_cell_encode` / `enc_i`) into one reused `DagrBuilder` and copies the record into
//! `out` (Dagr writes back-to-front). Packed layouts have a **direct builder**
//! (`<graph>_core::direct::write_into`); regular and frozen layouts have none, so their timed
//! encode is the generated **arena serializer** (`root.store` + the root framing — the body of
//! the arena's `to_bytes`, into the reused builder instead of a fresh one).
//!
//! Deserialize uses the generated **lazy reader** and materializes the owned domain value for
//! the fidelity check (decode + domain build both timed, like prost's `decode` + `from_pb`).
//! The layouts' lazy getters differ in shape (`Option<T>`, `Result<T>`, `Result<Option<T>>`),
//! so one decoder body per suite type is shared through three tiny per-layout adapters.
//!
//! `graph` (shared regions and a person ring) is only the regular and frozen arenas. Packed
//! layouts inline a reference, so `dagr-packed` and `dagr-frozen-packed` do not support it.

use crate::data::{
    Book, Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, Message, Order, Person,
    Region, Strings, Telemetry,
};
use anyhow::{anyhow, Result};
use dagr_benchmark_v2::dagr_runtime::{DagrBuilder, DagrError, PackedSink};
use std::marker::PhantomData;

use super::{BenchSerializer, NativeKind};

fn err(e: DagrError) -> anyhow::Error {
    anyhow!("dagr: {e:?}")
}

fn kind_err() -> anyhow::Error {
    anyhow!("dagr: mixed fixture kinds in one cell")
}

/// The columnar fixtures (`table`, `nested_table`, `signal`, …) have no Dagr schema;
/// `supports` keeps them out, so reaching one is a harness error.
fn unsupported_kind() -> anyhow::Error {
    anyhow!("dagr: fixture kind not in the Dagr schema")
}

fn decode_unsupported(_: &[u8]) -> Result<Fixture, DagrError> {
    Err(DagrError::InvalidData)
}

/// Extend a borrow of a `Prepared`'s own heap storage to `'static`.
///
/// SAFETY (for every use below): the target lives in a heap allocation owned by the same
/// `Prepared` (the boxed fixture copy, a boxed side table, or the boxed arena) that is never
/// reallocated or dropped while the values borrowing it exist — the borrowing field is declared
/// first, so it drops first, and nothing is pushed into a side table after a value borrows
/// from it.
unsafe fn erase<T: ?Sized>(r: &T) -> &'static T {
    unsafe { &*(r as *const T) }
}

/// `collect::<Result<Vec<_>, _>>()` can't see the array's length (the `Result` adapter
/// hides the size hint), so the Vec grows 4 → 8 → …; pre-size it from the accessor's `len()`.
fn collect_exact<T, E>(len: usize, it: impl Iterator<Item = Result<T, E>>) -> Result<Vec<T>, E> {
    let mut v = Vec::with_capacity(len);
    for x in it {
        v.push(x?);
    }
    Ok(v)
}

type DecodeFn = fn(&[u8]) -> Result<Fixture, DagrError>;

/// A cell's prepared native model: untimed `build`, timed `write`.
trait Cell: Sized + Send {
    fn empty() -> Self;
    fn build(fixtures: &[Fixture]) -> Result<Self>;
    /// Timed: store prepared value `i` into the (reset) builder `b`, root framing included.
    fn write(&self, i: usize, b: &mut DagrBuilder) -> Result<(), DagrError>;
}

// ── encode, packed layouts (direct builder) ─────────────────────────────────
//
// The direct builder's value structs are this codec's native model — the counterpart of
// prost's generated messages.

macro_rules! direct_cell {
    ($m:ident: $msg:ident, $doc:ident, $tel:ident, $str:ident, $ev:ident) => {
        mod $m {
            use super::*;
            use dagr_benchmark_v2::$doc::direct as dd;
            use dagr_benchmark_v2::$ev::direct as ed;
            use dagr_benchmark_v2::{$msg as msg_core, $str as str_core, $tel as tel_core};

            enum Values {
                None,
                Message(Vec<msg_core::direct::Message<'static>>),
                Document(Vec<dd::Document<'static>>),
                Telemetry(Vec<tel_core::direct::Telemetry<'static>>),
                Strings(Vec<str_core::direct::Strings<'static>>),
                Event(Vec<ed::Event<'static>>),
            }

            /// The prepared direct value structs of one cell and the storage they borrow from.
            pub struct Prepared {
                values: Values,
                _metas: Vec<Box<dd::DocumentMeta<'static>>>,
                _items: Vec<Box<[dd::DocumentItem<'static>]>>,
                _attrs: Vec<Box<[ed::EventAttr<'static>]>>,
                _strs: Vec<Box<[&'static str]>>,
                _owner: Box<[Fixture]>,
            }

            impl Cell for Prepared {
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
                        Some(_) => return Err(unsupported_kind()),
                    };
                    Ok(p)
                }

                /// Timed: the direct builder's `write_into`.
                #[inline]
                fn write(&self, i: usize, b: &mut DagrBuilder) -> Result<(), DagrError> {
                    let missing = DagrError::InvalidData;
                    match &self.values {
                        Values::Message(v) => msg_core::direct::write_into(v.get(i).ok_or(missing)?, b),
                        Values::Document(v) => dd::write_into(v.get(i).ok_or(missing)?, b),
                        Values::Telemetry(v) => tel_core::direct::write_into(v.get(i).ok_or(missing)?, b),
                        Values::Strings(v) => str_core::direct::write_into(v.get(i).ok_or(missing)?, b),
                        Values::Event(v) => ed::write_into(v.get(i).ok_or(missing)?, b),
                        Values::None => Err(missing),
                    }
                    .map(|_| ())
                }
            }
        }
    };
}

direct_cell!(packed_cell: message_graph_core, document_graph_core, telemetry_graph_core,
             strings_graph_core, event_graph_core);
direct_cell!(frozen_packed_cell: message_frozen_packed_graph_core, document_frozen_packed_graph_core,
             telemetry_frozen_packed_graph_core, strings_frozen_packed_graph_core,
             event_frozen_packed_graph_core);

// ── encode, regular / frozen layouts (generated arena) ─────────────────────
//
// These layouts have no direct builder: the generated arena is the native model. One arena
// per cell holds all N instances (one root handle each); the timed path stores one root —
// the body of the arena's `to_bytes` (`root.store` + root framing), but into the reused
// builder rather than a fresh `DagrBuilder::with_hint` per call. Both builders use the
// default 2 MiB `max_size` (same pointer width), so the bytes are identical — checked
// against `to_bytes` by the tests at the bottom of this file.

macro_rules! arena_cell {
    ($m:ident:
     $msg:ident($MA:ident, $MG:ident), $doc:ident($DA:ident, $DG:ident),
     $tel:ident($TA:ident, $TG:ident), $str:ident($SA:ident, $SG:ident),
     $ev:ident($EA:ident, $EG:ident),
     $gra:ident($GA:ident, $GG:ident)) => {
        mod $m {
            use super::*;
            use dagr_benchmark_v2::dagr_runtime::NodeStoreRef;
            use dagr_benchmark_v2::{$doc as doc, $ev as ev, $gra as graph, $msg as msg, $str as strs, $tel as tel};
            // The graph traits carry the `new_<node>` constructors.
            use dagr_benchmark_v2::{$doc::$DG as _, $ev::$EG as _, $gra::$GG as _, $msg::$MG as _, $str::$SG as _, $tel::$TG as _};
            use std::rc::Rc;

            type MsgArena = msg::$MA<0>;
            type DocArena = doc::$DA<0>;
            type TelArena = tel::$TA<0>;
            type StrArena = strs::$SA<0>;
            type EvArena = ev::$EA<0>;
            type GraphArena = graph::$GA<0>;

            /// Root handles (Copy, no Drop) into the boxed arena, one per instance of the cell.
            enum Roots {
                None,
                Message(Vec<msg::Message<'static, MsgArena>>),
                Document(Vec<doc::Document<'static, DocArena>>),
                Telemetry(Vec<tel::Telemetry<'static, TelArena>>),
                Strings(Vec<strs::Strings<'static, StrArena>>),
                Event(Vec<ev::Event<'static, EvArena>>),
                Graph(Vec<graph::Book<'static, GraphArena>>),
            }

            enum Arena {
                None,
                Message(Box<MsgArena>),
                Document(Box<DocArena>),
                Telemetry(Box<TelArena>),
                Strings(Box<StrArena>),
                Event(Box<EvArena>),
                Graph(Box<GraphArena>),
            }

            pub struct Prepared {
                roots: Roots,
                arena: Arena,
            }

            // SAFETY: the arena (RefCell-based, hence !Send) and the handles into it are owned
            // together by one `Prepared` and only touched through `&self`/`&mut self` of it,
            // i.e. by whichever single thread owns the serializer.
            unsafe impl Send for Prepared {}

            /// Box a fresh arena into `p.arena` and hand out a `'static` borrow of it.
            macro_rules! new_arena {
                ($p:ident, $variant:ident, $ty:ty) => {{
                    $p.arena = Arena::$variant(Box::new(<$ty>::new()));
                    let Arena::$variant(a) = &$p.arena else { unreachable!() };
                    // SAFETY: see `erase` — the boxed arena lives exactly as long as `roots`.
                    let a: &'static $ty = unsafe { erase(&**a) };
                    a
                }};
            }

            /// The arena `to_bytes` root framing, after `root.store(b)`.
            #[inline]
            fn frame(r: NodeStoreRef, b: &mut DagrBuilder) {
                let root_off = r.to_offset().unwrap_or(0);
                b.store_leb(((b.cursor() - root_off) as u64) << 2);
            }

            impl Cell for Prepared {
                fn empty() -> Self {
                    Self { roots: Roots::None, arena: Arena::None }
                }

                fn build(fixtures: &[Fixture]) -> Result<Self> {
                    let mut p = Self::empty();
                    p.roots = match fixtures.first() {
                        None => Roots::None,
                        Some(Fixture::Message(_)) => {
                            let a = new_arena!(p, Message, MsgArena);
                            Roots::Message(fixtures.iter().map(|f| match f {
                                Fixture::Message(m) => Ok(a.new_message(
                                    Some(m.f_bool), Some(m.f_int32), Some(m.f_int64), Some(m.f_float64),
                                    Some(&m.f_string), Some(m.f_bool_2), Some(m.f_int32_2), Some(&m.f_string_2))),
                                _ => Err(kind_err()),
                            }).collect::<Result<_>>()?)
                        }
                        Some(Fixture::Document(_)) => {
                            let a = new_arena!(p, Document, DocArena);
                            Roots::Document(fixtures.iter().map(|f| match f {
                                Fixture::Document(d) => {
                                    let meta = a.new_document_meta(Some(&d.meta.region), Some(d.meta.version));
                                    let items: Vec<_> = d.items.iter()
                                        .map(|it| a.new_document_item(Some(&it.sku), Some(it.qty), Some(it.price_minor)))
                                        .collect();
                                    Ok(a.new_document(Some(&d.id), Some(d.status), Some(meta), &items))
                                }
                                _ => Err(kind_err()),
                            }).collect::<Result<_>>()?)
                        }
                        Some(Fixture::Telemetry(_)) => {
                            let a = new_arena!(p, Telemetry, TelArena);
                            Roots::Telemetry(fixtures.iter().map(|f| match f {
                                Fixture::Telemetry(t) => Ok(a.new_telemetry(
                                    Some(&t.source), Some(t.ts), t.tags.clone(), t.values.clone())),
                                _ => Err(kind_err()),
                            }).collect::<Result<_>>()?)
                        }
                        Some(Fixture::Strings(_)) => {
                            let a = new_arena!(p, Strings, StrArena);
                            Roots::Strings(fixtures.iter().map(|f| match f {
                                Fixture::Strings(st) => Ok(a.new_strings(st.items.clone())),
                                _ => Err(kind_err()),
                            }).collect::<Result<_>>()?)
                        }
                        Some(Fixture::Event(_)) => {
                            let a = new_arena!(p, Event, EvArena);
                            Roots::Event(fixtures.iter().map(|f| match f {
                                Fixture::Event(e) => {
                                    let attrs: Vec<_> = e.attrs.iter()
                                        .map(|at| a.new_event_attr(Some(&at.key), Some(&at.value)))
                                        .collect();
                                    Ok(a.new_event(Some(&e.event_id), Some(&e.event_type), Some(e.occurred_at),
                                                   Some(&e.producer), &attrs))
                                }
                                _ => Err(kind_err()),
                            }).collect::<Result<_>>()?)
                        }
                        Some(Fixture::Graph(_)) => {
                            let a = new_arena!(p, Graph, GraphArena);
                            Roots::Graph(fixtures.iter().map(|f| {
                                let Fixture::Graph(book) = f else { return Err(kind_err()) };
                                // One arena region per shared Rc. Do not new_region per order.
                                let mut region_of: Vec<(usize, graph::Region<'static, GraphArena>)> = Vec::new();
                                let mut orders = Vec::with_capacity(book.orders.len());
                                for order in &book.orders {
                                    let key = Rc::as_ptr(&order.region) as usize;
                                    let region = if let Some(pos) = region_of.iter().position(|(k, _)| *k == key) {
                                        region_of[pos].1
                                    } else {
                                        let h = a.new_region(
                                            Some(order.region.code.as_str()),
                                            Some(order.region.note.as_str()),
                                            Some(order.region.version),
                                        );
                                        region_of.push((key, h));
                                        h
                                    };
                                    orders.push(a.new_order(Some(order.sku.as_str()), Some(order.qty), Some(region)));
                                }
                                let mut person_of: Vec<(usize, graph::Person<'static, GraphArena>)> = Vec::new();
                                let mut people = Vec::with_capacity(book.people.len());
                                for person in &book.people {
                                    let key = Rc::as_ptr(person) as usize;
                                    let h = if let Some(pos) = person_of.iter().position(|(k, _)| *k == key) {
                                        person_of[pos].1
                                    } else {
                                        let h = a.new_person(Some(person.name.as_str()), None);
                                        person_of.push((key, h));
                                        h
                                    };
                                    people.push(h);
                                }
                                for person in &book.people {
                                    let key = Rc::as_ptr(person) as usize;
                                    let h = person_of.iter().find(|(k, _)| *k == key).map(|(_, h)| *h)
                                        .ok_or_else(|| anyhow::anyhow!("dagr: missing person"))?;
                                    let next_key = person.next.borrow().as_ref().map(|n| Rc::as_ptr(n) as usize);
                                    let next = match next_key {
                                        None => None,
                                        Some(nk) => Some(
                                            person_of.iter().find(|(k, _)| *k == nk).map(|(_, h)| *h)
                                                .ok_or_else(|| anyhow::anyhow!("dagr: person.next leaves the book"))?,
                                        ),
                                    };
                                    h.set_next(next);
                                }
                                Ok(a.new_book(&orders, &people))
                            }).collect::<Result<_>>()?)
                        }
                        Some(_) => return Err(unsupported_kind()),
                    };
                    Ok(p)
                }

                /// Timed: the arena serializer for root `i`.
                #[inline]
                fn write(&self, i: usize, b: &mut DagrBuilder) -> Result<(), DagrError> {
                    let missing = DagrError::InvalidData;
                    let r = match &self.roots {
                        Roots::Message(v) => v.get(i).ok_or(missing)?.store(b)?,
                        Roots::Document(v) => v.get(i).ok_or(missing)?.store(b)?,
                        Roots::Telemetry(v) => v.get(i).ok_or(missing)?.store(b)?,
                        Roots::Strings(v) => v.get(i).ok_or(missing)?.store(b)?,
                        Roots::Event(v) => v.get(i).ok_or(missing)?.store(b)?,
                        Roots::Graph(v) => v.get(i).ok_or(missing)?.store(b)?,
                        Roots::None => return Err(missing),
                    };
                    frame(r, b);
                    Ok(())
                }
            }

            /// Test hook: the arena's own `to_bytes` with root `i` (fresh builder per call).
            #[cfg(test)]
            pub(super) fn arena_to_bytes(p: &Prepared, i: usize) -> Result<Vec<u8>, DagrError> {
                match (&p.arena, &p.roots) {
                    (Arena::Message(a), Roots::Message(v)) => { a.set_root(Some(v[i])); a.to_bytes() }
                    (Arena::Document(a), Roots::Document(v)) => { a.set_root(Some(v[i])); a.to_bytes() }
                    (Arena::Telemetry(a), Roots::Telemetry(v)) => { a.set_root(Some(v[i])); a.to_bytes() }
                    (Arena::Strings(a), Roots::Strings(v)) => { a.set_root(Some(v[i])); a.to_bytes() }
                    (Arena::Event(a), Roots::Event(v)) => { a.set_root(Some(v[i])); a.to_bytes() }
                    (Arena::Graph(a), Roots::Graph(v)) => { a.set_root(Some(v[i])); a.to_bytes() }
                    _ => Err(DagrError::InvalidData),
                }
            }
        }
    };
}

arena_cell!(regular_cell:
    message_regular_graph(MessageRegularGraphArena, MessageRegularGraphGraph),
    document_regular_graph(DocumentRegularGraphArena, DocumentRegularGraphGraph),
    telemetry_regular_graph(TelemetryRegularGraphArena, TelemetryRegularGraphGraph),
    strings_regular_graph(StringsRegularGraphArena, StringsRegularGraphGraph),
    event_regular_graph(EventRegularGraphArena, EventRegularGraphGraph),
    graph_regular_graph(GraphRegularGraphArena, GraphRegularGraphGraph));
arena_cell!(frozen_cell:
    message_frozen_graph(MessageFrozenGraphArena, MessageFrozenGraphGraph),
    document_frozen_graph(DocumentFrozenGraphArena, DocumentFrozenGraphGraph),
    telemetry_frozen_graph(TelemetryFrozenGraphArena, TelemetryFrozenGraphGraph),
    strings_frozen_graph(StringsFrozenGraphArena, StringsFrozenGraphGraph),
    event_frozen_graph(EventFrozenGraphArena, EventFrozenGraphGraph),
    graph_frozen_graph(GraphFrozenGraphArena, GraphFrozenGraphGraph));

// ── decode (lazy reader → owned domain value) ───────────────────────────────
//
// Per layout, the lazy getters return:
//
// | layout        | scalar                 | string                        | node ref                |
// |---------------|------------------------|-------------------------------|-------------------------|
// | packed        | `Option<T>`            | `Option<&str>`                | `Option<Acc>`           |
// | regular       | `Result<Option<T>>`    | `Result<Option<&str>>`        | `Result<Option<Acc>>`   |
// | frozen        | `Result<T>`            | `Result<Option<&str>>`        | `Result<Option<Acc>>`   |
// | frozen-packed | `Result<T>`            | `Option<&str>`                | `Option<Acc>`           |
//
// (frozen scalars have no absent state on the read side: an absent one is `InvalidData`.)
// Arrays are `Result<Array>` with `len()` + `iter()` of `Result<T>` everywhere.
// `sc` / `st` / `nd` normalize those to `Result<T>` / `Result<String>` / `Result<Option<Acc>>`.

mod adapt {
    use dagr_benchmark_v2::dagr_runtime::DagrError;
    type R<T> = Result<T, DagrError>;

    pub mod packed {
        use super::R;
        #[inline] pub fn sc<T: Default>(v: Option<T>) -> R<T> { Ok(v.unwrap_or_default()) }
        #[inline] pub fn st(v: Option<&str>) -> R<String> { Ok(v.unwrap_or_default().to_owned()) }
        #[inline] pub fn nd<A>(v: Option<A>) -> R<Option<A>> { Ok(v) }
    }
    pub mod regular {
        use super::R;
        #[inline] pub fn sc<T: Default>(v: R<Option<T>>) -> R<T> { v.map(Option::unwrap_or_default) }
        #[inline] pub fn st(v: R<Option<&str>>) -> R<String> { v.map(|s| s.unwrap_or_default().to_owned()) }
        #[inline] pub fn nd<A>(v: R<Option<A>>) -> R<Option<A>> { v }
    }
    pub mod frozen {
        use super::R;
        #[inline] pub fn sc<T>(v: R<T>) -> R<T> { v }
        pub use super::regular::{nd, st};
    }
    pub mod frozen_packed {
        use super::R;
        #[inline] pub fn sc<T>(v: R<T>) -> R<T> { v }
        pub use super::packed::{nd, st};
    }
}

/// Element count of a node-ref array accessor, to pre-size the Vec. The vtable-layout
/// accessors (`<Node>ArrayAccessor`) have no `len()`, only a `pub count` field; the packed
/// ones (`<Node>PackedNodeArray`) have `len()` but a private `count`.
trait NodeArrLen {
    fn n(&self) -> usize;
}

macro_rules! node_arr_len {
    (count: $($c:ty),*; len: $($l:ty),*) => {
        $(impl NodeArrLen for $c { #[inline] fn n(&self) -> usize { self.count } })*
        $(impl NodeArrLen for $l { #[inline] fn n(&self) -> usize { self.len() } })*
    };
}

node_arr_len!(
    count: dagr_benchmark_v2::document_regular_graph_lazy::DocumentItemArrayAccessor<'_>,
           dagr_benchmark_v2::event_regular_graph_lazy::EventAttrArrayAccessor<'_>,
           dagr_benchmark_v2::document_frozen_graph_lazy::DocumentItemArrayAccessor<'_>,
           dagr_benchmark_v2::event_frozen_graph_lazy::EventAttrArrayAccessor<'_>;
    len: dagr_benchmark_v2::document_graph_lazy::DocumentItemPackedNodeArray<'_>,
         dagr_benchmark_v2::event_graph_lazy::EventAttrPackedNodeArray<'_>,
         dagr_benchmark_v2::document_frozen_packed_graph_lazy::DocumentItemPackedNodeArray<'_>,
         dagr_benchmark_v2::event_frozen_packed_graph_lazy::EventAttrPackedNodeArray<'_>
);

macro_rules! lazy_decoders {
    ($m:ident($adapt:ident): $msg:ident, $doc:ident, $tel:ident, $str:ident, $ev:ident $(, graph: $graph:ident)?) => {
        mod $m {
            use super::adapt::$adapt::{nd, sc, st};
            use super::*;
            use dagr_benchmark_v2::{$doc as doc_lazy, $ev as ev_lazy, $msg as msg_lazy, $str as str_lazy, $tel as tel_lazy};

            fn decode_message(data: &[u8]) -> Result<Fixture, DagrError> {
                let m = msg_lazy::read_root(data)?;
                Ok(Fixture::Message(Message {
                    f_bool: sc(m.f_bool())?,
                    f_int32: sc(m.f_int32())?,
                    f_int64: sc(m.f_int64())?,
                    f_float64: sc(m.f_float64())?,
                    f_string: st(m.f_string())?,
                    f_bool_2: sc(m.f_bool_2())?,
                    f_int32_2: sc(m.f_int32_2())?,
                    f_string_2: st(m.f_string_2())?,
                }))
            }

            fn decode_document(data: &[u8]) -> Result<Fixture, DagrError> {
                let d = doc_lazy::read_root(data)?;
                let meta = match nd(d.meta())? {
                    Some(m) => DocumentMeta { region: st(m.region())?, version: sc(m.version())? },
                    None => DocumentMeta { region: String::new(), version: 0 },
                };
                Ok(Fixture::Document(Document {
                    id: st(d.id())?,
                    status: sc(d.status())?,
                    meta,
                    items: {
                        let arr = d.items()?;
                        collect_exact(
                            arr.n(),
                            arr.iter().map(|it| {
                                let it = it?;
                                Ok(DocumentItem {
                                    sku: st(it.sku())?,
                                    qty: sc(it.qty())?,
                                    price_minor: sc(it.price_minor())?,
                                })
                            }),
                        )?
                    },
                }))
            }

            fn decode_telemetry(data: &[u8]) -> Result<Fixture, DagrError> {
                let t = tel_lazy::read_root(data)?;
                Ok(Fixture::Telemetry(Telemetry {
                    source: st(t.source())?,
                    ts: sc(t.ts())?,
                    tags: {
                        let arr = t.tags()?;
                        collect_exact(arr.len(), arr.iter().map(|r| r.map(str::to_owned)))?
                    },
                    // one block copy: `values` is `raw` (Dagr spec/43)
                    values: t.values()?.to_vec()?,
                }))
            }

            fn decode_strings(data: &[u8]) -> Result<Fixture, DagrError> {
                let s = str_lazy::read_root(data)?;
                Ok(Fixture::Strings(Strings {
                    items: {
                        let arr = s.items()?;
                        collect_exact(arr.len(), arr.iter().map(|r| r.map(str::to_owned)))?
                    },
                }))
            }

            fn decode_event(data: &[u8]) -> Result<Fixture, DagrError> {
                let e = ev_lazy::read_root(data)?;
                Ok(Fixture::Event(Event {
                    event_id: st(e.event_id())?,
                    event_type: st(e.event_type())?,
                    occurred_at: sc(e.occurred_at())?,
                    producer: st(e.producer())?,
                    attrs: {
                        let arr = e.attrs()?;
                        collect_exact(
                            arr.n(),
                            arr.iter().map(|a| {
                                let a = a?;
                                Ok(EventAttr { key: st(a.key())?, value: st(a.value())? })
                            }),
                        )?
                    },
                }))
            }

            $(
            fn decode_graph(data: &[u8]) -> Result<Fixture, DagrError> {
                use dagr_benchmark_v2::$graph as graph_lazy;
                use std::cell::RefCell;
                use std::rc::Rc;

                struct Seen {
                    start: usize,
                    name: String,
                    next: Option<usize>,
                }

                let root = graph_lazy::read_root(data)?;
                let orders_acc = root.orders()?;
                let mut regions: Vec<(usize, Rc<Region>)> = Vec::new();
                let mut orders = Vec::with_capacity(orders_acc.count);
                for it in orders_acc.iter() {
                    let it = it?;
                    let reg = nd(it.region())?.ok_or(DagrError::InvalidData)?;
                    let key = reg._start();
                    let region = if let Some(pos) = regions.iter().position(|(k, _)| *k == key) {
                        Rc::clone(&regions[pos].1)
                    } else {
                        let region = Rc::new(Region {
                            code: st(reg.code())?,
                            note: st(reg.note())?,
                            version: sc(reg.version())?,
                        });
                        regions.push((key, Rc::clone(&region)));
                        region
                    };
                    orders.push(Order {
                        sku: st(it.sku())?,
                        qty: sc(it.qty())?,
                        region,
                    });
                }

                let people_acc = root.people()?;
                let mut seen = Vec::with_capacity(people_acc.count);
                for it in people_acc.iter() {
                    let acc = it?;
                    let next = match nd(acc.next())? {
                        Some(n) => Some(n._start()),
                        None => None,
                    };
                    seen.push(Seen { start: acc._start(), name: st(acc.name())?, next });
                }
                let mut shells: Vec<(usize, Rc<Person>)> = Vec::with_capacity(seen.len());
                for row in &seen {
                    if shells.iter().any(|(k, _)| *k == row.start) {
                        continue;
                    }
                    shells.push((
                        row.start,
                        Rc::new(Person {
                            name: row.name.clone(),
                            next: RefCell::new(None),
                        }),
                    ));
                }
                for row in &seen {
                    let Some(next_key) = row.next else { continue };
                    let person = match shells.iter().find(|(k, _)| *k == row.start) {
                        Some((_, p)) => Rc::clone(p),
                        None => return Err(DagrError::InvalidData),
                    };
                    let next = match shells.iter().find(|(k, _)| *k == next_key) {
                        Some((_, p)) => Rc::clone(p),
                        None => return Err(DagrError::InvalidData),
                    };
                    *person.next.borrow_mut() = Some(next);
                }
                let mut people = Vec::with_capacity(seen.len());
                for row in &seen {
                    let person = match shells.iter().find(|(k, _)| *k == row.start) {
                        Some((_, p)) => Rc::clone(p),
                        None => return Err(DagrError::InvalidData),
                    };
                    people.push(person);
                }
                Ok(Fixture::Graph(Book { orders, people }))
            }
            )?

            fn graph_decoder() -> DecodeFn {
                // `stringify!($graph)` keeps this repetition tied to the optional graph module.
                $(
                if !stringify!($graph).is_empty() {
                    return decode_graph;
                }
                )?
                decode_unsupported
            }

            /// Bind the monomorphic decoder for the cell's fixture kind (untimed).
            pub fn decoder(first: &Fixture) -> DecodeFn {
                match first {
                    Fixture::Message(_) => decode_message,
                    Fixture::Document(_) => decode_document,
                    Fixture::Telemetry(_) => decode_telemetry,
                    Fixture::Strings(_) => decode_strings,
                    Fixture::Event(_) => decode_event,
                    Fixture::Graph(_) => graph_decoder(),
                    _ => decode_unsupported,
                }
            }
        }
    };
}

lazy_decoders!(packed_dec(packed): message_graph_lazy, document_graph_lazy,
               telemetry_graph_lazy, strings_graph_lazy, event_graph_lazy);
lazy_decoders!(regular_dec(regular): message_regular_graph_lazy, document_regular_graph_lazy,
               telemetry_regular_graph_lazy, strings_regular_graph_lazy, event_regular_graph_lazy,
               graph: graph_regular_graph_lazy);
lazy_decoders!(frozen_dec(frozen): message_frozen_graph_lazy, document_frozen_graph_lazy,
               telemetry_frozen_graph_lazy, strings_frozen_graph_lazy, event_frozen_graph_lazy,
               graph: graph_frozen_graph_lazy);
lazy_decoders!(frozen_packed_dec(frozen_packed): message_frozen_packed_graph_lazy,
               document_frozen_packed_graph_lazy, telemetry_frozen_packed_graph_lazy,
               strings_frozen_packed_graph_lazy, event_frozen_packed_graph_lazy);

// ── layouts / rows ──────────────────────────────────────────────────────────

/// One node layout = one row.
pub trait Layout: Send {
    const NAME: &'static str;
    const KIND: NativeKind;
    const GRAPH: bool;
    #[allow(private_bounds)]
    type Prepared: Cell;
    fn decoder(first: &Fixture) -> DecodeFn;
}

macro_rules! layout {
    ($ty:ident, $name:literal, $kind:ident, $cell:ident, $dec:ident, $graph:expr) => {
        pub struct $ty;
        impl Layout for $ty {
            const NAME: &'static str = $name;
            const KIND: NativeKind = NativeKind::$kind;
            const GRAPH: bool = $graph;
            type Prepared = $cell::Prepared;
            fn decoder(first: &Fixture) -> DecodeFn {
                $dec::decoder(first)
            }
        }
    };
}

layout!(Packed, "dagr-packed", Direct, packed_cell, packed_dec, false);
layout!(Regular, "dagr-regular", Message, regular_cell, regular_dec, true);
layout!(Frozen, "dagr-frozen", Message, frozen_cell, frozen_dec, true);
layout!(FrozenPacked, "dagr-frozen-packed", Direct, frozen_packed_cell, frozen_packed_dec, false);

// ── BenchSerializer ─────────────────────────────────────────────────────────

fn no_cell(_: &[u8]) -> Result<Fixture, DagrError> {
    Err(DagrError::InvalidData)
}

pub struct DagrLayoutSer<L: Layout> {
    builder: DagrBuilder,
    prepared: L::Prepared,
    enc_i: usize,
    decode: DecodeFn,
    _layout: PhantomData<L>,
}

pub type DagrSer = DagrLayoutSer<Packed>;
pub type DagrRegularSer = DagrLayoutSer<Regular>;
pub type DagrFrozenSer = DagrLayoutSer<Frozen>;
pub type DagrFrozenPackedSer = DagrLayoutSer<FrozenPacked>;

impl<L: Layout> Default for DagrLayoutSer<L> {
    fn default() -> Self {
        Self {
            builder: DagrBuilder::with_capacity(4096),
            prepared: L::Prepared::empty(),
            enc_i: 0,
            decode: no_cell,
            _layout: PhantomData,
        }
    }
}

impl<L: Layout> BenchSerializer for DagrLayoutSer<L> {
    fn name(&self) -> &'static str {
        L::NAME
    }
    fn version(&self) -> &'static str {
        // Generator version recorded in schemas/v2/dagr/dagr.lock.json (build.rs).
        env!("DAGR_VERSION")
    }
    fn native_kind(&self) -> NativeKind {
        L::KIND
    }
    fn supports(&self, test_data_name: &str) -> bool {
        matches!(
            test_data_name,
            "message" | "document" | "telemetry" | "strings" | "event"
        ) || (L::GRAPH && test_data_name == "graph")
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.prepare_many(std::slice::from_ref(fixture))
    }
    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        let first = fixtures.first().ok_or_else(|| anyhow!("dagr: empty cell"))?;
        self.decode = L::decoder(first);
        self.prepared = L::Prepared::build(fixtures)?;
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{check_cell_fidelity, make_one, TypeConfig};
    use std::collections::HashMap;
    use std::rc::Rc;

    fn assert_decoded_identity(book: &crate::data::Book) {
        assert_eq!(book.orders.len(), 32);
        assert_eq!(book.people.len(), 8);
        let mut ids = Vec::new();
        let mut counts = HashMap::new();
        for (i, order) in book.orders.iter().enumerate() {
            let p = Rc::as_ptr(&order.region) as usize;
            if !ids.contains(&p) {
                ids.push(p);
            }
            *counts.entry(p).or_insert(0) += 1;
            assert!(Rc::ptr_eq(&order.region, &book.orders[i % 4].region));
            assert_eq!(order.region.note.len(), 64);
        }
        assert_eq!(ids.len(), 4, "decoded regions were duplicated");
        assert!(counts.values().all(|&n| n == 8));
        let mut node = Rc::clone(&book.people[0]);
        for i in 0..book.people.len() {
            let next = node.next.borrow().as_ref().cloned().expect("ring");
            assert!(Rc::ptr_eq(&next, &book.people[(i + 1) % book.people.len()]));
            node = next;
        }
        assert!(Rc::ptr_eq(&node, &book.people[0]));
    }

    fn roundtrip_graph<L: Layout>() {
        let fx = make_one("graph", 42, 0, &TypeConfig::default()).unwrap();
        let mut ser = DagrLayoutSer::<L>::default();
        assert!(ser.supports("graph"), "{}", ser.name());
        ser.prepare_many(std::slice::from_ref(&fx)).unwrap();
        let mut buf = Vec::new();
        ser.begin_cell_encode();
        ser.serialize_into(&fx, &mut buf).unwrap();
        assert!(!buf.is_empty());
        let got = ser.deserialize_bytes(&buf).unwrap();
        check_cell_fidelity("graph", std::slice::from_ref(&fx), std::slice::from_ref(&got)).unwrap();
        let Fixture::Graph(book) = &got else {
            panic!("expected graph");
        };
        assert_decoded_identity(book);
    }

    #[test]
    fn graph_roundtrip_preserves_identity() {
        assert!(!DagrSer::default().supports("graph"));
        assert!(!DagrFrozenPackedSer::default().supports("graph"));
        roundtrip_graph::<Regular>();
        roundtrip_graph::<Frozen>();
        for ser in crate::serializers::all_serializers() {
            let want = matches!(ser.name(), "dagr-regular" | "dagr-frozen");
            assert_eq!(ser.supports("graph"), want, "{}", ser.name());
        }
    }

    /// The reused-builder arena encode must be byte-identical to the arena's own `to_bytes`.
    #[test]
    fn arena_encode_matches_to_bytes() {
        for kind in ["message", "document", "telemetry", "strings", "event", "graph"] {
            let fxs: Vec<Fixture> =
                (0..3).map(|i| make_one(kind, 42, i, &crate::data::TypeConfig::default()).unwrap()).collect();
            let mut b = DagrBuilder::with_capacity(16);
            let reg = regular_cell::Prepared::build(&fxs).unwrap();
            let frz = frozen_cell::Prepared::build(&fxs).unwrap();
            for i in 0..fxs.len() {
                PackedSink::reset(&mut b);
                reg.write(i, &mut b).unwrap();
                assert_eq!(b.record_bytes(), regular_cell::arena_to_bytes(&reg, i).unwrap(), "regular {kind}[{i}]");
                PackedSink::reset(&mut b);
                frz.write(i, &mut b).unwrap();
                assert_eq!(b.record_bytes(), frozen_cell::arena_to_bytes(&frz, i).unwrap(), "frozen {kind}[{i}]");
            }
        }
    }
}
