//! Canonical test data models, aligned with Python/C# fixtures.
//! Multiple derive stacks co-exist so each serializer can use its native path.

use minicbor::{Decode, Encode};
use nanoserde::{DeBin, SerBin};
use rkyv::{Archive, Deserialize as RkyvDeserialize, Serialize as RkyvSerialize};
use serde::{Deserialize, Serialize};
use speedy::{Readable, Writable};

/// Null edge index for ObjectGraph (matches C harness `GRAPH_NULL_IDX`).
pub const GRAPH_NULL: i32 = -1;

#[derive(
    Debug,
    Clone,
    Copy,
    PartialEq,
    Eq,
    Serialize,
    Deserialize,
    Archive,
    RkyvSerialize,
    RkyvDeserialize,
    Encode,
    Decode,
    Readable,
    Writable,
)]
#[rkyv(derive(Debug))]
#[repr(u8)]
pub enum Gender {
    #[n(0)]
    Male = 0,
    #[n(1)]
    Female = 1,
}

impl nanoserde::SerBin for Gender {
    fn ser_bin(&self, output: &mut Vec<u8>) {
        (*self as u8).ser_bin(output);
    }
}

impl nanoserde::DeBin for Gender {
    fn de_bin(offset: &mut usize, bytes: &[u8]) -> Result<Self, nanoserde::DeBinErr> {
        let v = u8::de_bin(offset, bytes)?;
        match v {
            0 => Ok(Gender::Male),
            1 => Ok(Gender::Female),
            _ => Err(nanoserde::DeBinErr {
                o: *offset,
                l: 1,
                s: bytes.len(),
            }),
        }
    }
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
pub struct Passport {
    #[n(0)]
    pub number: String,
    #[n(1)]
    pub authority: String,
    #[n(2)]
    pub expiration_date: String,
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
pub struct PoliceRecord {
    #[n(0)]
    pub id: i32,
    #[n(1)]
    pub crime_code: String,
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
pub struct Person {
    #[n(0)]
    pub first_name: String,
    #[n(1)]
    pub last_name: String,
    #[n(2)]
    pub age: i32,
    #[n(3)]
    pub gender: Gender,
    #[n(4)]
    pub passport: Option<Passport>,
    #[n(5)]
    pub police_records: Vec<PoliceRecord>,
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
pub struct SimpleObject {
    #[n(0)]
    pub id: i32,
    #[n(1)]
    pub name: String,
    #[n(2)]
    pub timestamp: String,
    #[n(3)]
    pub is_active: bool,
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
pub struct StringArrayObject {
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
pub struct TelemetryData {
    #[n(0)]
    pub id: String,
    #[n(1)]
    pub data_source: String,
    #[n(2)]
    pub time_stamp: String,
    #[n(3)]
    pub param1: i32,
    #[n(4)]
    pub param2: i32,
    #[n(5)]
    pub measurements: Vec<f64>,
    #[n(6)]
    pub associated_problem_id: i32,
    #[n(7)]
    pub associated_log_id: i32,
    #[n(8)]
    pub was_processed: bool,
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
pub struct ServiceLine {
    #[n(0)]
    pub service_code: String,
    #[n(1)]
    pub charge_amount: f64,
    #[n(2)]
    pub adjudicated_amount: f64,
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
pub struct Claim {
    #[n(0)]
    pub claim_id: String,
    #[n(1)]
    pub patient_name: String,
    #[n(2)]
    pub total_charge: f64,
    #[n(3)]
    pub payment_amount: f64,
    #[n(4)]
    pub lines: Vec<ServiceLine>,
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
pub struct Edi835 {
    #[n(0)]
    pub payer_name: String,
    #[n(1)]
    pub payee_name: String,
    #[n(2)]
    pub payment_date: String,
    #[n(3)]
    pub total_actual_amount: f64,
    #[n(4)]
    pub transaction_control_number: String,
    #[n(5)]
    pub claims: Vec<Claim>,
}

/// One node in a flat ObjectGraph. Edges are **indices into `ObjectGraph.nodes`**
/// (`GRAPH_NULL` = no edge). This is the portable cycle encoding used by every
/// format: no live pointer chasing, no infinite recursion.
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
pub struct GraphNodeData {
    #[n(0)]
    pub name: String,
    /// Parent node index, or `GRAPH_NULL`.
    #[n(1)]
    pub parent: i32,
    /// Related node index, or `GRAPH_NULL`.
    #[n(2)]
    pub related: i32,
    /// Child node indices.
    #[n(3)]
    pub children: Vec<i32>,
}

/// Object graph with circular references encoded via integer edges.
/// Topology matches C#/Python: Root → Child1, Child2; Child1.Related ↔ Child2.
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
pub struct ObjectGraph {
    #[n(0)]
    pub root: i32,
    #[n(1)]
    pub nodes: Vec<GraphNodeData>,
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

/// Same topology as C# `ObjectGraphDescription` / Python `generate_object_graph`.
pub fn make_object_graph() -> ObjectGraph {
    ObjectGraph {
        root: 0,
        nodes: vec![
            GraphNodeData {
                name: "Root".into(),
                parent: GRAPH_NULL,
                related: GRAPH_NULL,
                children: vec![1, 2],
            },
            GraphNodeData {
                name: "Child1".into(),
                parent: 0,
                related: 2,
                children: vec![],
            },
            GraphNodeData {
                name: "Child2".into(),
                parent: 0,
                related: 1,
                children: vec![],
            },
        ],
    }
}

/// Holder for harness fixtures (externally tagged for Serde formats).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Fixture {
    Person(Person),
    Integer(i32),
    Telemetry(TelemetryData),
    Simple(SimpleObject),
    StringArray(StringArrayObject),
    Edi(Edi835),
    ObjectGraph(ObjectGraph),
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
            Fixture::ObjectGraph(_) => "ObjectGraph",
        }
    }
}

/// Structural fidelity for ObjectGraph (names + index edges + sibling cycle).
pub fn object_graph_fidelity(a: &ObjectGraph, b: &ObjectGraph) -> bool {
    if a.root != b.root || a.nodes.len() != b.nodes.len() {
        return false;
    }
    if a.nodes.is_empty() {
        return true;
    }
    if a.root < 0 || a.root as usize >= a.nodes.len() {
        return false;
    }
    for (na, nb) in a.nodes.iter().zip(b.nodes.iter()) {
        if na.name != nb.name
            || na.parent != nb.parent
            || na.related != nb.related
            || na.children != nb.children
        {
            return false;
        }
    }
    // Sibling cycle on the standard fixture (Root with ≥2 children).
    let root = &a.nodes[a.root as usize];
    if root.children.len() >= 2 {
        let i1 = root.children[0] as usize;
        let i2 = root.children[1] as usize;
        if i1 >= a.nodes.len() || i2 >= a.nodes.len() {
            return false;
        }
        if a.nodes[i1].parent != a.root || a.nodes[i2].parent != a.root {
            return false;
        }
        if a.nodes[i1].related != root.children[1] || a.nodes[i2].related != root.children[0] {
            return false;
        }
    }
    true
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
        Fixture::ObjectGraph(make_object_graph()),
    ]
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn object_graph_topology() {
        let g = make_object_graph();
        assert_eq!(g.root, 0);
        assert_eq!(g.nodes.len(), 3);
        assert_eq!(g.nodes[0].name, "Root");
        assert_eq!(g.nodes[0].children, vec![1, 2]);
        assert_eq!(g.nodes[1].parent, 0);
        assert_eq!(g.nodes[1].related, 2);
        assert_eq!(g.nodes[2].related, 1);
        assert!(object_graph_fidelity(&g, &g));
    }

    #[test]
    fn all_fixtures_include_object_graph() {
        let names: Vec<_> = all_fixtures(42).iter().map(|f| f.name()).collect();
        assert!(names.contains(&"ObjectGraph"));
        assert_eq!(names.len(), 7);
    }
}
