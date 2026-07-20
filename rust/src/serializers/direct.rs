//! Direct encode/decode paths: minicbor, rkyv, nanoserde, speedy (V2 types).
//!
//! Each codec exposes monomorphic `ser_*` helpers (one per fixture kind) bound
//! in `prepare` so timed encode is an indirect call, not a multi-way match.

use crate::data::{Document, Event, Fixture, Message, Strings, Telemetry};
use anyhow::{anyhow, bail, Result};

use super::kinded::impl_kinded_direct;
use super::{ver, BenchSerializer, NativeKind};

// ---------------------------------------------------------------------------
// minicbor
// ---------------------------------------------------------------------------

fn minicbor_ser_message(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Message(v) = fx else {
        bail!("minicbor: expected Message");
    };
    minicbor::encode(v, &mut *out).map_err(|e| anyhow!("{e}"))
}
fn minicbor_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else {
        bail!("minicbor: expected Document");
    };
    minicbor::encode(v, &mut *out).map_err(|e| anyhow!("{e}"))
}
fn minicbor_ser_telemetry(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Telemetry(v) = fx else {
        bail!("minicbor: expected Telemetry");
    };
    minicbor::encode(v, &mut *out).map_err(|e| anyhow!("{e}"))
}
fn minicbor_ser_strings(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Strings(v) = fx else {
        bail!("minicbor: expected Strings");
    };
    minicbor::encode(v, &mut *out).map_err(|e| anyhow!("{e}"))
}
fn minicbor_ser_event(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Event(v) = fx else {
        bail!("minicbor: expected Event");
    };
    minicbor::encode(v, &mut *out).map_err(|e| anyhow!("{e}"))
}

impl_kinded_direct!(
    MinicborDirect,
    "minicbor",
    "0.25",
    NativeKind::Direct,
    minicbor_ser_message,
    minicbor_ser_document,
    minicbor_ser_telemetry,
    minicbor_ser_strings,
    minicbor_ser_event,
    |d| minicbor::decode::<Message>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Document>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Telemetry>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Strings>(d).map_err(|e| anyhow!("{e}")),
    |d| minicbor::decode::<Event>(d).map_err(|e| anyhow!("{e}"))
);

// ---------------------------------------------------------------------------
// rkyv — full Archive on concrete types (materialize to owned for fidelity)
// ---------------------------------------------------------------------------

fn rkyv_ser_message(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Message(v) = fx else {
        bail!("rkyv: expected Message");
    };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v).map_err(|e| anyhow!("{e}"))?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
}
fn rkyv_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else {
        bail!("rkyv: expected Document");
    };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v).map_err(|e| anyhow!("{e}"))?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
}
fn rkyv_ser_telemetry(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Telemetry(v) = fx else {
        bail!("rkyv: expected Telemetry");
    };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v).map_err(|e| anyhow!("{e}"))?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
}
fn rkyv_ser_strings(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Strings(v) = fx else {
        bail!("rkyv: expected Strings");
    };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v).map_err(|e| anyhow!("{e}"))?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
}
fn rkyv_ser_event(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Event(v) = fx else {
        bail!("rkyv: expected Event");
    };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v).map_err(|e| anyhow!("{e}"))?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
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
    rkyv_ser_message,
    rkyv_ser_document,
    rkyv_ser_telemetry,
    rkyv_ser_strings,
    rkyv_ser_event,
    rkyv_de_message,
    rkyv_de_document,
    rkyv_de_telemetry,
    rkyv_de_strings,
    rkyv_de_event
);

// ---------------------------------------------------------------------------
// nanoserde
// ---------------------------------------------------------------------------

fn nanoserde_ser_message(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use nanoserde::SerBin;
    let Fixture::Message(v) = fx else {
        bail!("nanoserde: expected Message");
    };
    out.extend_from_slice(&SerBin::serialize_bin(v));
    Ok(())
}
fn nanoserde_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use nanoserde::SerBin;
    let Fixture::Document(v) = fx else {
        bail!("nanoserde: expected Document");
    };
    out.extend_from_slice(&SerBin::serialize_bin(v));
    Ok(())
}
fn nanoserde_ser_telemetry(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use nanoserde::SerBin;
    let Fixture::Telemetry(v) = fx else {
        bail!("nanoserde: expected Telemetry");
    };
    out.extend_from_slice(&SerBin::serialize_bin(v));
    Ok(())
}
fn nanoserde_ser_strings(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use nanoserde::SerBin;
    let Fixture::Strings(v) = fx else {
        bail!("nanoserde: expected Strings");
    };
    out.extend_from_slice(&SerBin::serialize_bin(v));
    Ok(())
}
fn nanoserde_ser_event(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use nanoserde::SerBin;
    let Fixture::Event(v) = fx else {
        bail!("nanoserde: expected Event");
    };
    out.extend_from_slice(&SerBin::serialize_bin(v));
    Ok(())
}

impl_kinded_direct!(
    NanoserdeSer,
    "nanoserde",
    "0.1",
    NativeKind::Direct,
    nanoserde_ser_message,
    nanoserde_ser_document,
    nanoserde_ser_telemetry,
    nanoserde_ser_strings,
    nanoserde_ser_event,
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

// ---------------------------------------------------------------------------
// speedy
// ---------------------------------------------------------------------------

fn speedy_ser_message(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use speedy::Writable;
    let Fixture::Message(v) = fx else {
        bail!("speedy: expected Message");
    };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
fn speedy_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use speedy::Writable;
    let Fixture::Document(v) = fx else {
        bail!("speedy: expected Document");
    };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
fn speedy_ser_telemetry(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use speedy::Writable;
    let Fixture::Telemetry(v) = fx else {
        bail!("speedy: expected Telemetry");
    };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
fn speedy_ser_strings(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use speedy::Writable;
    let Fixture::Strings(v) = fx else {
        bail!("speedy: expected Strings");
    };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
fn speedy_ser_event(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use speedy::Writable;
    let Fixture::Event(v) = fx else {
        bail!("speedy: expected Event");
    };
    v.write_to_stream(&mut *out)?;
    Ok(())
}

impl_kinded_direct!(
    SpeedySer,
    "speedy",
    "0.8",
    NativeKind::Direct,
    speedy_ser_message,
    speedy_ser_document,
    speedy_ser_telemetry,
    speedy_ser_strings,
    speedy_ser_event,
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
