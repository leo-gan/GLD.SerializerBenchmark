//! Serde-backed binary formats: MessagePack, CBOR, bincode, postcard, bitcode, flexbuffers, bson.

use crate::data::Fixture;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};

use super::{take_rearm, ver, BenchSerializer, CountWrite, StreamMode};

pub struct RmpSerde {
    buf: Vec<u8>,
}
impl Default for RmpSerde {
    fn default() -> Self {
        Self {
            buf: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for RmpSerde {
    fn name(&self) -> &'static str {
        "rmp-serde"
    }
    fn version(&self) -> &'static str {
        ver("rmp-serde")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // Optimal: named maps into reused buffer via Serializer (to_vec_named allocates).
        self.buf.clear();
        let mut ser = rmp_serde::Serializer::new(&mut self.buf).with_struct_map();
        fixture.serialize(&mut ser)?;
        Ok(take_rearm(&mut self.buf))
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(rmp_serde::from_slice(data)?)
    }
}

pub struct CiboriumSer {
    buf: Vec<u8>,
}
impl Default for CiboriumSer {
    fn default() -> Self {
        Self {
            buf: Vec::with_capacity(4096),
        }
    }
}
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
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // Optimal: into_writer into reused buffer; take (no clone of the payload).
        self.buf.clear();
        ciborium::into_writer(fixture, &mut self.buf)?;
        Ok(take_rearm(&mut self.buf))
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
    buf: Vec<u8>,
}
impl Default for BincodeSer {
    fn default() -> Self {
        Self {
            config: bincode::config::standard(),
            buf: Vec::with_capacity(4096),
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
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // Optimal: encode_into_slice/vec into reused capacity when possible.
        self.buf.clear();
        bincode::serde::encode_into_std_write(fixture, &mut self.buf, self.config)?;
        Ok(take_rearm(&mut self.buf))
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let (v, _): (Fixture, usize) = bincode::serde::decode_from_slice(data, self.config)?;
        Ok(v)
    }
}

pub struct PostcardSer {
    buf: Vec<u8>,
}
impl Default for PostcardSer {
    fn default() -> Self {
        Self {
            buf: Vec::with_capacity(4096),
        }
    }
}
impl BenchSerializer for PostcardSer {
    fn name(&self) -> &'static str {
        "postcard"
    }
    fn version(&self) -> &'static str {
        ver("postcard")
    }
    fn prepare(&mut self, _: &Fixture) -> Result<()> {
        self.buf.clear();
        Ok(())
    }
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // Optimal: extend into reused Vec (to_allocvec always allocates fresh).
        // to_extend takes Extend by value and returns it with capacity preserved.
        self.buf.clear();
        let buf = postcard::to_extend(fixture, std::mem::take(&mut self.buf))?;
        // re-arm for next call
        self.buf = Vec::with_capacity(buf.capacity().max(4096));
        Ok(buf)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(postcard::from_bytes(data)?)
    }
}

pub struct BitcodeSer;
impl Default for BitcodeSer {
    fn default() -> Self {
        Self
    }
}
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
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        Ok(bitcode::serialize(fixture)?)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(bitcode::deserialize(data)?)
    }
}

pub struct FlexbuffersSer;
impl Default for FlexbuffersSer {
    fn default() -> Self {
        Self
    }
}
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
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        let mut s = flexbuffers::FlexbufferSerializer::new();
        fixture.serialize(&mut s)?;
        Ok(s.view().to_vec())
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let r = flexbuffers::Reader::get_root(data)?;
        Ok(Fixture::deserialize(r)?)
    }
}

// We need kind tracking for minicbor/rkyv/speedy/nanoserde deserializers.
// Store last fixture name on each serializer that needs it.

pub struct BsonSer;
impl Default for BsonSer {
    fn default() -> Self {
        Self
    }
}
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
    fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
        // BSON documents need a map/struct root; wrap enum as document via serde.
        let doc = bson::to_vec(fixture)?;
        Ok(doc)
    }
    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        Ok(bson::from_slice(data)?)
    }
}
