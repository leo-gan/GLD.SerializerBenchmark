//! Shared macro for direct (non-Serde-enum) codecs that bind kind in `prepare`.
//!
//! Timed serialize uses a monomorphic function pointer set during `prepare`,
//! so the hot path is not a multi-way `match fixture { ... }`. Decode matches
//! a small kind enum bound in prepare (not the input fixture).
//! Identifiers in the macro body resolve at the call site (`direct.rs`).

use crate::data::Fixture;
use anyhow::Result;

/// Encode `fixture` into `out` (kind already bound by prepare).
pub(crate) type SerFn = fn(&Fixture, &mut Vec<u8>) -> Result<()>;

#[derive(Clone, Copy)]
pub(crate) enum BoundKind {
    Message,
    Document,
    Telemetry,
    Strings,
    Event,
}

macro_rules! impl_kinded_direct {
    (
        $name:ident,
        $log:expr,
        $ver:expr,
        $nk:expr,
        $ser_message:expr,
        $ser_document:expr,
        $ser_telemetry:expr,
        $ser_strings:expr,
        $ser_event:expr,
        $de_message:expr,
        $de_document:expr,
        $de_telemetry:expr,
        $de_strings:expr,
        $de_event:expr
    ) => {
        pub struct $name {
            ser: crate::serializers::kinded::SerFn,
            kind: crate::serializers::kinded::BoundKind,
        }
        impl Default for $name {
            fn default() -> Self {
                Self {
                    ser: $ser_message,
                    kind: crate::serializers::kinded::BoundKind::Message,
                }
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
                // Bind monomorphic encode + decode kind outside the timed loop.
                use crate::serializers::kinded::BoundKind;
                match fixture {
                    Fixture::Message(_) => {
                        self.ser = $ser_message;
                        self.kind = BoundKind::Message;
                    }
                    Fixture::Document(_) => {
                        self.ser = $ser_document;
                        self.kind = BoundKind::Document;
                    }
                    Fixture::Telemetry(_) => {
                        self.ser = $ser_telemetry;
                        self.kind = BoundKind::Telemetry;
                    }
                    Fixture::Strings(_) => {
                        self.ser = $ser_strings;
                        self.kind = BoundKind::Strings;
                    }
                    Fixture::Event(_) => {
                        self.ser = $ser_event;
                        self.kind = BoundKind::Event;
                    }
                }
                Ok(())
            }
            fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
                (self.ser)(fixture, out)
            }
            fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
                use crate::serializers::kinded::BoundKind;
                match self.kind {
                    BoundKind::Message => Ok(Fixture::Message($de_message(data)?)),
                    BoundKind::Document => Ok(Fixture::Document($de_document(data)?)),
                    BoundKind::Telemetry => Ok(Fixture::Telemetry($de_telemetry(data)?)),
                    BoundKind::Strings => Ok(Fixture::Strings($de_strings(data)?)),
                    BoundKind::Event => Ok(Fixture::Event($de_event(data)?)),
                }
            }
        }
    };
}

pub(crate) use impl_kinded_direct;
