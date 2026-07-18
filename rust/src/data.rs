//! Data Model v2 domain types for the Rust harness.
//!
//! Suite types: message, document, telemetry, strings, event.
//! Multiple derive stacks co-exist so each serializer can use its native path.

use minicbor::{Decode, Encode};
use nanoserde::{DeBin, SerBin};
use rkyv::{Archive, Deserialize as RkyvDeserialize, Serialize as RkyvSerialize};
use serde::{Deserialize, Serialize};
use speedy::{Readable, Writable};

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

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Deterministic xorshift64* RNG (within-language seed mixing).
pub struct Rng {
    state: u64,
}

impl Rng {
    pub fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 {
                0x9E3779B97F4A7C15
            } else {
                seed
            },
        }
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }

    pub fn next_int(&mut self, lo: i32, hi: i32) -> i32 {
        if hi <= lo {
            return lo;
        }
        lo + (self.next_u64() % (hi - lo + 1) as u64) as i32
    }

    pub fn next_bool(&mut self) -> bool {
        self.next_u64() & 1 == 1
    }

    pub fn next_f64(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 / ((1u64 << 53) as f64)
    }

    pub fn word(&mut self, min_l: usize, max_l: usize) -> String {
        let n = self.next_int(min_l as i32, max_l as i32) as usize;
        const A: &[u8] = b"abcdefghijklmnopqrstuvwxyz";
        (0..n)
            .map(|_| A[(self.next_u64() % 26) as usize] as char)
            .collect()
    }
}

pub fn mix_seed(seed: u64, type_id: &str, idx: i32) -> u64 {
    let mut h = seed;
    for b in type_id.bytes() {
        h = (h ^ b as u64).wrapping_mul(0x100000001B3);
    }
    h ^= (idx as u64).wrapping_mul(0x9E3779B97F4A7C15);
    if h == 0 {
        1
    } else {
        h
    }
}

/// Build one V2 fixture instance.
/// `children` / `points` / `count` / `attr_count` come from type_config defaults.
pub fn make_one(
    type_id: &str,
    seed: u64,
    instance_index: i32,
    children: i32,
    points: i32,
    count: i32,
    attr_count: i32,
) -> anyhow::Result<Fixture> {
    let mut r = Rng::new(mix_seed(seed, type_id, instance_index));
    match type_id {
        "message" => Ok(Fixture::Message(Message {
            f_bool: r.next_bool(),
            f_int32: r.next_int(0, 1_000_000),
            f_int64: r.next_int(0, 1_000_000) as i64,
            f_float64: r.next_f64() * 1000.0,
            f_string: r.word(3, 16),
            f_bool_2: r.next_bool(),
            f_int32_2: r.next_int(0, 1_000_000),
            f_string_2: r.word(3, 16),
        })),
        "document" => {
            let items: Vec<_> = (0..children)
                .map(|_| DocumentItem {
                    sku: r.word(3, 12),
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
            let tags: Vec<_> = (0..2).map(|_| r.word(3, 10)).collect();
            let values: Vec<_> = (0..points).map(|_| r.next_f64() * 100.0).collect();
            Ok(Fixture::Telemetry(Telemetry {
                source: r.word(3, 10),
                ts: BASE_TS_MS + r.next_int(0, 86_400_000) as i64,
                tags,
                values,
            }))
        }
        "strings" => {
            let items: Vec<_> = (0..count).map(|_| r.word(3, 16)).collect();
            Ok(Fixture::Strings(Strings { items }))
        }
        "event" => {
            let attrs: Vec<_> = (0..attr_count)
                .map(|_| EventAttr {
                    key: r.word(3, 12),
                    value: r.word(3, 12),
                })
                .collect();
            Ok(Fixture::Event(Event {
                event_id: r.word(8, 12),
                event_type: r.word(3, 12),
                occurred_at: BASE_TS_MS + r.next_int(0, 86_400_000) as i64,
                producer: r.word(3, 12),
                attrs,
            }))
        }
        other => anyhow::bail!("unknown v2 type_id {other}"),
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
}

impl Fixture {
    /// Catalog type_id: `"message"` | `"document"` | `"telemetry"` | `"strings"` | `"event"`.
    pub fn name(&self) -> &'static str {
        match self {
            Fixture::Message(_) => "message",
            Fixture::Document(_) => "document",
            Fixture::Telemetry(_) => "telemetry",
            Fixture::Strings(_) => "strings",
            Fixture::Event(_) => "event",
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
        _ => false,
    }
}

/// Standard suite samples (one of each V2 type_id).
pub fn all_fixtures(seed: u64) -> Vec<Fixture> {
    ["message", "document", "telemetry", "strings", "event"]
        .iter()
        .map(|tid| {
            make_one(tid, seed, 0, 8, 32, 32, 4)
                .unwrap_or_else(|e| panic!("make_one({tid}): {e}"))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

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
        let a = make_one("message", 42, 0, 8, 32, 32, 4).unwrap();
        assert_eq!(a.name(), "message");
        assert!(fidelity(&a, &a));
    }

    #[test]
    fn make_one_document_has_children() {
        let fx = make_one("document", 7, 1, 5, 32, 32, 4).unwrap();
        match fx {
            Fixture::Document(d) => assert_eq!(d.items.len(), 5),
            _ => panic!("expected document"),
        }
    }

    #[test]
    fn make_one_unknown_errors() {
        assert!(make_one("not-a-suite-type", 1, 0, 1, 1, 1, 1).is_err());
    }
}
