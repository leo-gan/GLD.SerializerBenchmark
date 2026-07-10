//! prost wrapper — serializer kept; V1 Person protobuf schema removed.
//!
//! Data Model v2 path uses Value codecs in `run_v2`. Prost re-wiring to
//! `schemas/v2/protobuf/benchmark_v2.proto` is deferred; this stub stays
//! registered but supports no fixture names until that lands.

use crate::data::Fixture;
use crate::serializers::{BenchSerializer, NativeKind, StreamMode};
use anyhow::{bail, Result};
use std::io::{Read, Write};

pub struct ProstSer {
    kind: &'static str,
}

impl Default for ProstSer {
    fn default() -> Self {
        Self { kind: "" }
    }
}

impl BenchSerializer for ProstSer {
    fn name(&self) -> &'static str {
        "prost"
    }
    fn version(&self) -> &'static str {
        crate::serializers::ver("prost")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Message
    }
    fn supports(&self, _test_data_name: &str) -> bool {
        false
    }
    fn prepare(&mut self, fx: &Fixture) -> Result<()> {
        self.kind = fx.name();
        bail!("prost V2 schema mapping not wired yet")
    }
    fn serialize_bytes(&mut self, _fx: &Fixture) -> Result<Vec<u8>> {
        bail!("prost not available")
    }
    fn deserialize_bytes(&mut self, _data: &[u8]) -> Result<Fixture> {
        bail!("prost not available")
    }
    fn serialize_stream(&mut self, fx: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let b = self.serialize_bytes(fx)?;
        w.write_all(&b)?;
        Ok(b.len())
    }
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        let mut buf = Vec::new();
        r.read_to_end(&mut buf)?;
        self.deserialize_bytes(&buf)
    }
}
