use anyhow::{bail, Result};
use fory::Fory;

use super::{ver, BenchSerializer, NativeKind};
use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Fixture, Message, Strings, Telemetry,
};

type Encode = fn(&Fory, &Fixture, &mut Vec<u8>) -> Result<()>;
type Decode = fn(&Fory, &[u8]) -> Result<Fixture>;

pub struct ForySer {
    fory: Fory,
    encode: Encode,
    decode: Decode,
}

impl Default for ForySer {
    fn default() -> Self {
        let mut fory = Fory::builder().xlang(false).build();
        fory.register::<Message>(1).unwrap();
        fory.register::<DocumentMeta>(2).unwrap();
        fory.register::<DocumentItem>(3).unwrap();
        fory.register::<Document>(4).unwrap();
        fory.register::<Telemetry>(5).unwrap();
        fory.register::<Strings>(6).unwrap();
        fory.register::<EventAttr>(7).unwrap();
        fory.register::<Event>(8).unwrap();
        Self {
            fory,
            encode: |_, _, _| bail!("prepare required"),
            decode: |_, _| bail!("prepare required"),
        }
    }
}

impl BenchSerializer for ForySer {
    fn name(&self) -> &'static str {
        "fory"
    }
    fn version(&self) -> &'static str {
        ver("fory")
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Direct
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        // Bind concrete generated serializers once, outside the measured loop.
        macro_rules! bind {
            ($variant:ident) => {{
                self.encode = |f, fx, out| {
                    let Fixture::$variant(value) = fx else {
                        bail!("fixture kind changed");
                    };
                    f.serialize_to(out, value)?;
                    Ok(())
                };
                self.decode = |f, data| Ok(Fixture::$variant(f.deserialize(data)?));
            }};
        }
        match fixture {
            Fixture::Message(_) => bind!(Message),
            Fixture::Document(_) => bind!(Document),
            Fixture::Telemetry(_) => bind!(Telemetry),
            Fixture::Strings(_) => bind!(Strings),
            Fixture::Event(_) => bind!(Event),
        }
        let bytes = self.serialize_bytes(fixture)?;
        self.deserialize_bytes(&bytes)?;
        Ok(())
    }

    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        (self.encode)(&self.fory, fixture, out)
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        (self.decode)(&self.fory, data)
    }
}
