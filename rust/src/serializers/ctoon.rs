//! ctoon — C99 TOON core through the Rust binding.
//!
//! The crate has no Serde layer. The timed path builds its `Value` from the
//! suite value, then calls `dumps` / `loads`. Size is the UTF-8 byte length.
//! https://github.com/MohammadRaziei/ctoon

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

pub struct Ctoon;

impl Default for Ctoon {
    fn default() -> Self {
        Self
    }
}

fn json_to_ctoon(v: &serde_json::Value) -> ctoon::Value {
    match v {
        serde_json::Value::Null => ctoon::Value::Null,
        serde_json::Value::Bool(b) => ctoon::Value::Bool(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                ctoon::Value::Sint(i)
            } else if let Some(u) = n.as_u64() {
                ctoon::Value::Uint(u)
            } else {
                ctoon::Value::Real(n.as_f64().unwrap_or(0.0))
            }
        }
        serde_json::Value::String(s) => ctoon::Value::Str(s.clone()),
        serde_json::Value::Array(items) => {
            ctoon::Value::Array(items.iter().map(json_to_ctoon).collect())
        }
        serde_json::Value::Object(map) => ctoon::Value::Object(
            map.iter()
                .map(|(k, v)| (k.clone(), json_to_ctoon(v)))
                .collect(),
        ),
    }
}

fn ctoon_to_json(v: &ctoon::Value) -> serde_json::Value {
    match v {
        ctoon::Value::Null => serde_json::Value::Null,
        ctoon::Value::Bool(b) => serde_json::Value::Bool(*b),
        ctoon::Value::Uint(n) => serde_json::Value::Number((*n).into()),
        ctoon::Value::Sint(n) => serde_json::Value::Number((*n).into()),
        ctoon::Value::Real(n) => serde_json::Number::from_f64(*n)
            .map(serde_json::Value::Number)
            .unwrap_or(serde_json::Value::Null),
        ctoon::Value::Str(s) => serde_json::Value::String(s.clone()),
        ctoon::Value::Array(items) => {
            serde_json::Value::Array(items.iter().map(ctoon_to_json).collect())
        }
        ctoon::Value::Object(fields) => {
            let mut map = serde_json::Map::new();
            for (k, v) in fields {
                map.insert(k.clone(), ctoon_to_json(v));
            }
            serde_json::Value::Object(map)
        }
    }
}

impl BenchSerializer for Ctoon {
    fn name(&self) -> &'static str {
        "ctoon"
    }
    fn version(&self) -> &'static str {
        super::ver("ctoon")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let value = serde_json::to_value(fixture)?;
        let text = ctoon::dumps(&json_to_ctoon(&value)).map_err(|e| anyhow::anyhow!("{e}"))?;
        out.extend_from_slice(text.as_bytes());
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let text = std::str::from_utf8(data)?;
        let value = ctoon::loads(text).map_err(|e| anyhow::anyhow!("{e}"))?;
        Ok(serde_json::from_value(integral_numbers(ctoon_to_json(&value)))?)
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
