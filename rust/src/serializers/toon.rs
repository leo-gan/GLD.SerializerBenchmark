//! TOON via the `toon-format` crate.
//!
//! The timed path writes and reads UTF-8 text. The byte length is the size.
//! A token count is not part of this measurement.
//! https://github.com/toon-format/toon-rust

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

use super::{BenchSerializer, StreamMode};

#[derive(Default)]
pub struct ToonFormat;

impl BenchSerializer for ToonFormat {
    fn name(&self) -> &'static str {
        "toon-format"
    }
    fn version(&self) -> &'static str {
        super::ver("toon-format")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let text = toon_format::encode_default(fixture)?;
        out.extend_from_slice(text.as_bytes());
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let text = std::str::from_utf8(data)?;
        Ok(toon_format::decode_default(text)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let mut data = Vec::new();
        self.serialize_into(fixture, &mut data)?;
        w.write_all(&data)?;
        Ok(data.len())
    }
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        let mut data = Vec::new();
        r.read_to_end(&mut data)?;
        self.deserialize_bytes(&data)
    }
}
