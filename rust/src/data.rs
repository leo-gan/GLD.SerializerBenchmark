//! Data Model v2 domain types for the Rust harness.
//!
//! Suite types: message, document, telemetry, strings, event, plus the columnar
//! ids table, table_project, nested_table, and signal, plus `graph`.
//! Multiple derive stacks co-exist on the original five so each serializer can
//! use its native path. The columnar structs are serde-only.
//! `graph` is shared nodes and one reference cycle. It is not a serde tree.


use minicbor::{Decode, Encode};
use nanoserde::{DeBin, SerBin};
use rkyv::{Archive, Deserialize as RkyvDeserialize, Serialize as RkyvSerialize};
use serde::{Deserialize, Serialize};
use speedy::{Readable, Writable};
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

/// Epoch-ms base for generated timestamps (matches other language harnesses).
pub const BASE_TS_MS: i64 = 1_704_067_200_000;

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct Message {
    #[n(0)]
    pub f_bool: bool,
    #[n(1)]
    pub f_int32: i32,
    #[n(2)]
    pub f_int64: i64,
    #[n(3)]
    pub f_float64: f64,
    #[n(4)]
    pub f_string: String,
    #[n(5)]
    pub f_bool_2: bool,
    #[n(6)]
    pub f_int32_2: i32,
    #[n(7)]
    pub f_string_2: String,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct DocumentMeta {
    #[n(0)]
    pub region: String,
    #[n(1)]
    pub version: i32,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct DocumentItem {
    #[n(0)]
    pub sku: String,
    #[n(1)]
    pub qty: i32,
    #[n(2)]
    pub price_minor: i64,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct Document {
    #[n(0)]
    pub id: String,
    #[n(1)]
    pub status: i32,
    #[n(2)]
    pub meta: DocumentMeta,
    #[n(3)]
    pub items: Vec<DocumentItem>,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct Telemetry {
    #[n(0)]
    pub source: String,
    #[n(1)]
    pub ts: i64,
    #[n(2)]
    pub tags: Vec<String>,
    #[n(3)]
    pub values: Vec<f64>,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct Strings {
    #[n(0)]
    pub items: Vec<String>,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct EventAttr {
    #[n(0)]
    pub key: String,
    #[n(1)]
    pub value: String,
}

#[derive(
    Debug,
    Clone,
    PartialEq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    SerBin,
    DeBin,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
pub struct Event {
    #[n(0)]
    pub event_id: String,
    #[n(1)]
    pub event_type: String,
    #[n(2)]
    pub occurred_at: i64,
    #[n(3)]
    pub producer: String,
    #[n(4)]
    pub attrs: Vec<EventAttr>,
}

/// Wide flat row. Proto / Avro / SBE name this record Table.
/// Field order is 16 float64, 4 int64, then 2 strings.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TableRow {
    pub f_float_0: f64,
    pub f_float_1: f64,
    pub f_float_2: f64,
    pub f_float_3: f64,
    pub f_float_4: f64,
    pub f_float_5: f64,
    pub f_float_6: f64,
    pub f_float_7: f64,
    pub f_float_8: f64,
    pub f_float_9: f64,
    pub f_float_10: f64,
    pub f_float_11: f64,
    pub f_float_12: f64,
    pub f_float_13: f64,
    pub f_float_14: f64,
    pub f_float_15: f64,
    pub f_int_0: i64,
    pub f_int_1: i64,
    pub f_int_2: i64,
    pub f_int_3: i64,
    pub f_str_0: String,
    pub f_str_1: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NestedMeta {
    pub region: String,
    pub version: i32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NestedItem {
    pub sku: String,
    pub qty: i32,
    pub price_minor: i64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NestedRow {
    pub id: String,
    pub status: i32,
    pub meta: NestedMeta,
    pub items: Vec<NestedItem>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SignalLeg {
    pub leg_id: i64,
    pub leg_qty: i32,
    pub leg_pad: i32,
}

/// Domain order is fixed fields, then strings, then legs.
/// SBE wire order puts the legs group before the strings; this struct does not.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Signal {
    pub seq: i64,
    pub ts: i64,
    pub price_mantissa: i64,
    pub qty: i32,
    pub flags: i32,
    pub symbol: String,
    pub venue: String,
    pub legs: Vec<SignalLeg>,
}

/// Shared node. Several orders hold this same `Rc`.
#[derive(Clone, Debug, PartialEq)]
pub struct Region {
    pub code: String,
    /// Exactly 64 characters at the catalog default.
    pub note: String,
    pub version: i32,
}

/// One order. `region` is a shared handle, not an owned copy.
#[derive(Clone, Debug)]
pub struct Order {
    pub sku: String,
    pub qty: i32,
    pub region: Rc<Region>,
}

/// Ring node. `next` is filled after every person in the ring exists.
#[derive(Clone)]
pub struct Person {
    pub name: String,
    pub next: RefCell<Option<Rc<Person>>>,
}

impl std::fmt::Debug for Person {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let next = self.next.borrow().as_ref().map(|p| p.name.clone());
        f.debug_struct("Person")
            .field("name", &self.name)
            .field("next", &next)
            .finish()
    }
}

/// One graph instance: shared regions and a person ring.
#[derive(Clone, Debug)]
pub struct Book {
    pub orders: Vec<Order>,
    pub people: Vec<Rc<Person>>,
}

fn ptr_key<T>(r: &T) -> usize {
    std::ptr::from_ref::<T>(r) as *const () as usize
}

struct IdMemo {
    a: HashMap<usize, usize>,
    b: HashMap<usize, usize>,
}

impl IdMemo {
    fn new() -> Self {
        Self {
            a: HashMap::new(),
            b: HashMap::new(),
        }
    }

    /// `Some(eq)` when either side was already visited. `None` means compare fields.
    fn enter(&mut self, ka: usize, kb: usize) -> Option<bool> {
        let seen_a = self.a.get(&ka).copied();
        let seen_b = self.b.get(&kb).copied();
        if seen_a.is_some() || seen_b.is_some() {
            return Some(seen_a.is_some() && seen_b.is_some() && seen_a == seen_b);
        }
        let token = self.a.len();
        self.a.insert(ka, token);
        self.b.insert(kb, token);
        None
    }
}

/// Identity correspondence for one graph.
///
/// The second visit of a node must land on the same token on the other side.
/// A duplicated region or an unrolled ring compares unequal. The back-edge stops the walk.
fn graphs_match(left: &Book, right: &Book) -> bool {
    fn book(a: &Book, b: &Book, m: &mut IdMemo) -> bool {
        if let Some(done) = m.enter(ptr_key(a), ptr_key(b)) {
            return done;
        }
        a.orders.len() == b.orders.len()
            && a.people.len() == b.people.len()
            && a.orders
                .iter()
                .zip(b.orders.iter())
                .all(|(x, y)| order(x, y, m))
            && a.people
                .iter()
                .zip(b.people.iter())
                .all(|(x, y)| person(x, y, m))
    }
    fn order(a: &Order, b: &Order, m: &mut IdMemo) -> bool {
        if let Some(done) = m.enter(ptr_key(a), ptr_key(b)) {
            return done;
        }
        a.sku == b.sku && a.qty == b.qty && region(&a.region, &b.region, m)
    }
    fn region(a: &Rc<Region>, b: &Rc<Region>, m: &mut IdMemo) -> bool {
        if let Some(done) = m.enter(ptr_key(a.as_ref()), ptr_key(b.as_ref())) {
            return done;
        }
        a.code == b.code && a.note == b.note && a.version == b.version
    }
    fn person(a: &Rc<Person>, b: &Rc<Person>, m: &mut IdMemo) -> bool {
        if let Some(done) = m.enter(ptr_key(a.as_ref()), ptr_key(b.as_ref())) {
            return done;
        }
        if a.name != b.name {
            return false;
        }
        let next_a = a.next.borrow().clone();
        let next_b = b.next.borrow().clone();
        match (next_a, next_b) {
            (None, None) => true,
            (Some(x), Some(y)) => person(&x, &y, m),
            _ => false,
        }
    }
    book(left, right, &mut IdMemo::new())
}

impl PartialEq for Book {
    fn eq(&self, other: &Self) -> bool {
        graphs_match(self, other)
    }
}

// SAFETY: `BenchSerializer: Send` stores fixtures in serializer state, but the harness
// never shares one fixture across threads. `Rc`'s refcount and `RefCell`'s flag stay on
// the owning thread, same contract as the Dagr arena's `unsafe impl Send`.
#[allow(clippy::non_send_fields_in_send_ty)]
unsafe impl Send for Book {}

impl Serialize for Book {
    fn serialize<S: serde::Serializer>(&self, _serializer: S) -> Result<S::Ok, S::Error> {
        Err(<S::Error as serde::ser::Error>::custom(
            "graph is a reference cycle and is not a serde tree",
        ))
    }
}

impl<'de> Deserialize<'de> for Book {
    fn deserialize<D: serde::Deserializer<'de>>(_deserializer: D) -> Result<Self, D::Error> {
        Err(<D::Error as serde::de::Error>::custom(
            "graph is a reference cycle and is not a serde tree",
        ))
    }
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

use rand::{Rng as _, RngCore};
use rand_pcg::Lcg64Xsh32;

/// Nothing-up-my-sleeve constants: first digits of π (same approach as
/// [rust_serialization_benchmark](https://github.com/djkoloski/rust_serialization_benchmark)).
const PI_STATE: u64 = 3_141_592_653;
const PI_STREAM: u64 = 5_897_932_384;

/// FNV-1a-ish mix so (suite_seed, type_id, instance_index) → distinct stream.
/// The golden-ratio constant is a standard avalanche multiplier (2^64/φ), not a secret.
pub fn mix_seed(seed: u64, type_id: &str, idx: i32) -> u64 {
    let mut h = seed;
    for b in type_id.bytes() {
        h = (h ^ b as u64).wrapping_mul(0x0100_0000_01B3);
    }
    h ^= (idx as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15);
    if h == 0 {
        1
    } else {
        h
    }
}

/// Deterministic PCG-XSH-RR RNG for fixture generation (within-language only).
///
/// Seeded from `mix_seed(suite_seed, type_id, idx) ^ PI_STATE` with stream
/// `PI_STREAM`. Same `(seed, type_id, type_config, instance_index)` → same
/// instance across runs; streams are **not** required to match other languages.
pub struct Rng {
    inner: Lcg64Xsh32,
}

impl Rng {
    pub fn new(mixed_seed: u64) -> Self {
        let state = mixed_seed ^ PI_STATE;
        Self {
            inner: Lcg64Xsh32::new(state, PI_STREAM),
        }
    }

    pub fn next_int(&mut self, lo: i32, hi: i32) -> i32 {
        if hi <= lo {
            return lo;
        }
        self.inner.gen_range(lo..=hi)
    }

    pub fn next_bool(&mut self) -> bool {
        self.inner.gen_bool(0.5)
    }

    pub fn next_f64(&mut self) -> f64 {
        // Match prior harness scale: unit interval via 53-bit mantissa.
        (self.inner.next_u64() >> 11) as f64 / ((1u64 << 53) as f64)
    }

    pub fn word(&mut self, min_l: usize, max_l: usize) -> String {
        let n = self.next_int(min_l as i32, max_l as i32) as usize;
        const A: &[u8] = b"abcdefghijklmnopqrstuvwxyz";
        (0..n)
            .map(|_| A[self.inner.gen_range(0..26)] as char)
            .collect()
    }
}

/// Resolved `type_config` for one cell. Missing keys use catalog defaults.
#[derive(Clone, Debug)]
pub struct TypeConfig {
    value: serde_json::Value,
}

impl Default for TypeConfig {
    fn default() -> Self {
        Self {
            value: serde_json::json!({}),
        }
    }
}

impl TypeConfig {
    pub fn from_value(value: serde_json::Value) -> Self {
        if value.is_object() {
            Self { value }
        } else {
            Self::default()
        }
    }

    fn i32(&self, key: &str, default: i32) -> i32 {
        self.value
            .get(key)
            .and_then(|v| v.as_i64())
            .map(|n| n as i32)
            .unwrap_or(default)
    }

    fn f64(&self, key: &str, default: f64) -> f64 {
        match self.value.get(key) {
            Some(v) => v
                .as_f64()
                .or_else(|| v.as_i64().map(|n| n as f64))
                .unwrap_or(default),
            None => default,
        }
    }

    fn str_val<'a>(&'a self, key: &str) -> Option<&'a str> {
        self.value.get(key).and_then(|v| v.as_str())
    }

    /// Inclusive range. Absent object or side uses the catalog default for that side.
    fn range(&self, key: &str, def_min: i32, def_max: i32) -> (i32, i32) {
        let Some(obj) = self.value.get(key).and_then(|v| v.as_object()) else {
            return (def_min, def_max);
        };
        let min = obj
            .get("min")
            .and_then(|v| v.as_i64())
            .map(|n| n as i32)
            .unwrap_or(def_min);
        let max = obj
            .get("max")
            .and_then(|v| v.as_i64())
            .map(|n| n as i32)
            .unwrap_or(def_max);
        (min, max)
    }
}

pub fn is_columnar_id(type_id: &str) -> bool {
    matches!(
        type_id,
        "table" | "table_project" | "nested_table" | "signal"
    )
}

fn shared_vocab(seed: u64, type_id: &str, smin: i32, smax: i32) -> Vec<String> {
    let mut vocab_rng = Rng::new(mix_seed(seed, &format!("{type_id}#vocab"), 0));
    (0..32)
        .map(|_| vocab_rng.word(smin as usize, smax as usize))
        .collect()
}

fn pick_word(rng: &mut Rng, vocab: &[String], duplication: f64, smin: i32, smax: i32) -> String {
    if !vocab.is_empty() && rng.next_f64() < duplication {
        let idx = rng.next_int(0, vocab.len() as i32 - 1) as usize;
        vocab[idx].clone()
    } else {
        rng.word(smin as usize, smax as usize)
    }
}

fn make_table(rng: &mut Rng, cfg: &TypeConfig, vocab: &[String]) -> TableRow {
    let (lo, hi) = cfg.range("int_range", 0, 1_000_000);
    let (smin, smax) = cfg.range("string_len", 3, 16);
    let dup = cfg.f64("duplication", 0.5);
    let floats: Vec<f64> = (0..16).map(|_| rng.next_f64() * 1000.0).collect();
    let ints: Vec<i64> = (0..4).map(|_| rng.next_int(lo, hi) as i64).collect();
    let strs: Vec<String> = (0..2)
        .map(|_| pick_word(rng, vocab, dup, smin, smax))
        .collect();
    TableRow {
        f_float_0: floats[0],
        f_float_1: floats[1],
        f_float_2: floats[2],
        f_float_3: floats[3],
        f_float_4: floats[4],
        f_float_5: floats[5],
        f_float_6: floats[6],
        f_float_7: floats[7],
        f_float_8: floats[8],
        f_float_9: floats[9],
        f_float_10: floats[10],
        f_float_11: floats[11],
        f_float_12: floats[12],
        f_float_13: floats[13],
        f_float_14: floats[14],
        f_float_15: floats[15],
        f_int_0: ints[0],
        f_int_1: ints[1],
        f_int_2: ints[2],
        f_int_3: ints[3],
        f_str_0: strs[0].clone(),
        f_str_1: strs[1].clone(),
    }
}

fn make_nested(rng: &mut Rng, cfg: &TypeConfig) -> NestedRow {
    let children = cfg.i32("children", 4).max(0);
    let (smin, smax) = cfg.range("string_len", 3, 12);
    let items: Vec<_> = (0..children)
        .map(|_| NestedItem {
            sku: rng.word(smin as usize, smax as usize),
            qty: rng.next_int(1, 100),
            price_minor: rng.next_int(0, 100_000) as i64,
        })
        .collect();
    NestedRow {
        id: rng.word(8, 12),
        status: rng.next_int(0, 5),
        meta: NestedMeta {
            region: rng.word(2, 4),
            version: rng.next_int(1, 10),
        },
        items,
    }
}

fn make_signal(rng: &mut Rng, cfg: &TypeConfig) -> Signal {
    let group_count = cfg.i32("group_count", 4).max(0);
    let (smin, smax) = cfg.range("string_len", 3, 12);
    // Same consumption order as the Python list-comp: legs, then the fixed block.
    let legs: Vec<_> = (0..group_count)
        .map(|_| SignalLeg {
            leg_id: rng.next_int(0, 1_000_000) as i64,
            leg_qty: rng.next_int(0, 10_000),
            leg_pad: 0,
        })
        .collect();
    Signal {
        seq: rng.next_int(0, 1_000_000_000) as i64,
        ts: BASE_TS_MS + rng.next_int(0, 86_400_000) as i64,
        price_mantissa: rng.next_int(0, 1_000_000_000) as i64,
        qty: rng.next_int(0, 10_000),
        flags: rng.next_int(0, 65_535),
        symbol: rng.word(smin as usize, smax as usize),
        venue: rng.word(smin as usize, smax as usize),
        legs,
    }
}

/// One graph. Call order is the cross-language contract.
///
/// Regions (code, 64-char note, version), then orders (sku, qty, shared region
/// `i % region_count`), then person names, then the ring of references.
fn make_graph(rng: &mut Rng, cfg: &TypeConfig) -> anyhow::Result<Book> {
    let (smin, smax) = cfg.range("string_len", 8, 16);
    let n_orders = cfg.i32("order_count", 32).max(0) as usize;
    let n_regions = cfg.i32("region_count", 4);
    let ring = cfg.i32("ring_size", 8);
    if n_regions < 1 {
        anyhow::bail!("region_count must be >= 1");
    }
    if ring < 1 {
        anyhow::bail!("ring_size must be >= 1");
    }
    let n_regions = n_regions as usize;
    let ring = ring as usize;
    let smin = smin as usize;
    let smax = smax as usize;
    let regions: Vec<Rc<Region>> = (0..n_regions)
        .map(|_| {
            Rc::new(Region {
                code: rng.word(smin, smax),
                note: rng.word(64, 64),
                version: rng.next_int(1, 10),
            })
        })
        .collect();
    let orders = (0..n_orders)
        .map(|i| Order {
            sku: rng.word(smin, smax),
            qty: rng.next_int(1, 100),
            region: Rc::clone(&regions[i % n_regions]),
        })
        .collect();
    let people: Vec<Rc<Person>> = (0..ring)
        .map(|_| {
            Rc::new(Person {
                name: rng.word(smin, smax),
                next: RefCell::new(None),
            })
        })
        .collect();
    for (i, person) in people.iter().enumerate() {
        *person.next.borrow_mut() = Some(Rc::clone(&people[(i + 1) % ring]));
    }
    Ok(Book { orders, people })
}

/// Build one V2 fixture. `cfg` is the resolved type_config (empty object = catalog defaults).
///
/// Old type ids keep the historical draw sequence when catalog defaults are in effect.
/// `strings` still ignores `duplication` so those cells do not change.
/// `graph` draws regions, then orders, then person names, then closes the ring.
pub fn make_one(
    type_id: &str,
    seed: u64,
    instance_index: i32,
    cfg: &TypeConfig,
) -> anyhow::Result<Fixture> {
    if type_id == "table" || type_id == "table_project" {
        let (smin, smax) = cfg.range("string_len", 3, 16);
        let vocab = shared_vocab(seed, type_id, smin, smax);
        let mut rng = Rng::new(mix_seed(seed, type_id, instance_index));
        let row = make_table(&mut rng, cfg, &vocab);
        return Ok(if type_id == "table_project" {
            Fixture::TableProject(row)
        } else {
            Fixture::Table(row)
        });
    }
    let mut r = Rng::new(mix_seed(seed, type_id, instance_index));
    match type_id {
        "message" => {
            let (lo, hi) = cfg.range("int_range", 0, 1_000_000);
            let (smin, smax) = cfg.range("string_len", 3, 16);
            Ok(Fixture::Message(Message {
                f_bool: r.next_bool(),
                f_int32: r.next_int(lo, hi.min(i32::MAX)),
                f_int64: r.next_int(lo, hi) as i64,
                f_float64: r.next_f64() * 1000.0,
                f_string: r.word(smin as usize, smax as usize),
                f_bool_2: r.next_bool(),
                f_int32_2: r.next_int(lo, hi.min(i32::MAX)),
                f_string_2: r.word(smin as usize, smax as usize),
            }))
        }
        "document" => {
            let children = cfg.i32("children", 8).max(0);
            let (smin, smax) = cfg.range("string_len", 3, 12);
            let items: Vec<_> = (0..children)
                .map(|_| DocumentItem {
                    sku: r.word(smin as usize, smax as usize),
                    qty: r.next_int(1, 100),
                    price_minor: r.next_int(0, 100_000) as i64,
                })
                .collect();
            Ok(Fixture::Document(Document {
                id: r.word(8, 12),
                status: r.next_int(0, 5),
                meta: DocumentMeta {
                    region: r.word(2, 4),
                    version: r.next_int(1, 10),
                },
                items,
            }))
        }
        "telemetry" => {
            let points = cfg.i32("points", 32).max(0);
            let tag_count = cfg.i32("tag_count", 2).max(0);
            let (smin, smax) = cfg.range("string_len", 3, 10);
            let tags: Vec<_> = (0..tag_count)
                .map(|_| r.word(smin as usize, smax as usize))
                .collect();
            let number_type = cfg.str_val("number_type").unwrap_or("float64");
            let values: Vec<_> = if number_type == "int64" {
                (0..points).map(|_| r.next_int(0, 10_000) as f64).collect()
            } else {
                (0..points).map(|_| r.next_f64() * 100.0).collect()
            };
            Ok(Fixture::Telemetry(Telemetry {
                source: r.word(smin as usize, smax as usize),
                ts: BASE_TS_MS + r.next_int(0, 86_400_000) as i64,
                tags,
                values,
            }))
        }
        "strings" => {
            // duplication stays unused: applying the catalog 0.1 would change historical cells.
            let count = cfg.i32("count", 32).max(0);
            let (smin, smax) = cfg.range("string_len", 3, 16);
            let items: Vec<_> = (0..count)
                .map(|_| r.word(smin as usize, smax as usize))
                .collect();
            Ok(Fixture::Strings(Strings { items }))
        }
        "event" => {
            let attr_count = cfg.i32("attr_count", 4).max(0);
            let (smin, smax) = cfg.range("string_len", 3, 12);
            let attrs: Vec<_> = (0..attr_count)
                .map(|_| EventAttr {
                    key: r.word(smin as usize, smax as usize),
                    value: r.word(smin as usize, smax as usize),
                })
                .collect();
            Ok(Fixture::Event(Event {
                event_id: r.word(8, 12),
                event_type: r.word(smin as usize, smax as usize),
                occurred_at: BASE_TS_MS + r.next_int(0, 86_400_000) as i64,
                producer: r.word(smin as usize, smax as usize),
                attrs,
            }))
        }
        "nested_table" => Ok(Fixture::NestedTable(make_nested(&mut r, cfg))),
        "signal" => Ok(Fixture::Signal(make_signal(&mut r, cfg))),
        "graph" => Ok(Fixture::Graph(make_graph(&mut r, cfg)?)),
        other => anyhow::bail!("unknown v2 type_id {other}"),
    }
}

/// `f_float_0` from a table row, a batch of rows, or an existing projection.
pub fn collect_f_float_0(fx: &Fixture) -> anyhow::Result<Vec<f64>> {
    match fx {
        Fixture::Table(row) | Fixture::TableProject(row) => Ok(vec![row.f_float_0]),
        Fixture::Rows(rows) => {
            let mut out = Vec::new();
            for row in rows {
                out.extend(collect_f_float_0(row)?);
            }
            Ok(out)
        }
        Fixture::Projected(values) => Ok(values.clone()),
        other => anyhow::bail!("cannot project f_float_0 from {}", other.name()),
    }
}

// ---------------------------------------------------------------------------
// Fixture enum
// ---------------------------------------------------------------------------

/// Holder for harness fixtures (externally tagged for Serde formats).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Fixture {
    Message(Message),
    Document(Document),
    Telemetry(Telemetry),
    Strings(Strings),
    Event(Event),
    Table(TableRow),
    /// Same row as [`Fixture::Table`]. Deserialize of this id is [`Fixture::Projected`].
    TableProject(TableRow),
    NestedTable(NestedRow),
    Signal(Signal),
    /// One payload covering N rows (columnar cell, N>1).
    Rows(Vec<Fixture>),
    /// `f_float_0` for every row of a `table_project` cell, including N=1.
    Projected(Vec<f64>),
    /// Shared regions and one person ring. `==` is the identity walker, not derived equality.
    Graph(Book),
}

impl Fixture {
    /// Catalog type_id.
    pub fn name(&self) -> &'static str {
        match self {
            Fixture::Message(_) => "message",
            Fixture::Document(_) => "document",
            Fixture::Telemetry(_) => "telemetry",
            Fixture::Strings(_) => "strings",
            Fixture::Event(_) => "event",
            Fixture::Table(_) => "table",
            Fixture::TableProject(_) | Fixture::Projected(_) => "table_project",
            Fixture::NestedTable(_) => "nested_table",
            Fixture::Signal(_) => "signal",
            Fixture::Graph(_) => "graph",
            Fixture::Rows(rows) => rows.first().map(|r| r.name()).unwrap_or("rows"),
        }
    }
}

fn nearly_eq(a: f64, b: f64) -> bool {
    let scale = 1.0_f64.max(a.abs()).max(b.abs());
    (a - b).abs() <= 1e-6 * scale
}

/// Semantic fidelity check (float-tolerant for message / telemetry).
pub fn fidelity(a: &Fixture, b: &Fixture) -> bool {
    match (a, b) {
        (Fixture::Message(x), Fixture::Message(y)) => {
            x.f_bool == y.f_bool
                && x.f_int32 == y.f_int32
                && x.f_int64 == y.f_int64
                && nearly_eq(x.f_float64, y.f_float64)
                && x.f_string == y.f_string
                && x.f_bool_2 == y.f_bool_2
                && x.f_int32_2 == y.f_int32_2
                && x.f_string_2 == y.f_string_2
        }
        (Fixture::Document(x), Fixture::Document(y)) => x == y,
        (Fixture::Telemetry(x), Fixture::Telemetry(y)) => {
            x.source == y.source
                && x.ts == y.ts
                && x.tags == y.tags
                && x.values.len() == y.values.len()
                && x.values
                    .iter()
                    .zip(y.values.iter())
                    .all(|(p, q)| nearly_eq(*p, *q))
        }
        (Fixture::Strings(x), Fixture::Strings(y)) => x == y,
        (Fixture::Event(x), Fixture::Event(y)) => x == y,
        (Fixture::Table(x), Fixture::Table(y))
        | (Fixture::TableProject(x), Fixture::TableProject(y)) => table_eq(x, y),
        (Fixture::NestedTable(x), Fixture::NestedTable(y)) => x == y,
        (Fixture::Signal(x), Fixture::Signal(y)) => x == y,
        (Fixture::Graph(x), Fixture::Graph(y)) => x == y,
        (Fixture::Rows(x), Fixture::Rows(y)) => {
            x.len() == y.len() && x.iter().zip(y.iter()).all(|(p, q)| fidelity(p, q))
        }
        (Fixture::Projected(x), Fixture::Projected(y)) => {
            x.len() == y.len() && x.iter().zip(y.iter()).all(|(p, q)| nearly_eq(*p, *q))
        }
        _ => false,
    }
}

fn table_eq(x: &TableRow, y: &TableRow) -> bool {
    let xf = x.floats();
    let yf = y.floats();
    xf.iter().zip(yf.iter()).all(|(p, q)| nearly_eq(*p, *q))
        && x.ints() == y.ints()
        && x.f_str_0 == y.f_str_0
        && x.f_str_1 == y.f_str_1
}

impl TableRow {
    pub fn floats(&self) -> [f64; 16] {
        [
            self.f_float_0,
            self.f_float_1,
            self.f_float_2,
            self.f_float_3,
            self.f_float_4,
            self.f_float_5,
            self.f_float_6,
            self.f_float_7,
            self.f_float_8,
            self.f_float_9,
            self.f_float_10,
            self.f_float_11,
            self.f_float_12,
            self.f_float_13,
            self.f_float_14,
            self.f_float_15,
        ]
    }

    pub fn ints(&self) -> [i64; 4] {
        [self.f_int_0, self.f_int_1, self.f_int_2, self.f_int_3]
    }
}

/// Fidelity for one cell.
///
/// `table_project` accepts only a single [`Fixture::Projected`] whose length is N.
/// A full row, a batch of rows, or any other shape fails that check.
pub fn check_cell_fidelity(type_id: &str, expected: &[Fixture], got: &[Fixture]) -> anyhow::Result<()> {
    if type_id == "table_project" {
        if got.len() != 1 {
            anyhow::bail!(
                "table_project deserialize returned {} values, expected one Projected sequence",
                got.len()
            );
        }
        let Fixture::Projected(actual) = &got[0] else {
            anyhow::bail!(
                "table_project fidelity expects Projected, got {}",
                got[0].name()
            );
        };
        if actual.len() != expected.len() {
            anyhow::bail!(
                "table_project len {} != {}",
                actual.len(),
                expected.len()
            );
        }
        for (i, exp) in expected.iter().enumerate() {
            let want = match exp {
                Fixture::Table(r) | Fixture::TableProject(r) => r.f_float_0,
                _ => anyhow::bail!("table_project expected a table row"),
            };
            if !nearly_eq(want, actual[i]) {
                anyhow::bail!("table_project f_float_0 mismatch at {i}");
            }
        }
        return Ok(());
    }
    let flat: Vec<&Fixture> = match got {
        [Fixture::Rows(rows)] => rows.iter().collect(),
        other => other.iter().collect(),
    };
    if flat.len() != expected.len() {
        anyhow::bail!("fidelity batch len {} != {}", flat.len(), expected.len());
    }
    for (a, b) in expected.iter().zip(flat.iter()) {
        if !fidelity(a, b) {
            anyhow::bail!("fidelity failed for {}", a.name());
        }
    }
    Ok(())
}

/// Standard suite samples (one of each original V2 type_id).
pub fn all_fixtures(seed: u64) -> Vec<Fixture> {
    ["message", "document", "telemetry", "strings", "event"]
        .iter()
        .map(|tid| {
            make_one(tid, seed, 0, &TypeConfig::default())
                .unwrap_or_else(|e| panic!("make_one({tid}): {e}"))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::collections::HashMap;
    use std::rc::Rc;

    #[test]
    fn all_fixtures_are_v2_type_ids() {
        let names: Vec<_> = all_fixtures(42).iter().map(|f| f.name()).collect();
        assert_eq!(
            names,
            vec!["message", "document", "telemetry", "strings", "event"]
        );
    }

    #[test]
    fn make_one_message_roundtrip_fidelity() {
        let a = make_one("message", 42, 0, &TypeConfig::default()).unwrap();
        assert_eq!(a.name(), "message");
        assert!(fidelity(&a, &a));
    }

    #[test]
    fn make_one_document_has_children() {
        let cfg = TypeConfig::from_value(serde_json::json!({"children": 5}));
        let fx = make_one("document", 7, 1, &cfg).unwrap();
        match fx {
            Fixture::Document(d) => assert_eq!(d.items.len(), 5),
            _ => panic!("expected document"),
        }
    }

    #[test]
    fn make_one_unknown_errors() {
        assert!(make_one("not-a-suite-type", 1, 0, &TypeConfig::default()).is_err());
    }

    #[test]
    fn make_one_columnar_ids_are_deterministic() {
        let cfg = TypeConfig::default();
        for tid in ["table", "table_project", "nested_table", "signal"] {
            let a = make_one(tid, 99, 3, &cfg).unwrap();
            let b = make_one(tid, 99, 3, &cfg).unwrap();
            assert_eq!(a, b, "{tid} not deterministic");
            let c = make_one(tid, 99, 4, &cfg).unwrap();
            assert_ne!(a, c, "{tid} ignored instance index");
        }
    }

    #[test]
    fn table_strings_repeat_across_rows() {
        let cfg = TypeConfig::default();
        let mut strings = Vec::new();
        for i in 0..40 {
            match make_one("table", 42, i, &cfg).unwrap() {
                Fixture::Table(row) => {
                    strings.push(row.f_str_0);
                    strings.push(row.f_str_1);
                }
                _ => panic!("expected table"),
            }
        }
        let unique: std::collections::HashSet<&String> = strings.iter().collect();
        assert!(
            unique.len() < strings.len(),
            "duplication 0.5 should repeat a vocab word across 40 rows, unique {} of {}",
            unique.len(),
            strings.len()
        );
    }

    #[test]
    fn table_and_table_project_differ_at_same_index() {
        let cfg = TypeConfig::default();
        let a = make_one("table", 42, 0, &cfg).unwrap();
        let b = make_one("table_project", 42, 0, &cfg).unwrap();
        let af = collect_f_float_0(&a).unwrap();
        let bf = collect_f_float_0(&b).unwrap();
        assert_ne!(af, bf);
    }

    #[test]
    fn nested_default_children_and_signal_shape() {
        let cfg = TypeConfig::default();
        match make_one("nested_table", 1, 0, &cfg).unwrap() {
            Fixture::NestedTable(row) => assert_eq!(row.items.len(), 4),
            _ => panic!("expected nested_table"),
        }
        match make_one("signal", 1, 2, &cfg).unwrap() {
            Fixture::Signal(sig) => {
                assert_eq!(sig.legs.len(), 4);
                assert!(sig.legs.iter().all(|leg| leg.leg_pad == 0));
                let value = serde_json::to_value(&sig).unwrap();
                let keys: Vec<&str> = value.as_object().unwrap().keys().map(|k| k.as_str()).collect();
                assert_eq!(
                    keys,
                    vec![
                        "seq",
                        "ts",
                        "price_mantissa",
                        "qty",
                        "flags",
                        "symbol",
                        "venue",
                        "legs"
                    ]
                );
                let sym = keys.iter().position(|k| *k == "symbol").unwrap();
                let venue = keys.iter().position(|k| *k == "venue").unwrap();
                let legs = keys.iter().position(|k| *k == "legs").unwrap();
                assert!(sym < venue && venue < legs);
            }
            _ => panic!("expected signal"),
        }
    }

    #[test]
    fn type_config_threads_table_ranges_and_strings_ignore_duplication() {
        let cfg = TypeConfig::from_value(serde_json::json!({
            "string_len": {"min": 4, "max": 4},
            "int_range": {"min": 7, "max": 7},
            "duplication": 0.0
        }));
        match make_one("table", 3, 0, &cfg).unwrap() {
            Fixture::Table(row) => {
                assert_eq!(row.ints(), [7, 7, 7, 7]);
                assert_eq!(row.f_str_0.len(), 4);
                assert_eq!(row.f_str_1.len(), 4);
            }
            _ => panic!("expected table"),
        }
        let plain = make_one("strings", 42, 0, &TypeConfig::default()).unwrap();
        let dup = TypeConfig::from_value(serde_json::json!({
            "duplication": 0.1,
            "count": 32,
            "string_len": {"min": 3, "max": 16}
        }));
        let with_dup = make_one("strings", 42, 0, &dup).unwrap();
        assert_eq!(plain, with_dup);
    }

    #[test]
    fn table_project_fidelity_rejects_full_row() {
        let cfg = TypeConfig::default();
        let row = match make_one("table_project", 5, 0, &cfg).unwrap() {
            Fixture::TableProject(row) => row,
            _ => panic!("expected table_project"),
        };
        let expected = vec![Fixture::TableProject(row.clone())];
        let full = vec![Fixture::TableProject(row.clone())];
        assert!(check_cell_fidelity("table_project", &expected, &full).is_err());
        let rows = vec![Fixture::Rows(vec![Fixture::Table(row.clone())])];
        assert!(check_cell_fidelity("table_project", &expected, &rows).is_err());
        let projected = vec![Fixture::Projected(vec![row.f_float_0])];
        check_cell_fidelity("table_project", &expected, &projected).unwrap();
        let n2 = vec![
            Fixture::TableProject(row.clone()),
            Fixture::TableProject(row.clone()),
        ];
        let seq = vec![Fixture::Projected(vec![row.f_float_0, row.f_float_0])];
        check_cell_fidelity("table_project", &n2, &seq).unwrap();
    }

    fn alias_book(book: &Book) -> Book {
        let mut regions: Vec<(usize, Rc<Region>)> = Vec::new();
        let mut orders = Vec::with_capacity(book.orders.len());
        for order in &book.orders {
            let key = Rc::as_ptr(&order.region) as usize;
            let region = if let Some(pos) = regions.iter().position(|(k, _)| *k == key) {
                Rc::clone(&regions[pos].1)
            } else {
                let region = Rc::new(Region {
                    code: order.region.code.clone(),
                    note: order.region.note.clone(),
                    version: order.region.version,
                });
                regions.push((key, Rc::clone(&region)));
                region
            };
            orders.push(Order {
                sku: order.sku.clone(),
                qty: order.qty,
                region,
            });
        }
        let people: Vec<Rc<Person>> = book
            .people
            .iter()
            .map(|p| {
                Rc::new(Person {
                    name: p.name.clone(),
                    next: RefCell::new(None),
                })
            })
            .collect();
        let n = people.len();
        for (i, person) in people.iter().enumerate() {
            *person.next.borrow_mut() = Some(Rc::clone(&people[(i + 1) % n]));
        }
        Book { orders, people }
    }

    #[test]
    fn make_one_graph_is_deterministic_and_shared() {
        let cfg = TypeConfig::default();
        let a = make_one("graph", 42, 0, &cfg).unwrap();
        let b = make_one("graph", 42, 0, &cfg).unwrap();
        assert_eq!(a.name(), "graph");
        assert_eq!(a, b);
        assert!(fidelity(&a, &b));
        let c = make_one("graph", 42, 1, &cfg).unwrap();
        assert_ne!(a, c);

        let Fixture::Graph(book) = &a else {
            panic!("expected graph");
        };
        assert_eq!(book.orders.len(), 32);
        assert_eq!(book.people.len(), 8);
        assert!(book.orders.iter().all(|o| o.region.note.len() == 64));
        assert!(book.orders.iter().all(|o| {
            (8..=16).contains(&o.sku.len())
                && (8..=16).contains(&o.region.code.len())
                && (1..=100).contains(&o.qty)
                && (1..=10).contains(&o.region.version)
        }));
        assert!(book.people.iter().all(|p| (8..=16).contains(&p.name.len())));

        let mut ids = Vec::new();
        let mut counts = HashMap::new();
        for (i, order) in book.orders.iter().enumerate() {
            let p = Rc::as_ptr(&order.region) as usize;
            if !ids.contains(&p) {
                ids.push(p);
            }
            *counts.entry(p).or_insert(0) += 1;
            assert!(Rc::ptr_eq(&order.region, &book.orders[i % 4].region));
        }
        assert_eq!(ids.len(), 4, "regions were cloned per order");
        assert!(counts.values().all(|&n| n == 8));

        let mut node = Rc::clone(&book.people[0]);
        for i in 0..book.people.len() {
            let next = node.next.borrow().as_ref().cloned().expect("ring");
            assert!(
                Rc::ptr_eq(&next, &book.people[(i + 1) % book.people.len()]),
                "people[{i}].next is not people[{}]",
                (i + 1) % book.people.len()
            );
            node = next;
        }
        assert!(Rc::ptr_eq(&node, &book.people[0]));

        let alias = Fixture::Graph(alias_book(book));
        assert_eq!(a, alias);
        assert!(fidelity(&a, &alias));

        let mut duplicated = alias_book(book);
        duplicated.orders = book
            .orders
            .iter()
            .map(|order| Order {
                sku: order.sku.clone(),
                qty: order.qty,
                region: Rc::new(order.region.as_ref().clone()),
            })
            .collect();
        let duplicated = Fixture::Graph(duplicated);
        assert_ne!(a, duplicated);
        assert!(!fidelity(&a, &duplicated));

        let Book { orders, .. } = alias_book(book);
        let people: Vec<Rc<Person>> = book
            .people
            .iter()
            .map(|p| {
                Rc::new(Person {
                    name: p.name.clone(),
                    next: RefCell::new(None),
                })
            })
            .collect();
        for (i, person) in people.iter().enumerate() {
            let nxt = &book.people[(i + 1) % people.len()];
            *person.next.borrow_mut() = Some(Rc::new(Person {
                name: nxt.name.clone(),
                next: RefCell::new(None),
            }));
        }
        let unrolled = Fixture::Graph(Book { orders, people });
        assert_ne!(a, unrolled);
        assert!(!fidelity(&a, &unrolled));

        assert!(serde_json::to_vec(&a).is_err());
    }
}
