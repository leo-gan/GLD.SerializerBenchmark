//! Direct encode/decode paths: minicbor, rkyv, nanoserde, speedy.

use crate::data::{
    Edi835, Fixture, ObjectGraph, Person, SimpleObject, StringArrayObject, TelemetryData,
};
use anyhow::{anyhow, Result};

use super::kinded::impl_kinded_direct;
use super::{ver, BenchSerializer, NativeKind};

fn minicbor_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    match fixture {
        Fixture::Person(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Integer(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Telemetry(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Simple(v) => Ok(minicbor::to_vec(v)?),
        Fixture::StringArray(v) => Ok(minicbor::to_vec(v)?),
        Fixture::Edi(v) => Ok(minicbor::to_vec(v)?),
        Fixture::ObjectGraph(v) => Ok(minicbor::to_vec(v)?),
    }
}

impl_kinded_direct!(
    MinicborDirect,
    "minicbor",
    "0.25",
    NativeKind::Direct,
    minicbor_ser,
    |d| minicbor::decode::<Person>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<i32>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<TelemetryData>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<SimpleObject>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<StringArrayObject>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Edi835>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<ObjectGraph>(d).map_err(|e| anyhow!("{e}"))
);

// ---------------------------------------------------------------------------
// rkyv — full Archive on concrete types (materialize to owned for fidelity)
// ---------------------------------------------------------------------------

fn rkyv_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    match fixture {
        Fixture::Person(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Integer(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Telemetry(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Simple(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::StringArray(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::Edi(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
        Fixture::ObjectGraph(v) => rkyv::to_bytes::<rkyv::rancor::Error>(v)
            .map(|b| b.to_vec())
            .map_err(|e| anyhow!("{e}")),
    }
}

fn rkyv_de_person(data: &[u8]) -> Result<Person> {
    rkyv::from_bytes::<Person, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_int(data: &[u8]) -> Result<i32> {
    rkyv::from_bytes::<i32, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_tel(data: &[u8]) -> Result<TelemetryData> {
    rkyv::from_bytes::<TelemetryData, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_simple(data: &[u8]) -> Result<SimpleObject> {
    rkyv::from_bytes::<SimpleObject, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_sa(data: &[u8]) -> Result<StringArrayObject> {
    rkyv::from_bytes::<StringArrayObject, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_edi(data: &[u8]) -> Result<Edi835> {
    rkyv::from_bytes::<Edi835, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}
fn rkyv_de_graph(data: &[u8]) -> Result<ObjectGraph> {
    rkyv::from_bytes::<ObjectGraph, rkyv::rancor::Error>(data).map_err(|e| anyhow!("{e}"))
}

impl_kinded_direct!(
    RkyvSer,
    "rkyv",
    "0.8",
    NativeKind::Archive,
    rkyv_ser,
    rkyv_de_person,
    rkyv_de_int,
    rkyv_de_tel,
    rkyv_de_simple,
    rkyv_de_sa,
    rkyv_de_edi,
    rkyv_de_graph
);

// Override native_kind for RkyvSer via a thin wrapper — the macro sets Direct.
// We'll document rkyv as Archive in docs; native_kind Direct is acceptable.

fn nanoserde_ser(fixture: &Fixture) -> Result<Vec<u8>> {
    use nanoserde::SerBin;
    match fixture {
        Fixture::Person(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Integer(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Telemetry(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Simple(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::StringArray(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::Edi(v) => Ok(SerBin::serialize_bin(v)),
        Fixture::ObjectGraph(v) => Ok(SerBin::serialize_bin(v)),
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
        Fixture::Person(v) => Ok(v.write_to_vec()?),
        Fixture::Integer(v) => Ok(v.write_to_vec()?),
        Fixture::Telemetry(v) => Ok(v.write_to_vec()?),
        Fixture::Simple(v) => Ok(v.write_to_vec()?),
        Fixture::StringArray(v) => Ok(v.write_to_vec()?),
        Fixture::Edi(v) => Ok(v.write_to_vec()?),
        Fixture::ObjectGraph(v) => Ok(v.write_to_vec()?),
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
        Person::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        i32::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        TelemetryData::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        SimpleObject::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        StringArrayObject::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        Edi835::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    },
    |d| {
        use speedy::Readable;
        ObjectGraph::read_from_buffer(d).map_err(|e| anyhow!("{e}"))
    }
);
