//! Direct encode/decode paths: minicbor, rkyv, nanoserde, speedy (V2 types).

use crate::data::{Document, Event, Fixture, Message, Strings, Telemetry};
use anyhow::{anyhow, Result};

use super::kinded::impl_kinded_direct;
use super::{ver, BenchSerializer, NativeKind};

fn minicbor_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    match fixture {
        Fixture::Message(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Document(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Telemetry(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Strings(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Event(v) => Ok(minicbor::to_vec(v)?),
    }
}

impl_kinded_direct!(
    MinicborDirect,
    "minicbor",
    "0.25",
    NativeKind::Direct,
    minicbor_ser,
    |d| minicbor::decode::<Message>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Document>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Telemetry>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Strings>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Event>(d).map_err(|e| anyhow!("{e}"))
);

// ---------------------------------------------------------------------------
// rkyv — full Archive on concrete types (materialize to owned for fidelity)
// ---------------------------------------------------------------------------

fn rkyv_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    match fixture {
        Fixture::Message(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Document(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Telemetry(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Strings(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Event(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
    }
}

fn rkyv_de_message(data: &[u8]) -> Result<Message> {
    rkyv::from_bytes::<Message, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_document(data: &[u8]) -> Result<Document> {
    rkyv::from_bytes::<Document, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_telemetry(data: &[u8]) -> Result<Telemetry> {
    rkyv::from_bytes::<Telemetry, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_strings(data: &[u8]) -> Result<Strings> {
    rkyv::from_bytes::<Strings, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_event(data: &[u8]) -> Result<Event> {
    rkyv::from_bytes::<Event, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}

impl_kinded_direct!(
    RkyvSer,
    "rkyv",
    "0.8",
    NativeKind::Archive,
    rkyv_ser,
    rkyv_de_message,
    rkyv_de_document,
    rkyv_de_telemetry,
    rkyv_de_strings,
    rkyv_de_event
);

fn nanoserde_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    use nanoserde::SerBin;
    match fixture {
        Fixture::Message(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Document(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Telemetry(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Strings(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Event(v) => Ok(SerBin::serialize_bin(v)),
    }
}

impl_kinded_direct!(
    NanoserdeSer,
    "nanoserde",
    "0.1",
    NativeKind::Direct,
    nanoserde_ser,
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use nanoserde::DeBin;
        DeBin::deserialize_bin(d).map_err(|e| anyhow!("{e}"))
    }
);

fn speedy_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    use speedy::Writable;
    match fixture {
        Fixture::Message(v) => Ok(v.write_to_vec()?),
        Fixture::Document(v) => Ok(v.write_to_vec()?),
        Fixture::Telemetry(v) => Ok(v.write_to_vec()?),
        Fixture::Strings(v) => Ok(v.write_to_vec()?),
        Fixture::Event(v) => Ok(v.write_to_vec()?),
    }
}

impl_kinded_direct!(
    SpeedySer,
    "speedy",
    "0.8",
    NativeKind::Direct,
    speedy_ser,
    |d| {
        use speedy::Readable;
        Message::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        Document::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        Telemetry::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        Strings::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        Event::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    }
);
