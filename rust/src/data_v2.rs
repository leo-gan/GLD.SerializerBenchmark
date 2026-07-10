//! Data Model v2 generators (within-language deterministic).
//! Cross-language payload identity is not required.
//! Wire via BENCHMARK_DATA_MODEL=v2 when the runner supports it.

#![allow(dead_code)]

use serde::{Deserialize, Serialize};

const BASE_TS_MS: i64 = 1_704_067_200_000;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Message {
    pub f_bool: bool,
    pub f_int32: i32,
    pub f_int64: i64,
    pub f_float64: f64,
    pub f_string: String,
    pub f_bool_2: bool,
    pub f_int32_2: i32,
    pub f_string_2: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DocumentMeta {
    pub region: String,
    pub version: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DocumentItem {
    pub sku: String,
    pub qty: i32,
    pub price_minor: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Document {
    pub id: String,
    pub status: i32,
    pub meta: DocumentMeta,
    pub items: Vec<DocumentItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Telemetry {
    pub source: String,
    pub ts: i64,
    pub tags: Vec<String>,
    pub values: Vec<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Strings {
    pub items: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EventAttr {
    pub key: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Event {
    pub event_id: String,
    pub event_type: String,
    pub occurred_at: i64,
    pub producer: String,
    pub attrs: Vec<EventAttr>,
}

struct Rng { state: u64 }

impl Rng {
    fn new(seed: u64) -> Self {
        Self { state: if seed == 0 { 0x9E3779B97F4A7C15 } else { seed } }
    }
    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }
    fn next_int(&mut self, lo: i32, hi: i32) -> i32 {
        if hi <= lo { return lo; }
        lo + (self.next_u64() % (hi - lo + 1) as u64) as i32
    }
    fn next_bool(&mut self) -> bool { self.next_u64() & 1 == 1 }
    fn next_f64(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 / ((1u64 << 53) as f64)
    }
    fn word(&mut self, min_l: usize, max_l: usize) -> String {
        let n = self.next_int(min_l as i32, max_l as i32) as usize;
        const A: &[u8] = b"abcdefghijklmnopqrstuvwxyz";
        (0..n).map(|_| A[(self.next_u64() % 26) as usize] as char).collect()
    }
}

fn mix_seed(seed: u64, type_id: &str, idx: i32) -> u64 {
    let mut h = seed;
    for b in type_id.bytes() {
        h = (h ^ b as u64).wrapping_mul(0x100000001B3);
    }
    h ^= (idx as u64).wrapping_mul(0x9E3779B97F4A7C15);
    if h == 0 { 1 } else { h }
}

/// Build one instance. `children`/`points`/`count`/`attr_count` from type_config defaults.
pub fn make_one(type_id: &str, seed: u64, instance_index: i32, children: i32, points: i32, count: i32, attr_count: i32) -> serde_json::Value {
    let mut r = Rng::new(mix_seed(seed, type_id, instance_index));
    match type_id {
        "message" => serde_json::to_value(Message {
            f_bool: r.next_bool(),
            f_int32: r.next_int(0, 1_000_000),
            f_int64: r.next_int(0, 1_000_000) as i64,
            f_float64: r.next_f64() * 1000.0,
            f_string: r.word(3, 16),
            f_bool_2: r.next_bool(),
            f_int32_2: r.next_int(0, 1_000_000),
            f_string_2: r.word(3, 16),
        }).unwrap(),
        "document" => {
            let items: Vec<_> = (0..children).map(|_| DocumentItem {
                sku: r.word(3, 12), qty: r.next_int(1, 100), price_minor: r.next_int(0, 100_000) as i64,
            }).collect();
            serde_json::to_value(Document {
                id: r.word(8, 12), status: r.next_int(0, 5),
                meta: DocumentMeta { region: r.word(2, 4), version: r.next_int(1, 10) },
                items,
            }).unwrap()
        }
        "telemetry" => {
            let tags: Vec<_> = (0..2).map(|_| r.word(3, 10)).collect();
            let values: Vec<_> = (0..points).map(|_| r.next_f64() * 100.0).collect();
            serde_json::to_value(Telemetry {
                source: r.word(3, 10), ts: BASE_TS_MS + r.next_int(0, 86_400_000) as i64,
                tags, values,
            }).unwrap()
        }
        "strings" => {
            let items: Vec<_> = (0..count).map(|_| r.word(3, 16)).collect();
            serde_json::to_value(Strings { items }).unwrap()
        }
        "event" => {
            let attrs: Vec<_> = (0..attr_count).map(|_| EventAttr {
                key: r.word(3, 12), value: r.word(3, 12),
            }).collect();
            serde_json::to_value(Event {
                event_id: r.word(8, 12), event_type: r.word(3, 12),
                occurred_at: BASE_TS_MS + r.next_int(0, 86_400_000) as i64,
                producer: r.word(3, 12), attrs,
            }).unwrap()
        }
        _ => serde_json::Value::Null,
    }
}
