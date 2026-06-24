//! Canonical test data models (serde-compatible), aligned with Python/C# fixtures.

use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Gender {
    Male = 0,
    Female = 1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Passport {
    pub number: String,
    pub authority: String,
    pub expiration_date: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PoliceRecord {
    pub id: i32,
    pub crime_code: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Person {
    pub first_name: String,
    pub last_name: String,
    pub age: i32,
    pub gender: Gender,
    pub passport: Option<Passport>,
    pub police_records: Vec<PoliceRecord>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SimpleObject {
    pub id: i32,
    pub name: String,
    pub timestamp: String,
    pub is_active: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StringArrayObject {
    pub items: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TelemetryData {
    pub id: String,
    pub data_source: String,
    pub time_stamp: String,
    pub param1: i32,
    pub param2: i32,
    pub measurements: Vec<f64>,
    pub associated_problem_id: i32,
    pub associated_log_id: i32,
    pub was_processed: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ServiceLine {
    pub service_code: String,
    pub charge_amount: f64,
    pub adjudicated_amount: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Claim {
    pub claim_id: String,
    pub patient_name: String,
    pub total_charge: f64,
    pub payment_amount: f64,
    pub lines: Vec<ServiceLine>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Edi835 {
    pub payer_name: String,
    pub payee_name: String,
    pub payment_date: String,
    pub total_actual_amount: f64,
    pub transaction_control_number: String,
    pub claims: Vec<Claim>,
}

/// Graph node with optional back-reference for cycle tests (JSON/serde may not support).
#[derive(Debug, Clone)]
pub struct GraphNode {
    pub name: String,
    pub children: Vec<Rc<RefCell<GraphNode>>>,
    pub parent: Option<Rc<RefCell<GraphNode>>>,
}

/// Deterministic pseudo-random generator matching seed=42 intent.
pub struct Rng {
    state: u64,
}

impl Rng {
    pub fn new(seed: u64) -> Self {
        Self { state: seed.max(1) }
    }

    fn next_u64(&mut self) -> u64 {
        // xorshift64*
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }

    pub fn next_i32(&mut self, lo: i32, hi: i32) -> i32 {
        if hi <= lo {
            return lo;
        }
        let span = (hi - lo + 1) as u64;
        lo + (self.next_u64() % span) as i32
    }

    pub fn next_f64(&mut self) -> f64 {
        (self.next_u64() as f64) / (u64::MAX as f64)
    }

    pub fn next_bool(&mut self) -> bool {
        self.next_u64() & 1 == 1
    }

    pub fn word(&mut self, min_len: usize, max_len: usize) -> String {
        const POOL: &[u8] = b"abcdefghijklmnopqrstuvwxyz";
        let len = self.next_i32(min_len as i32, max_len as i32) as usize;
        (0..len)
            .map(|_| POOL[(self.next_u64() as usize) % POOL.len()] as char)
            .collect()
    }
}

pub fn make_person(rng: &mut Rng) -> Person {
    let n_records = 5;
    Person {
        first_name: rng.word(3, 10),
        last_name: rng.word(3, 10),
        age: rng.next_i32(1, 99),
        gender: if rng.next_bool() {
            Gender::Male
        } else {
            Gender::Female
        },
        passport: Some(Passport {
            number: rng.word(8, 12),
            authority: rng.word(3, 10),
            expiration_date: "2030-01-01T00:00:00Z".into(),
        }),
        police_records: (0..n_records)
            .map(|i| PoliceRecord {
                id: i,
                crime_code: rng.word(3, 8),
            })
            .collect(),
    }
}

pub fn make_simple(rng: &mut Rng) -> SimpleObject {
    SimpleObject {
        id: rng.next_i32(0, 1_000_000),
        name: rng.word(3, 10),
        timestamp: "2024-01-01T00:00:00Z".into(),
        is_active: rng.next_bool(),
    }
}

pub fn make_string_array(rng: &mut Rng) -> StringArrayObject {
    StringArrayObject {
        items: (0..100).map(|_| rng.word(3, 10)).collect(),
    }
}

pub fn make_telemetry(rng: &mut Rng) -> TelemetryData {
    TelemetryData {
        id: rng.word(8, 12),
        data_source: rng.word(3, 10),
        time_stamp: "2024-01-01T00:00:00Z".into(),
        param1: rng.next_i32(0, 1000),
        param2: rng.next_i32(0, 1000),
        measurements: (0..100).map(|_| rng.next_f64() * 100.0).collect(),
        associated_problem_id: rng.next_i32(0, 10000),
        associated_log_id: rng.next_i32(0, 10000),
        was_processed: rng.next_bool(),
    }
}

pub fn make_edi(rng: &mut Rng) -> Edi835 {
    let mut claims = Vec::new();
    for c in 0..5 {
        let lines: Vec<ServiceLine> = (0..3)
            .map(|_| ServiceLine {
                service_code: rng.word(3, 6),
                charge_amount: rng.next_f64() * 1000.0,
                adjudicated_amount: rng.next_f64() * 1000.0,
            })
            .collect();
        claims.push(Claim {
            claim_id: format!("C{c}"),
            patient_name: rng.word(3, 10),
            total_charge: rng.next_f64() * 5000.0,
            payment_amount: rng.next_f64() * 5000.0,
            lines,
        });
    }
    Edi835 {
        payer_name: rng.word(3, 10),
        payee_name: rng.word(3, 10),
        payment_date: "2024-01-01T00:00:00Z".into(),
        total_actual_amount: rng.next_f64() * 10000.0,
        transaction_control_number: rng.word(8, 12),
        claims,
    }
}

pub fn make_graph() -> Rc<RefCell<GraphNode>> {
    let root = Rc::new(RefCell::new(GraphNode {
        name: "root".into(),
        children: vec![],
        parent: None,
    }));
    let child = Rc::new(RefCell::new(GraphNode {
        name: "child".into(),
        children: vec![],
        parent: Some(Rc::clone(&root)),
    }));
    root.borrow_mut().children.push(Rc::clone(&child));
    root
}

/// Generic value holder for serializers that work on serde values.
/// Externally tagged (default) for compatibility with bincode/postcard/bitcode;
/// JSON/MessagePack still round-trip cleanly for benchmarks.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Fixture {
    Person(Person),
    Integer(i32),
    Telemetry(TelemetryData),
    Simple(SimpleObject),
    StringArray(StringArrayObject),
    Edi(Edi835),
}

impl Fixture {
    pub fn name(&self) -> &'static str {
        match self {
            Fixture::Person(_) => "Person",
            Fixture::Integer(_) => "Integer",
            Fixture::Telemetry(_) => "Telemetry",
            Fixture::Simple(_) => "SimpleObject",
            Fixture::StringArray(_) => "StringArray",
            Fixture::Edi(_) => "EDI_835",
        }
    }
}

pub fn all_fixtures(seed: u64) -> Vec<Fixture> {
    let mut rng = Rng::new(seed);
    vec![
        Fixture::Person(make_person(&mut rng)),
        Fixture::Integer(42),
        Fixture::Telemetry(make_telemetry(&mut rng)),
        Fixture::Simple(make_simple(&mut rng)),
        Fixture::StringArray(make_string_array(&mut rng)),
        Fixture::Edi(make_edi(&mut rng)),
    ]
}
