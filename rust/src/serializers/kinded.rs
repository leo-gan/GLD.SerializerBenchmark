//! Shared macro for direct (non-Serde-enum) codecs that track fixture kind.
//!
//! Identifiers in the macro body resolve at the call site (`direct.rs`).

macro_rules! impl_kinded_direct {
    (
        $name:ident,
        $log:expr,
        $ver:expr,
        $nk:expr,
        $ser:expr,
        $de_message:expr,
        $de_document:expr,
        $de_telemetry:expr,
        $de_strings:expr,
        $de_event:expr
    ) => {
        pub struct $name {
            kind: &'static str,
        }
        impl Default for $name {
            fn default() -> Self {
                Self { kind: "message" }
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
                    "message" => Ok(Fixture::Message($de_message(data)?)),
                    "document" => Ok(Fixture::Document($de_document(data)?)),
                    "telemetry" => Ok(Fixture::Telemetry($de_telemetry(data)?)),
                    "strings" => Ok(Fixture::Strings($de_strings(data)?)),
                    "event" => Ok(Fixture::Event($de_event(data)?)),
                    other => Err(anyhow!("unknown kind {other}")),
                }
            }
        }
    };
}



pub(crate) use impl_kinded_direct;
