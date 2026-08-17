//! YAML via serde_yaml (the usual Rust YAML crate).

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

use super::{ver, BenchSerializer, CountWrite, StreamMode};

#[derive(Default)]
pub struct SerdeYaml;

impl BenchSerializer for SerdeYaml {
    fn name(&self) -> &'static str {
        "serde_yaml"
    }
    fn version(&self) -> &'static str {
        ver("serde_yaml")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        serde_yaml::to_writer(&mut *out, fixture)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(serde_yaml::from_slice(data)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let mut counter = CountWrite { inner: w, n: 0 };
        serde_yaml::to_writer(&mut counter, fixture)?;
        Ok(counter.n)
    }
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        Ok(serde_yaml::from_reader(r)?)
    }
}
