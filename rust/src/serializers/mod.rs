//! Serializer trait and implementations (Python-aligned call-path contract).
//!
//! Timed methods measure encode/decode only. Call `prepare` once per fixture
//! *outside* the timed loop so configs, scratch buffers, and native conversions
//! are not part of the measurement.
//!
//! ## Timing / buffer policy (issue #59)
//!
//! - **Output buffer:** the harness owns a reusable `Vec<u8>`, clears it before
//!   each timed serialize, and passes it to [`BenchSerializer::serialize_into`].
//!   Capacity is reused across repetitions so cold allocation falls into warmup
//!   (rep 0), which analysis drops when `exclude_warmup` is set. Timed work is
//!   encode into that buffer (including amortized growth if capacity is short).
//! - **Optimization barriers:** the harness applies [`std::hint::black_box`] to
//!   inputs and outputs of timed calls so LLVM cannot DCE or hoist work.
//! - **Fixture kind:** direct codecs bind a monomorphic encode/decode fn in
//!   `prepare` so the timed path is not a multi-way `match fixture`.
//!
//! Layout (one family / concern per file, matching Go/Python/C):
//! - [`json`] — serde_json, simd-json, sonic-rs
//! - [`binary_serde`] — rmp-serde, ciborium, bincode, postcard, bitcode, flexbuffers, bson
//! - [`direct`] — minicbor, rkyv, nanoserde, speedy
//! - [`prost_ser`] — prost + fixture conversion
//! - [`avro_ser`] — serde_avro_fast (Avro binary datum)
//! - [`kinded`] — shared kind-tracked direct codec macro

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

// Locked dependency versions from Cargo.lock (build.rs → OUT_DIR/dep_versions.rs).
include!(concat!(env!("OUT_DIR"), "/dep_versions.rs"));

mod avro_ser;
mod binary_serde;
mod direct;
mod json;
mod kinded;
mod prost_ser;
mod yaml;

use avro_ser::AvroFastSer;
use binary_serde::{
    BincodeSer, BitcodeSer, BsonSer, CiboriumSer, FlexbuffersSer, PostcardSer, RmpSerde,
};
use direct::{MinicborDirect, NanoserdeSer, RkyvSer, SpeedySer};
use json::{SerdeJson, SimdJson, SonicRs};
use prost_ser::ProstSer;
use yaml::SerdeYaml;

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

    /// Untimed: build reusable codec state / bind kind-specific encode fns.
    fn prepare(&mut self, fixture: &Fixture) -> Result<()>;

    /// Timed: encode `fixture` into `out` (caller cleared; capacity reused).
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()>;

    /// Timed: deserialize into a `Fixture` for semantic fidelity checks.
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture>;

    /// Convenience for tests: allocate a fresh buffer (not the timed path).
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        let mut out = Vec::with_capacity(4096);
        self.serialize_into(fixture, &mut out)?;
        Ok(out)
    }

    /// Timed stream serialize (default: adapted bytes path into `w`).
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let mut data = Vec::with_capacity(4096);
        self.serialize_into(fixture, &mut data)?;
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
        Box::new(AvroFastSer::default()),
        Box::new(NanoserdeSer::default()),
        Box::new(SpeedySer::default()),
        Box::new(SerdeYaml::default()),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{all_fixtures, fidelity, make_one, Fixture};
    use super::binary_serde::CiboriumSer;
    use super::json::SerdeJson;

    fn roundtrip(ser: &mut dyn BenchSerializer, fx: &Fixture) {
        ser.prepare(fx).expect("prepare");
        let bytes = ser.serialize_bytes(fx).expect("ser");
        assert!(!bytes.is_empty(), "{} empty ser for {}", ser.name(), fx.name());
        let out = ser.deserialize_bytes(&bytes).expect("de");
        assert!(
            fidelity(fx, &out),
            "{} fidelity failed for {}",
            ser.name(),
            fx.name()
        );
    }

    #[test]
    fn all_serializers_roundtrip_all_v2_fixtures() {
        let fixtures = all_fixtures(42);
        assert_eq!(fixtures.len(), 5);
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
    fn all_serializers_support_message() {
        let fx = make_one("message", 42, 0, 8, 32, 32, 4).unwrap();
        let mut ok = 0;
        for mut ser in all_serializers() {
            assert!(
                ser.supports("message"),
                "{} should support message",
                ser.name()
            );
            roundtrip(ser.as_mut(), &fx);
            ok += 1;
        }
        assert_eq!(ok, all_serializers().len());
    }

    #[test]
    fn serialize_into_serde_json_deterministic() {
        let fx = make_one("document", 1, 0, 4, 32, 32, 4).unwrap();
        let mut s = SerdeJson::default();
        s.prepare(&fx).unwrap();
        let mut a = Vec::new();
        s.serialize_into(&fx, &mut a).unwrap();
        let mut b = Vec::new();
        s.serialize_into(&fx, &mut b).unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn serialize_into_reuses_capacity() {
        let fx = make_one("message", 1, 0, 8, 32, 32, 4).unwrap();
        let mut s = SerdeJson::default();
        s.prepare(&fx).unwrap();
        let mut buf = Vec::with_capacity(4096);
        s.serialize_into(&fx, &mut buf).unwrap();
        let cap_after_first = buf.capacity();
        assert!(cap_after_first >= buf.len());
        buf.clear();
        s.serialize_into(&fx, &mut buf).unwrap();
        // clear keeps capacity; second encode must not shrink the allocation.
        assert_eq!(buf.capacity(), cap_after_first);
    }

    #[test]
    fn ciborium_no_empty_and_deterministic() {
        let fx = make_one("message", 1, 0, 8, 32, 32, 4).unwrap();
        let mut s = CiboriumSer::default();
        s.prepare(&fx).unwrap();
        let a = s.serialize_bytes(&fx).unwrap();
        let b = s.serialize_bytes(&fx).unwrap();
        assert_eq!(a, b);
        assert!(!a.is_empty());
    }

    #[test]
    fn fixture_generation_is_deterministic() {
        let a = make_one("telemetry", 42, 0, 8, 32, 32, 4).unwrap();
        let b = make_one("telemetry", 42, 0, 8, 32, 32, 4).unwrap();
        assert_eq!(a, b);
        let c = make_one("telemetry", 42, 1, 8, 32, 32, 4).unwrap();
        assert_ne!(a, c);
    }
}
