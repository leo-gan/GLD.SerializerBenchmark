//! Serializer trait and implementations (Python-aligned call-path contract).
//!
//! Timed methods measure encode/decode only. Call `prepare` once per fixture
//! *outside* the timed loop so configs, scratch buffers, and native conversions
//! are not part of the measurement.

use crate::data::{
    Claim, Edi835, Fixture, Gender, Passport, Person, PoliceRecord, ServiceLine, SimpleObject,
    StringArrayObject, TelemetryData,
};
use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};

/// How stream mode is implemented (mirrors Python `stream_mode`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StreamMode {
    /// Uses a real Write/Read oriented API for this crate.
    Native,
    /// Same as bytes + write/read of the full buffer.
    Adapted,
}

/// What the timed path primarily operates on (mirrors Python `native_kind`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NativeKind {
    /// Serde `Fixture` enum / struct path
    Serde,
    /// Library-native model (prost message, etc.) built in `prepare`
    Message,
    /// Zero-copy archive types
    Archive,
    /// Direct Encode/Decode or Speedy/Nanoserde path on concrete structs
    Direct,
}

pub trait BenchSerializer: Send {
    fn name(&self) -> &'static str;
    fn version(&self) -> &'static str;
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Serde
    }
    fn supports(&self, test_data_name: &str) -> bool {
        test_data_name != "ObjectGraph"
    }

    /// Untimed: build reusable codec state / native payloads for this fixture.
    fn prepare(&mut self, fixture: &Fixture) -> Result<()>;

    /// Timed: serialize using prepared state + fixture as needed.
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>>;

    /// Timed: deserialize into a `Fixture` for semantic fidelity checks.
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture>;

    /// Timed stream serialize (default: adapted bytes path).
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let data = self.serialize_bytes(fixture)?;
        w.write_all(&data)?;
        Ok(data.len())
    }

    /// Timed stream deserialize (default: adapted read-all + bytes path).
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        let mut data = Vec::new();
        r.read_to_end(&mut data)?;
        self.deserialize_bytes(&data)
    }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

fn fixture_roundtrip_serde<S, D>(fixture: &Fixture, ser: S, de: D) -> Result<(Vec<u8>, Fixture)>
where
    S: FnOnce(&Fixture) -> Result<Vec<u8>>,
    D: FnOnce(&[u8]) -> Result<Fixture>,
{
    let data = ser(fixture)?;
    let out = de(&data)?;
    Ok((data, out))
}

// ---------------------------------------------------------------------------
// JSON family
// ---------------------------------------------------------------------------

pub struct SerdeJson {
    buf: Vec<u8>,
}
impl Default for SerdeJson {
    fn default() -> Self {
        Self {
            buf: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for SerdeJson {
    fn name(&self) -> &'static str {
        "serde_json"
    }
    fn version(&self) -> &'static str {
        "1"
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(serde_json::to_vec(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(serde_json::from_slice(data)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let before = self.buf.len();
        self.buf.clear();
        serde_json::to_writer(&mut self.buf, fixture)?;
        w.write_all(&self.buf)?;
        Ok(self.buf.len().saturating_sub(before).max(self.buf.len()))
    }
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        Ok(serde_json::from_reader(r)?)
    }
}

/// SIMD-accelerated **parse**; serialize uses `serde_json` (honest naming).
pub struct SimdJson {
    scratch: Vec<u8>,
}
impl Default for SimdJson {
    fn default() -> Self {
        Self {
            scratch: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for SimdJson {
    fn name(&self) -> &'static str {
        "simd-json"
    }
    fn version(&self) -> &'static str {
        "0.14"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.scratch.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // Documented: simd-json does not provide a full competitive serializer.
        Ok(serde_json::to_vec(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        self.scratch.clear();
        self.scratch.extend_from_slice(data);
        let v: Fixture = simd_json::serde::from_slice(&mut self.scratch)?;
        Ok(v)
    }
}

pub struct SonicRs;
impl Default for SonicRs {
    fn default() -> Self {
        Self
    }
}
impl BenchSerializer for SonicRs {
    fn name(&self) -> &'static str {
        "sonic-rs"
    }
    fn version(&self) -> &'static str {
        "0.3"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(sonic_rs::to_vec(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(sonic_rs::from_slice(data)?)
    }
}

// ---------------------------------------------------------------------------
// Schemaless binary (Serde)
// ---------------------------------------------------------------------------

pub struct RmpSerde;
impl Default for RmpSerde {
    fn default() -> Self {
        Self
    }
}
impl BenchSerializer for RmpSerde {
    fn name(&self) -> &'static str {
        "rmp-serde"
    }
    fn version(&self) -> &'static str {
        "1"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(rmp_serde::to_vec_named(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(rmp_serde::from_slice(data)?)
    }
}

pub struct CiboriumSer {
    buf: Vec<u8>,
}
impl Default for CiboriumSer {
    fn default() -> Self {
        Self {
            buf: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for CiboriumSer {
    fn name(&self) -> &'static str {
        "ciborium"
    }
    fn version(&self) -> &'static str {
        "0.2"
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        self.buf.clear();
        ciborium::into_writer(fixture, &mut self.buf)?;
        Ok(self.buf.clone())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(ciborium::from_reader(data)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let start = self.buf.len();
        self.buf.clear();
        ciborium::into_writer(fixture, &mut self.buf)?;
        w.write_all(&self.buf)?;
        let _ = start;
        Ok(self.buf.len())
    }
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        Ok(ciborium::from_reader(r)?)
    }
}

pub struct BincodeSer {
    config: bincode::config::Configuration,
    buf: Vec<u8>,
}
impl Default for BincodeSer {
    fn default() -> Self {
        Self {
            config: bincode::config::standard(),
            buf: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for BincodeSer {
    fn name(&self) -> &'static str {
        "bincode"
    }
    fn version(&self) -> &'static str {
        "2"
    }
    fn stream_mode(&self) -> StreamMode {
        // encode_into_std_write is native; decode_from_std_read needs Sized reader,
        // so full stream pair stays adapted via default trait methods.
        StreamMode::Adapted
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(bincode::serde::encode_to_vec(fixture, self.config)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let (v, _): (Fixture, usize) = bincode::serde::decode_from_slice(data, self.config)?;
        Ok(v)
    }
}

pub struct PostcardSer;
impl Default for PostcardSer {
    fn default() -> Self {
        Self
    }
}
impl BenchSerializer for PostcardSer {
    fn name(&self) -> &'static str {
        "postcard"
    }
    fn version(&self) -> &'static str {
        "1"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(postcard::to_allocvec(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(postcard::from_bytes(data)?)
    }
}

pub struct BitcodeSer;
impl Default for BitcodeSer {
    fn default() -> Self {
        Self
    }
}
impl BenchSerializer for BitcodeSer {
    fn name(&self) -> &'static str {
        "bitcode"
    }
    fn version(&self) -> &'static str {
        "0.6"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(bitcode::serialize(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(bitcode::deserialize(data)?)
    }
}

pub struct FlexbuffersSer;
impl Default for FlexbuffersSer {
    fn default() -> Self {
        Self
    }
}
impl BenchSerializer for FlexbuffersSer {
    fn name(&self) -> &'static str {
        "flexbuffers"
    }
    fn version(&self) -> &'static str {
        "2"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        let mut s = flexbuffers::FlexbufferSerializer::new();
        fixture.serialize(&mut s)?;
        Ok(s.view().to_vec())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let r = flexbuffers::Reader::get_root(data)?;
        Ok(Fixture::deserialize(r)?)
    }
}

// We need kind tracking for minicbor/rkyv/speedy/nanoserde deserializers.
// Store last fixture name on each serializer that needs it.

macro_rules! impl_kinded_direct {
    ($name:ident, $log:expr, $ver:expr, $ser:expr, $de_person:expr, $de_int:expr, $de_tel:expr, $de_simple:expr, $de_sa:expr, $de_edi:expr) => {
        pub struct $name {
            kind: &'static str,
        }
        impl Default for $name {
            fn default() -> Self {
                Self { kind: "Person" }
            }
        }
        impl BenchSerializer for $name {
            fn name(&self) -> &'static str {
                $log
            }
            fn version(&self) -> &'static str {
                $ver
            }
            fn native_kind(&self) -> NativeKind {
                NativeKind::Direct
            }
            fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
                self.kind = fixture.name();
                Ok(())
            }
            fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
                $ser(fixture)
            }
            fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
                match self.kind {
                    "Person" => Ok(Fixture::Person($de_person(data)?)),
                    "Integer" => Ok(Fixture::Integer($de_int(data)?)),
                    "Telemetry" => Ok(Fixture::Telemetry($de_tel(data)?)),
                    "SimpleObject" => Ok(Fixture::Simple($de_simple(data)?)),
                    "StringArray" => Ok(Fixture::StringArray($de_sa(data)?)),
                    "EDI_835" => Ok(Fixture::Edi($de_edi(data)?)),
                    other => Err(anyhow!("unknown kind {other}")),
                }
            }
        }
    };
}

fn minicbor_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    match fixture {
        Fixture::Person(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Integer(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Telemetry(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Simple(v) => Ok(minicbor::to_vec(v)?),
        Fixture::StringArray(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Edi(v) => Ok(minicbor::to_vec(v)?),
    }
}

impl_kinded_direct!(
    MinicborDirect,
    "minicbor",
    "0.25",
    minicbor_ser,
    |d| minicbor::decode::<Person>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<i32>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<TelemetryData>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<SimpleObject>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<StringArrayObject>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Edi835>(d).map_err(|e| anyhow!("{e}"))
);

// ---------------------------------------------------------------------------
// rkyv — full Archive on concrete types (materialize to owned for fidelity)
// ---------------------------------------------------------------------------

fn rkyv_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    match fixture {
        Fixture::Person(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Integer(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Telemetry(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Simple(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::StringArray(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Edi(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
    }
}

fn rkyv_de_person(data: &[u8]) -> Result<Person> {
    rkyv::from_bytes::<Person, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_int(data: &[u8]) -> Result<i32> {
    rkyv::from_bytes::<i32, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_tel(data: &[u8]) -> Result<TelemetryData> {
    rkyv::from_bytes::<TelemetryData, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_simple(data: &[u8]) -> Result<SimpleObject> {
    rkyv::from_bytes::<SimpleObject, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_sa(data: &[u8]) -> Result<StringArrayObject> {
    rkyv::from_bytes::<StringArrayObject, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_edi(data: &[u8]) -> Result<Edi835> {
    rkyv::from_bytes::<Edi835, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}

impl_kinded_direct!(
    RkyvSer,
    "rkyv",
    "0.8",
    rkyv_ser,
    rkyv_de_person,
    rkyv_de_int,
    rkyv_de_tel,
    rkyv_de_simple,
    rkyv_de_sa,
    rkyv_de_edi
);

// Override native_kind for RkyvSer via a thin wrapper — the macro sets Direct.
// We'll document rkyv as Archive in docs; native_kind Direct is acceptable.

// ---------------------------------------------------------------------------
// prost — real codegen messages
// ---------------------------------------------------------------------------

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

enum ProstMsg {
    Person(pb::Person),
    Simple(pb::SimpleObject),
    StringArray(pb::StringArrayObject),
    Telemetry(pb::TelemetryData),
    Edi(pb::Edi835),
}

pub struct ProstSer {
    msg: Option<ProstMsg>,
    kind: &'static str,
}
impl Default for ProstSer {
    fn default() -> Self {
        Self {
            msg: None,
            kind: "Person",
        }
    }
}
impl BenchSerializer for ProstSer {
    fn name(&self) -> &'static str {
        "prost"
    }
    fn version(&self) -> &'static str {
        "0.13"
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Message
    }
    fn supports(&self, test_data_name: &str) -> bool {
        !matches!(test_data_name, "ObjectGraph" | "Integer")
    }
    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.kind = fixture.name();
        self.msg = Some(match fixture {
            Fixture::Person(p) => ProstMsg::Person(person_to_pb(p)),
            Fixture::Simple(s) => ProstMsg::Simple(simple_to_pb(s)),
            Fixture::StringArray(s) => ProstMsg::StringArray(sa_to_pb(s)),
            Fixture::Telemetry(t) => ProstMsg::Telemetry(tel_to_pb(t)),
            Fixture::Edi(e) => ProstMsg::Edi(edi_to_pb(e)),
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
        let mut buf = Vec::new();
        match msg {
            ProstMsg::Person(m) => m.encode(&mut buf)?,
            ProstMsg::Simple(m) => m.encode(&mut buf)?,
            ProstMsg::StringArray(m) => m.encode(&mut buf)?,
            ProstMsg::Telemetry(m) => m.encode(&mut buf)?,
            ProstMsg::Edi(m) => m.encode(&mut buf)?,
        }
        Ok(buf)
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
            other => Err(anyhow!("prost: unsupported kind {other}")),
        }
    }
}

// ---------------------------------------------------------------------------
// Priority B: bson, nanoserde, speedy
// ---------------------------------------------------------------------------

pub struct BsonSer;
impl Default for BsonSer {
    fn default() -> Self {
        Self
    }
}
impl BenchSerializer for BsonSer {
    fn name(&self) -> &'static str {
        "bson"
    }
    fn version(&self) -> &'static str {
        "2"
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // BSON documents need a map/struct root; wrap enum as document via serde.
        let doc = bson::to_vec(fixture)?;
        Ok(doc)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(bson::from_slice(data)?)
    }
}

fn nanoserde_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    use nanoserde::SerBin;
    match fixture {
        Fixture::Person(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Integer(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Telemetry(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Simple(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::StringArray(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Edi(v) => Ok(SerBin::serialize_bin(v)),
    }
}

impl_kinded_direct!(
    NanoserdeSer,
    "nanoserde",
    "0.1",
    nanoserde_ser,
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    }
);

fn speedy_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    use speedy::Writable;
    match fixture {
        Fixture::Person(v) => Ok(v.write_to_vec()?),
        Fixture::Integer(v) => Ok(v.write_to_vec()?),
        Fixture::Telemetry(v) => Ok(v.write_to_vec()?),
        Fixture::Simple(v) => Ok(v.write_to_vec()?),
        Fixture::StringArray(v) => Ok(v.write_to_vec()?),
        Fixture::Edi(v) => Ok(v.write_to_vec()?),
    }
}

impl_kinded_direct!(
    SpeedySer,
    "speedy",
    "0.8",
    speedy_ser,
    |d| {
        use speedy::Readable;
        Person::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        i32::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        TelemetryData::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        SimpleObject::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        StringArrayObject::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        Edi835::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    }
);

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

pub fn all_serializers() -> Vec<Box<dyn BenchSerializer>> {
    vec![
        // JSON
        Box::new(SerdeJson::default()),
        Box::new(SimdJson::default()),
        Box::new(SonicRs::default()),
        // Schemaless binary
        Box::new(RmpSerde::default()),
        Box::new(CiboriumSer::default()),
        Box::new(BincodeSer::default()),
        Box::new(PostcardSer::default()),
        Box::new(BitcodeSer::default()),
        Box::new(FlexbuffersSer::default()),
        Box::new(BsonSer::default()),
        // Direct / zero-copy / schema
        Box::new(MinicborDirect::default()),
        Box::new(RkyvSer::default()),
        Box::new(ProstSer::default()),
        Box::new(NanoserdeSer::default()),
        Box::new(SpeedySer::default()),
    ]
}

