//! JSON family: serde_json, simd-json, sonic-rs.

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

use super::{ver, BenchSerializer, CountWrite, StreamMode};

#[derive(Default)]
pub struct SerdeJson;

impl BenchSerializer for SerdeJson {
    fn name(&self) -> &'static str {
        "serde_json"
    }
    fn version(&self) -> &'static str {
        ver("serde_json")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        // Encode into harness-owned buffer (capacity reused across reps).
        serde_json::to_writer(&mut *out, fixture)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(serde_json::from_slice(data)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let mut counter = CountWrite { inner: w, n: 0 };
        serde_json::to_writer(&mut counter, fixture)?;
        Ok(counter.n)
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
        ver("simd-json")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.scratch.clear();
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        // simd-json has no competitive serializer; encode via serde_json into `out`.
        serde_json::to_writer(&mut *out, fixture)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        self.scratch.clear();
        self.scratch.extend_from_slice(data);
        let v: Fixture = simd_json::serde::from_slice(&mut self.scratch)?;
        Ok(v)
    }
}

#[derive(Default)]
pub struct SonicRs;

impl BenchSerializer for SonicRs {
    fn name(&self) -> &'static str {
        "sonic-rs"
    }
    fn version(&self) -> &'static str {
        ver("sonic-rs")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        sonic_rs::to_writer(&mut *out, fixture)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(sonic_rs::from_slice(data)?)
    }
}
