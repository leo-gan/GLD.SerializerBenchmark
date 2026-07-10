//! prost (protobuf) path: shared .proto messages + local flat ObjectGraph.

use crate::data::{
    Claim, Edi835, Fixture, Gender, GraphNodeData, ObjectGraph, Passport, Person, PoliceRecord,
    ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
};
use anyhow::{anyhow, Result};

use super::{take_rearm, ver, BenchSerializer, NativeKind};

pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/benchmark_data.rs"));
}

fn parse_dt_ms(s: &str) -> i64 {
    // Fixtures use ISO strings; map to a stable ms for proto int64 fields.
    // Prefer chrono parse; fall back to 0.
    chrono::DateTime::parse_from_rfc3339(s)
        .map(|d| d.timestamp_millis())
        .or_else(|_| {
            chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%dT%H:%M:%SZ")
                .map(|n| n.and_utc().timestamp_millis())
        })
        .unwrap_or(0)
}

fn person_to_pb(p: &Person) -> pb::Person {
    pb::Person {
        first_name: p.first_name.clone(),
        last_name: p.last_name.clone(),
        age: p.age as u32,
        gender: match p.gender {
            Gender::Male => pb::Gender::Male as i32,
            Gender::Female => pb::Gender::Female as i32,
        },
        passport: p.passport.as_ref().map(|x| pb::Passport {
            number: x.number.clone(),
            authority: x.authority.clone(),
            expiration_date: parse_dt_ms(&x.expiration_date),
        }),
        police_records: p
            .police_records
            .iter()
            .map(|r| pb::PoliceRecord {
                id: r.id,
                crime_code: r.crime_code.clone(),
            })
            .collect(),
    }
}

fn person_from_pb(p: pb::Person) -> Person {
    Person {
        first_name: p.first_name,
        last_name: p.last_name,
        age: p.age as i32,
        gender: if p.gender == pb::Gender::Female as i32 {
            Gender::Female
        } else {
            Gender::Male
        },
        passport: p.passport.map(|x| Passport {
            number: x.number,
            authority: x.authority,
            expiration_date: chrono::DateTime::from_timestamp_millis(x.expiration_date)
                .map(|d| d.to_rfc3339())
                .unwrap_or_else(|| "1970-01-01T00:00:00Z".into()),
        }),
        police_records: p
            .police_records
            .into_iter()
            .map(|r| PoliceRecord {
                id: r.id,
                crime_code: r.crime_code,
            })
            .collect(),
    }
}

fn simple_to_pb(s: &SimpleObject) -> pb::SimpleObject {
    pb::SimpleObject {
        id: s.id,
        name: s.name.clone(),
        timestamp: parse_dt_ms(&s.timestamp),
        is_active: s.is_active,
    }
}
fn simple_from_pb(s: pb::SimpleObject) -> SimpleObject {
    SimpleObject {
        id: s.id,
        name: s.name,
        timestamp: chrono::DateTime::from_timestamp_millis(s.timestamp)
            .map(|d| d.to_rfc3339())
            .unwrap_or_else(|| "1970-01-01T00:00:00Z".into()),
        is_active: s.is_active,
    }
}

fn sa_to_pb(s: &StringArrayObject) -> pb::StringArrayObject {
    pb::StringArrayObject {
        items: s.items.clone(),
    }
}
fn sa_from_pb(s: pb::StringArrayObject) -> StringArrayObject {
    StringArrayObject { items: s.items }
}

fn tel_to_pb(t: &TelemetryData) -> pb::TelemetryData {
    pb::TelemetryData {
        id: t.id.clone(),
        data_source: t.data_source.clone(),
        time_stamp: parse_dt_ms(&t.time_stamp),
        param1: t.param1,
        param2: t.param2 as u32,
        measurements: t.measurements.clone(),
        associated_problem_id: t.associated_problem_id as i64,
        associated_log_id: t.associated_log_id as i64,
        was_processed: t.was_processed,
    }
}
fn tel_from_pb(t: pb::TelemetryData) -> TelemetryData {
    TelemetryData {
        id: t.id,
        data_source: t.data_source,
        time_stamp: chrono::DateTime::from_timestamp_millis(t.time_stamp)
            .map(|d| d.to_rfc3339())
            .unwrap_or_else(|| "1970-01-01T00:00:00Z".into()),
        param1: t.param1,
        param2: t.param2 as i32,
        measurements: t.measurements,
        associated_problem_id: t.associated_problem_id as i32,
        associated_log_id: t.associated_log_id as i32,
        was_processed: t.was_processed,
    }
}

fn edi_to_pb(e: &Edi835) -> pb::Edi835 {
    pb::Edi835 {
        payer_name: e.payer_name.clone(),
        payee_name: e.payee_name.clone(),
        payment_date: parse_dt_ms(&e.payment_date),
        total_actual_amount: e.total_actual_amount,
        transaction_control_number: e.transaction_control_number.clone(),
        claims: e
            .claims
            .iter()
            .map(|c| pb::Claim {
                claim_id: c.claim_id.clone(),
                patient_name: c.patient_name.clone(),
                total_charge: c.total_charge,
                payment_amount: c.payment_amount,
                lines: c
                    .lines
                    .iter()
                    .map(|l| pb::ServiceLine {
                        service_code: l.service_code.clone(),
                        charge_amount: l.charge_amount,
                        adjudicated_amount: l.adjudicated_amount,
                    })
                    .collect(),
            })
            .collect(),
    }
}
fn edi_from_pb(e: pb::Edi835) -> Edi835 {
    Edi835 {
        payer_name: e.payer_name,
        payee_name: e.payee_name,
        payment_date: chrono::DateTime::from_timestamp_millis(e.payment_date)
            .map(|d| d.to_rfc3339())
            .unwrap_or_else(|| "1970-01-01T00:00:00Z".into()),
        total_actual_amount: e.total_actual_amount,
        transaction_control_number: e.transaction_control_number,
        claims: e
            .claims
            .into_iter()
            .map(|c| Claim {
                claim_id: c.claim_id,
                patient_name: c.patient_name,
                total_charge: c.total_charge,
                payment_amount: c.payment_amount,
                lines: c
                    .lines
                    .into_iter()
                    .map(|l| ServiceLine {
                        service_code: l.service_code,
                        charge_amount: l.charge_amount,
                        adjudicated_amount: l.adjudicated_amount,
                    })
                    .collect(),
            })
            .collect(),
    }
}

/// Local flat graph messages (shared .proto GraphNode is recursive without identity).
/// Index edges enable ObjectGraph cycles on the prost path without schema churn.
#[derive(Clone, PartialEq, prost::Message)]
struct FlatGraphNode {
    #[prost(string, tag = "1")]
    name: String,
    #[prost(int32, tag = "2")]
    parent: i32,
    #[prost(int32, tag = "3")]
    related: i32,
    #[prost(int32, repeated, tag = "4")]
    children: Vec<i32>,
}

#[derive(Clone, PartialEq, prost::Message)]
struct FlatObjectGraph {
    #[prost(int32, tag = "1")]
    root: i32,
    #[prost(message, repeated, tag = "2")]
    nodes: Vec<FlatGraphNode>,
}

fn graph_to_flat(g: &ObjectGraph) -> FlatObjectGraph {
    FlatObjectGraph {
        root: g.root,
        nodes: g
            .nodes
            .iter()
            .map(|n| FlatGraphNode {
                name: n.name.clone(),
                parent: n.parent,
                related: n.related,
                children: n.children.clone(),
            })
            .collect(),
    }
}

fn graph_from_flat(g: FlatObjectGraph) -> ObjectGraph {
    ObjectGraph {
        root: g.root,
        nodes: g
            .nodes
            .into_iter()
            .map(|n| GraphNodeData {
                name: n.name,
                parent: n.parent,
                related: n.related,
                children: n.children,
            })
            .collect(),
    }
}

enum ProstMsg {
    Person(pb::Person),
    Simple(pb::SimpleObject),
    StringArray(pb::StringArrayObject),
    Telemetry(pb::TelemetryData),
    Edi(pb::Edi835),
    ObjectGraph(FlatObjectGraph),
}

pub struct ProstSer {
    msg: Option<ProstMsg>,
    kind: &'static str,
    buf: Vec<u8>,
}
impl Default for ProstSer {
    fn default() -> Self {
        Self {
            msg: None,
            kind: "Person",
            buf: Vec::with_capacity(4096),
        }
    }
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
        // Shared schema has no bare Integer wrapper message.
        test_data_name != "Integer"
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.kind = fixture.name();
        self.msg = Some(match fixture {
            Fixture::Person(p) => ProstMsg::Person(person_to_pb(p)),
            Fixture::Simple(s) => ProstMsg::Simple(simple_to_pb(s)),
            Fixture::StringArray(s) => ProstMsg::StringArray(sa_to_pb(s)),
            Fixture::Telemetry(t) => ProstMsg::Telemetry(tel_to_pb(t)),
            Fixture::Edi(e) => ProstMsg::Edi(edi_to_pb(e)),
            Fixture::ObjectGraph(g) => ProstMsg::ObjectGraph(graph_to_flat(g)),
            Fixture::Integer(_) => return Err(anyhow!("prost does not support bare Integer")),
        });
        Ok(())
    }
    fn serialize_bytes(&mut self, _: &Fixture) -> Result<Vec<u8>> {
        use prost::Message;
        let msg = self
            .msg
            .as_ref()
            .ok_or_else(|| anyhow!("prost: prepare() required"))?;
        // Optimal: pre-size with encoded_len, reuse buffer (encode_to_vec always allocs).
        let len = match msg {
            ProstMsg::Person(m) => m.encoded_len(),
            ProstMsg::Simple(m) => m.encoded_len(),
            ProstMsg::StringArray(m) => m.encoded_len(),
            ProstMsg::Telemetry(m) => m.encoded_len(),
            ProstMsg::Edi(m) => m.encoded_len(),
            ProstMsg::ObjectGraph(m) => m.encoded_len(),
        };
        self.buf.clear();
        self.buf.reserve(len);
        match msg {
            ProstMsg::Person(m) => m.encode(&mut self.buf)?,
            ProstMsg::Simple(m) => m.encode(&mut self.buf)?,
            ProstMsg::StringArray(m) => m.encode(&mut self.buf)?,
            ProstMsg::Telemetry(m) => m.encode(&mut self.buf)?,
            ProstMsg::Edi(m) => m.encode(&mut self.buf)?,
            ProstMsg::ObjectGraph(m) => m.encode(&mut self.buf)?,
        }
        Ok(take_rearm(&mut self.buf))
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        use prost::Message;
        match self.kind {
            "Person" => {
                let m = pb::Person::decode(data)?;
                Ok(Fixture::Person(person_from_pb(m)))
            }
            "SimpleObject" => {
                let m = pb::SimpleObject::decode(data)?;
                Ok(Fixture::Simple(simple_from_pb(m)))
            }
            "StringArray" => {
                let m = pb::StringArrayObject::decode(data)?;
                Ok(Fixture::StringArray(sa_from_pb(m)))
            }
            "Telemetry" => {
                let m = pb::TelemetryData::decode(data)?;
                Ok(Fixture::Telemetry(tel_from_pb(m)))
            }
            "EDI_835" => {
                let m = pb::Edi835::decode(data)?;
                Ok(Fixture::Edi(edi_from_pb(m)))
            }
            "ObjectGraph" => {
                let m = FlatObjectGraph::decode(data)?;
                Ok(Fixture::ObjectGraph(graph_from_flat(m)))
            }
            other => Err(anyhow!("prost: unsupported kind {other}")),
        }
    }
}
