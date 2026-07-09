//! Serializer trait and implementations (Python-aligned call-path contract).
//!
//! Timed methods measure encode/decode only. Call `prepare` once per fixture
//! *outside* the timed loop so configs, scratch buffers, and native conversions
//! are not part of the measurement.
//!
//! Layout (one family / concern per file, matching Go/Python/C):
//! - [`json`] — serde_json, simd-json, sonic-rs
//! - [`binary_serde`] — rmp-serde, ciborium, bincode, postcard, bitcode, flexbuffers, bson
//! - [`direct`] — minicbor, rkyv, nanoserde, speedy
//! - [`prost_ser`] — prost + fixture conversion
//! - [`kinded`] — shared macro for kind-tracked direct codecs

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

// Locked dependency versions from Cargo.lock (build.rs → OUT_DIR/dep_versions.rs).
include!(concat!(env!("OUT_DIR"), "/dep_versions.rs"));

mod binary_serde;
mod direct;
mod json;
mod kinded;
mod prost_ser;

use binary_serde::{
    BincodeSer, BitcodeSer, BsonSer, CiboriumSer, FlexbuffersSer, PostcardSer, RmpSerde,
};
use direct::{MinicborDirect, NanoserdeSer, RkyvSer, SpeedySer};
use json::{SerdeJson, SimdJson, SonicRs};
use prost_ser::ProstSer;

#[inline]
pub(crate) fn ver(crate_name: &str) -> &'static str {
    crate_version(crate_name)
}

/// Counts bytes written while forwarding to an inner Write (for stream size reporting).
pub(crate) struct CountWrite<'a> {
    pub inner: &'a mut dyn Write,
    pub n: usize,
}
impl Write for CountWrite<'_> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let n = self.inner.write(buf)?;
        self.n += n;
        Ok(n)
    }
    fn flush(&mut self) -> std::io::Result<()> {
        self.inner.flush()
    }
}

/// Move filled buffer out for return while re-arming `slot` with equal capacity
/// so the next encode reuses the allocation (mem::take alone drops capacity).
#[inline]
pub(crate) fn take_rearm(slot: &mut Vec<u8>) -> Vec<u8> {
    let out = std::mem::take(slot);
    let cap = out.capacity().max(4096);
    *slot = Vec::with_capacity(cap);
    out
}

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
    fn supports(&self, _test_data_name: &str) -> bool {
        true
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{all_fixtures, make_object_graph, object_graph_fidelity, Fixture};
    use super::binary_serde::CiboriumSer;
    use super::json::SerdeJson;

    fn approx_eq(a: &Fixture, b: &Fixture) -> bool {
        if a == b {
            return true;
        }
        // Match harness fidelity (main.rs): allow prost date ms round-trip drift
        // and float noise from JSON codecs.
        match (a, b) {
            (Fixture::ObjectGraph(x), Fixture::ObjectGraph(y)) => object_graph_fidelity(x, y),
            (Fixture::Integer(x), Fixture::Integer(y)) => x == y,
            (Fixture::Person(x), Fixture::Person(y)) => {
                x.first_name == y.first_name
                    && x.last_name == y.last_name
                    && x.age == y.age
                    && x.gender == y.gender
                    && x.police_records == y.police_records
                    && x.passport.as_ref().map(|p| (&p.number, &p.authority))
                        == y.passport.as_ref().map(|p| (&p.number, &p.authority))
            }
            (Fixture::Simple(x), Fixture::Simple(y)) => {
                x.id == y.id && x.name == y.name && x.is_active == y.is_active
            }
            (Fixture::StringArray(x), Fixture::StringArray(y)) => x.items == y.items,
            (Fixture::Telemetry(x), Fixture::Telemetry(y)) => {
                x.id == y.id
                    && x.param1 == y.param1
                    && x.measurements.len() == y.measurements.len()
                    && x.measurements
                        .iter()
                        .zip(y.measurements.iter())
                        .all(|(p, q)| (p - q).abs() < 1e-9)
            }
            (Fixture::Edi(x), Fixture::Edi(y)) => {
                x.payer_name == y.payer_name
                    && x.payee_name == y.payee_name
                    && x.claims.len() == y.claims.len()
                    && (x.total_actual_amount - y.total_actual_amount).abs() < 1e-6
            }
            _ => false,
        }
    }

    fn roundtrip(ser: &mut dyn BenchSerializer, fx: &Fixture) {
        ser.prepare(fx).expect("prepare");
        let bytes = ser.serialize_bytes(fx).expect("ser");
        assert!(!bytes.is_empty(), "{} empty ser for {}", ser.name(), fx.name());
        let out = ser.deserialize_bytes(&bytes).expect("de");
        assert!(
            approx_eq(fx, &out),
            "{} fidelity failed for {}",
            ser.name(),
            fx.name()
        );
    }

    #[test]
    fn all_serializers_roundtrip_all_fixtures() {
        let fixtures = all_fixtures(42);
        for mut ser in all_serializers() {
            for fx in &fixtures {
                if !ser.supports(fx.name()) {
                    continue;
                }
                roundtrip(ser.as_mut(), fx);
            }
        }
    }

    #[test]
    fn all_serializers_support_object_graph() {
        let g = Fixture::ObjectGraph(make_object_graph());
        let mut ok = 0;
        for mut ser in all_serializers() {
            assert!(
                ser.supports("ObjectGraph") || ser.name() == "prost" && false,
                "{} should support ObjectGraph (or only Integer exclusion for prost)",
                ser.name()
            );
            // prost supports ObjectGraph; only Integer is excluded
            if ser.name() == "prost" {
                assert!(!ser.supports("Integer"));
                assert!(ser.supports("ObjectGraph"));
            }
            if ser.supports(g.name()) {
                roundtrip(ser.as_mut(), &g);
                ok += 1;
            }
        }
        assert_eq!(ok, all_serializers().len());
    }

    #[test]
    fn buffer_reuse_serde_json_deterministic() {
        let fx = Fixture::ObjectGraph(make_object_graph());
        let mut s = SerdeJson::default();
        s.prepare(&fx).unwrap();
        let a = s.serialize_bytes(&fx).unwrap();
        s.prepare(&fx).unwrap();
        let b = s.serialize_bytes(&fx).unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn ciborium_no_empty_and_deterministic() {
        let fx = Fixture::Simple(crate::data::make_simple(&mut crate::data::Rng::new(1)));
        let mut s = CiboriumSer::default();
        s.prepare(&fx).unwrap();
        let a = s.serialize_bytes(&fx).unwrap();
        s.prepare(&fx).unwrap();
        let b = s.serialize_bytes(&fx).unwrap();
        assert_eq!(a, b);
        assert!(!a.is_empty());
    }
}
