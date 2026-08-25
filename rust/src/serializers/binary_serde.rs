//! Serde-backed binary formats: MessagePack, CBOR, bincode, postcard, bitcode, flexbuffers, bson.

use crate::data::Fixture;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};

use super::{ver, BenchSerializer, CountWrite, StreamMode};

#[derive(Default)]
pub struct RmpSerde;

impl BenchSerializer for RmpSerde {
    fn name(&self) -> &'static str {
        "rmp-serde"
    }
    fn version(&self) -> &'static str {
        ver("rmp-serde")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let mut ser = rmp_serde::Serializer::new(&mut *out).with_struct_map();
        fixture.serialize(&mut ser)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(rmp_serde::from_slice(data)?)
    }
}

#[derive(Default)]
pub struct CiboriumSer;

impl BenchSerializer for CiboriumSer {
    fn name(&self) -> &'static str {
        "ciborium"
    }
    fn version(&self) -> &'static str {
        ver("ciborium")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Native
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        ciborium::into_writer(fixture, &mut *out)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(ciborium::from_reader(data)?)
    }
    fn serialize_stream(&mut self, fixture: &Fixture, w: &mut dyn Write) -> Result<usize> {
        let mut counter = CountWrite { inner: w, n: 0 };
        ciborium::into_writer(fixture, &mut counter)?;
        Ok(counter.n)
    }
    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        Ok(ciborium::from_reader(r)?)
    }
}

pub struct BincodeSer {
    config: bincode::config::Configuration,
}
impl Default for BincodeSer {
    fn default() -> Self {
        Self {
            config: bincode::config::standard(),
        }
    }
}
impl BenchSerializer for BincodeSer {
    fn name(&self) -> &'static str {
        "bincode"
    }
    fn version(&self) -> &'static str {
        ver("bincode")
    }
    fn stream_mode(&self) -> StreamMode {
        // encode_into_std_write is native; decode_from_std_read needs Sized reader,
        // so full stream pair stays adapted via default trait methods.
        StreamMode::Adapted
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        bincode::serde::encode_into_std_write(fixture, out, self.config)?;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let (v, _): (Fixture, usize) = bincode::serde::decode_from_slice(data, self.config)?;
        Ok(v)
    }
}

#[derive(Default)]
pub struct PostcardSer;

impl BenchSerializer for PostcardSer {
    fn name(&self) -> &'static str {
        "postcard"
    }
    fn version(&self) -> &'static str {
        ver("postcard")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        // to_extend appends into the existing Vec (capacity preserved by caller).
        let filled = postcard::to_extend(fixture, std::mem::take(out))?;
        *out = filled;
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(postcard::from_bytes(data)?)
    }
}

#[derive(Default)]
pub struct BitcodeSer;

impl BenchSerializer for BitcodeSer {
    fn name(&self) -> &'static str {
        "bitcode"
    }
    fn version(&self) -> &'static str {
        ver("bitcode")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        // Library returns a fresh Vec; append into harness buffer.
        let bytes = bitcode::serialize(fixture)?;
        out.extend_from_slice(&bytes);
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(bitcode::deserialize(data)?)
    }
}

#[derive(Default)]
pub struct FlexbuffersSer;

impl BenchSerializer for FlexbuffersSer {
    fn name(&self) -> &'static str {
        "flexbuffers"
    }
    fn version(&self) -> &'static str {
        ver("flexbuffers")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let mut s = flexbuffers::FlexbufferSerializer::new();
        fixture.serialize(&mut s)?;
        out.extend_from_slice(s.view());
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let r = flexbuffers::Reader::get_root(data)?;
        Ok(Fixture::deserialize(r)?)
    }
}

#[derive(Default)]
pub struct BsonSer;

impl BenchSerializer for BsonSer {
    fn name(&self) -> &'static str {
        "bson"
    }
    fn version(&self) -> &'static str {
        ver("bson")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        Ok(())
    }
    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        // bson 2.x has no serde `to_writer` (only `Document::to_writer` after
        // materializing a Document). `to_vec` is the public one-shot path;
        // append into the harness-owned buffer so capacity still reuses across reps.
        let bytes = bson::to_vec(fixture)?;
        out.extend_from_slice(&bytes);
        Ok(())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(bson::from_slice(data)?)
    }
}
