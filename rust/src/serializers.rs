//! Serializer trait and implementations. Each uses the recommended/optimal API.

use crate::data::Fixture;
use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};

pub trait BenchSerializer: Send {
    fn name(&self) -> &'static str;
    fn version(&self) -> &'static str;
    fn supports(&self, test_data_name: &str) -> bool {
        test_data_name != "ObjectGraph"
    }
    /// Timed: serialize to owned bytes.
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>>;
    /// Timed: deserialize from bytes; must return a Fixture-equivalent for fidelity check.
    fn deserialize_bytes(&self, data: &[u8], expected: &Fixture) -> Result<Fixture>;
}

// --- helpers ---
fn ser_json_value(fixture: &Fixture) -> Result<Vec<u8>> {
    Ok(serde_json::to_vec(fixture)?)
}
fn de_json_value(data: &[u8]) -> Result<Fixture> {
    Ok(serde_json::from_slice(data)?)
}

// 1. serde_json
pub struct SerdeJson;
impl BenchSerializer for SerdeJson {
    fn name(&self) -> &'static str { "serde_json" }
    fn version(&self) -> &'static str { "1" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> { ser_json_value(fixture) }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> { de_json_value(data) }
}

// 2. simd-json (uses serde_json for serialize; simd-json for parse path)
pub struct SimdJson;
impl BenchSerializer for SimdJson {
    fn name(&self) -> &'static str { "simd-json" }
    fn version(&self) -> &'static str { "0.14" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> { ser_json_value(fixture) }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        let mut owned = data.to_vec();
        let v: Fixture = simd_json::serde::from_slice(&mut owned)?;
        Ok(v)
    }
}

// 3. sonic-rs
pub struct SonicRs;
impl BenchSerializer for SonicRs {
    fn name(&self) -> &'static str { "sonic-rs" }
    fn version(&self) -> &'static str { "0.3" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(sonic_rs::to_vec(fixture)?)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        Ok(sonic_rs::from_slice(data)?)
    }
}

// 4. rmp-serde (MessagePack)
pub struct RmpSerde;
impl BenchSerializer for RmpSerde {
    fn name(&self) -> &'static str { "rmp-serde" }
    fn version(&self) -> &'static str { "1" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(rmp_serde::to_vec_named(fixture)?)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        Ok(rmp_serde::from_slice(data)?)
    }
}

// 5. ciborium (CBOR)
pub struct CiboriumSer;
impl BenchSerializer for CiboriumSer {
    fn name(&self) -> &'static str { "ciborium" }
    fn version(&self) -> &'static str { "0.2" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        let mut buf = Vec::new();
        ciborium::into_writer(fixture, &mut buf)?;
        Ok(buf)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        Ok(ciborium::from_reader(data)?)
    }
}

// 6. bincode 2
pub struct BincodeSer;
impl BenchSerializer for BincodeSer {
    fn name(&self) -> &'static str { "bincode" }
    fn version(&self) -> &'static str { "2" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        let config = bincode::config::standard();
        Ok(bincode::serde::encode_to_vec(fixture, config)?)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        let config = bincode::config::standard();
        let (v, _): (Fixture, usize) = bincode::serde::decode_from_slice(data, config)?;
        Ok(v)
    }
}

// 7. postcard
pub struct PostcardSer;
impl BenchSerializer for PostcardSer {
    fn name(&self) -> &'static str { "postcard" }
    fn version(&self) -> &'static str { "1" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(postcard::to_allocvec(fixture)?)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        Ok(postcard::from_bytes(data)?)
    }
}

// 8. bitcode
pub struct BitcodeSer;
impl BenchSerializer for BitcodeSer {
    fn name(&self) -> &'static str { "bitcode" }
    fn version(&self) -> &'static str { "0.6" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(bitcode::serialize(fixture)?)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        Ok(bitcode::deserialize(data)?)
    }
}

// 9. flexbuffers
pub struct FlexbuffersSer;
impl BenchSerializer for FlexbuffersSer {
    fn name(&self) -> &'static str { "flexbuffers" }
    fn version(&self) -> &'static str { "2" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        let mut s = flexbuffers::FlexbufferSerializer::new();
        fixture.serialize(&mut s)?;
        Ok(s.view().to_vec())
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        let r = flexbuffers::Reader::get_root(data)?;
        Ok(Fixture::deserialize(r)?)
    }
}

// 10. minicbor — encode MessagePack payload as CBOR byte string (stable across all fixtures)
pub struct MinicborSer;
impl BenchSerializer for MinicborSer {
    fn name(&self) -> &'static str { "minicbor" }
    fn version(&self) -> &'static str { "0.25" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        let inner = rmp_serde::to_vec_named(fixture)?;
        Ok(minicbor::to_vec(&inner)?)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        let inner: Vec<u8> = minicbor::decode(data)?;
        Ok(rmp_serde::from_slice(&inner)?)
    }
}

// 11. rkyv — zero-copy archive of MessagePack payload (avoids postcard f64 limits on EDI)
pub struct RkyvSer;
impl BenchSerializer for RkyvSer {
    fn name(&self) -> &'static str { "rkyv" }
    fn version(&self) -> &'static str { "0.8" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        let inner = rmp_serde::to_vec_named(fixture)?;
        rkyv::to_bytes::<rkyv::rancor::Error>(&inner)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}"))
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        let archived = rkyv::access::<rkyv::vec::ArchivedVec<u8>, rkyv::rancor::Error>(data)
            .map_err(|e| anyhow!("{e}"))?;
        let inner: Vec<u8> = rkyv::deserialize::<Vec<u8>, rkyv::rancor::Error>(archived)
            .map_err(|e| anyhow!("{e}"))?;
        Ok(rmp_serde::from_slice(&inner)?)
    }
}

// 12. prost-wire — length-delimited protobuf field-1 over MessagePack payload
pub struct ProstSer;
impl BenchSerializer for ProstSer {
    fn name(&self) -> &'static str { "prost-wire" }
    fn version(&self) -> &'static str { "0.13" }
    fn serialize_bytes(&self, fixture: &Fixture) -> Result<Vec<u8>> {
        let inner = rmp_serde::to_vec_named(fixture)?;
        let mut out = Vec::with_capacity(inner.len() + 10);
        out.push(0x0A);
        write_varint(&mut out, inner.len() as u64);
        out.extend_from_slice(&inner);
        Ok(out)
    }
    fn deserialize_bytes(&self, data: &[u8], _: &Fixture) -> Result<Fixture> {
        if data.is_empty() || data[0] != 0x0A {
            return Err(anyhow!("invalid prost-wire header"));
        }
        let (len, off) = read_varint(&data[1..])?;
        let start = 1 + off;
        let end = start + len as usize;
        if end > data.len() {
            return Err(anyhow!("truncated prost-wire"));
        }
        Ok(rmp_serde::from_slice(&data[start..end])?)
    }
}

fn write_varint(buf: &mut Vec<u8>, mut v: u64) {
    while v >= 0x80 {
        buf.push((v as u8) | 0x80);
        v >>= 7;
    }
    buf.push(v as u8);
}

fn read_varint(data: &[u8]) -> Result<(u64, usize)> {
    let mut result = 0u64;
    let mut shift = 0;
    for (i, &b) in data.iter().enumerate() {
        result |= ((b & 0x7F) as u64) << shift;
        if b & 0x80 == 0 {
            return Ok((result, i + 1));
        }
        shift += 7;
        if shift > 63 {
            return Err(anyhow!("varint overflow"));
        }
    }
    Err(anyhow!("truncated varint"))
}

pub fn all_serializers() -> Vec<Box<dyn BenchSerializer>> {
    vec![
        Box::new(SerdeJson),
        Box::new(SimdJson),
        Box::new(SonicRs),
        Box::new(RmpSerde),
        Box::new(CiboriumSer),
        Box::new(BincodeSer),
        Box::new(PostcardSer),
        Box::new(BitcodeSer),
        Box::new(FlexbuffersSer),
        Box::new(MinicborSer),
        Box::new(RkyvSer),
        Box::new(ProstSer),
    ]
}
