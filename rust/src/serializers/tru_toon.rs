//! tru — Dicklesworthstone TOON codec (library name `toon`).
//!
//! The timed path is `encode` / `try_decode` of the JSON value. Size is the
//! UTF-8 byte length. The published crate also links its CLI dependencies.
//! https://github.com/Dicklesworthstone/toon_rust

use crate::data::Fixture;
use anyhow::Result;
use std::io::{Read, Write};

use super::{BenchSerializer, StreamMode};

fn integral_numbers(v: serde_json::Value) -> serde_json::Value {
    match v {
        serde_json::Value::Number(n) => {
            if n.as_i64().is_some() || n.as_u64().is_some() {
                return serde_json::Value::Number(n);
            }
            if let Some(f) = n.as_f64() {
                if f.is_finite() && f.fract() == 0.0 {
                    let min = i64::MIN as f64;
                    let max = i64::MAX as f64;
                    if f >= min && f <= max {
                        return serde_json::Value::Number((f as i64).into());
                    }
                }
            }
            serde_json::Value::Number(n)
        }
        serde_json::Value::Array(items) => {
            serde_json::Value::Array(items.into_iter().map(integral_numbers).collect())
        }
        serde_json::Value::Object(map) => serde_json::Value::Object(
            map.into_iter()
                .map(|(k, v)| (k, integral_numbers(v)))
                .collect(),
        ),
        other => other,
    }
}

#[derive(Default)]
pub struct TruToon;

impl BenchSerializer for TruToon {
    fn name(&self) -> &'static str {
        "tru"
    }
    fn version(&self) -> &'static str {
        super::ver("tru")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let value = serde_json::to_value(fixture)?;
        let text = toon::encode(value, None);
        out.extend_from_slice(text.as_bytes());
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let text = std::str::from_utf8(data)?;
        let parsed = toon::try_decode(text, None).map_err(|e| anyhow::anyhow!("{e}"))?;
        // tru stores every number as f64. Whole values become integers so i32 fields decode.
        Ok(serde_json::from_value(integral_numbers(serde_json::Value::from(parsed)))?)
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
