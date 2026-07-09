//! Shared macro for direct (non-Serde-enum) codecs that track fixture kind.
//!
//! Identifiers in the macro body resolve at the call site (`direct.rs`).

macro_rules! impl_kinded_direct {
    ($name:ident, $log:expr, $ver:expr, $nk:expr, $ser:expr, $de_person:expr, $de_int:expr, $de_tel:expr, $de_simple:expr, $de_sa:expr, $de_edi:expr, $de_graph:expr) => {
        pub struct $name {
            kind: &'static str,
        }
        impl Default for $name {
            fn default() -> Self {
                Self { kind: "Person" }
            }
        }
        impl BenchSerializer for $name {
            fn name(&self) -> &'static str {
                $log
            }
            fn version(&self) -> &'static str {
                // $ver kept for call-site compatibility; version comes from Cargo.lock.
                let _ = $ver;
                ver($log)
            }
            fn native_kind(&self) -> NativeKind {
                $nk
            }
            fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
                self.kind = fixture.name();
                Ok(())
            }
            fn serialize_bytes(&mut self, fixture: &Fixture) -> Result<Vec<u8>> {
                $ser(fixture)
            }
            fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
                match self.kind {
                    "Person" => Ok(Fixture::Person($de_person(data)?)),
                    "Integer" => Ok(Fixture::Integer($de_int(data)?)),
                    "Telemetry" => Ok(Fixture::Telemetry($de_tel(data)?)),
                    "SimpleObject" => Ok(Fixture::Simple($de_simple(data)?)),
                    "StringArray" => Ok(Fixture::StringArray($de_sa(data)?)),
                    "EDI_835" => Ok(Fixture::Edi($de_edi(data)?)),
                    "ObjectGraph" => Ok(Fixture::ObjectGraph($de_graph(data)?)),
                    other => Err(anyhow!("unknown kind {other}")),
                }
            }
        }
    };
}



pub(crate) use impl_kinded_direct;
