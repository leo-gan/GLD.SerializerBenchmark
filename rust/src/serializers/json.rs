//! JSON family: serde_json, simd-json, sonic-rs.

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

use super::{take_rearm, ver, BenchSerializer, CountWrite, StreamMode};

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
        ver("serde_json")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // Optimal: write into a reused Vec (to_vec always allocates fresh).
        self.buf.clear();
        serde_json::to_writer(&mut self.buf, fixture)?;
        Ok(take_rearm(&mut self.buf))
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(serde_json::from_slice(data)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        // Native streaming write (no intermediate full Vec when writer is true stream).
        let before = self.buf.len(); // unused; write directly
        let _ = before;
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

pub struct SonicRs {
    buf: Vec<u8>,
}
impl Default for SonicRs {
    fn default() -> Self {
        Self {
            buf: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for SonicRs {
    fn name(&self) -> &'static str {
        "sonic-rs"
    }
    fn version(&self) -> &'static str {
        ver("sonic-rs")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        self.buf.clear();
        sonic_rs::to_writer(&mut self.buf, fixture)?;
        Ok(take_rearm(&mut self.buf))
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(sonic_rs::from_slice(data)?)
    }
}
