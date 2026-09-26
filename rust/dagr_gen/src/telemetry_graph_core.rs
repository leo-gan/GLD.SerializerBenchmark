#![allow(dead_code, non_snake_case, unused_imports, unused_variables, unexpected_cfgs, clippy::all)]
#[cfg(all(dagr_no_std, not(dagr_no_alloc)))] use alloc::{vec, vec::Vec, string::String, string::ToString, boxed::Box, borrow::ToOwned};
use crate::dagr_runtime::{DagrError, PackedSink, StorePacked};


// ── Direct Graph Builder ("spec/33-direct-graph-builder.md") ─────────────────────
// Arena-free construction for this packed-rooted tree: plain value structs in,
// byte-identical graph buffer out. `direct::to_bytes*(v) == arena.to_bytes*()`.
pub mod direct {
    use crate::dagr_runtime::{NodeStoreRef, DagrError, PackedSink};
    #[cfg(not(dagr_no_std))] use crate::dagr_runtime::DagrBuilder;
    #[cfg(all(dagr_no_std, not(dagr_no_alloc)))] use alloc::vec::Vec;

    #[derive(Debug, Clone, PartialEq)]
    pub struct Telemetry<'a> {
        pub source: Option<&'a str>,
        pub ts: Option<i64>,
        pub tags: &'a [&'a str],
        pub values: &'a [f64],
    }

    impl<'a> Telemetry<'a> {
        pub fn store_packed<B: PackedSink + ?Sized>(&self, b: &mut B) -> Result<NodeStoreRef, DagrError> {
            let _before = b.cursor();
            {
                let _values_arr = &self.values;
                if !_values_arr.is_empty() {
                let _cnt_values = _values_arr.len();
                let _bef_values = b.cursor();
                for &_e in _values_arr.iter().rev() { b.store_f64(_e)?; }
                b.store_leb(((_cnt_values as u64) << 2) | 1)?;
                b.store_leb((b.cursor() - _bef_values) as u64)?;
                    b.store_leb((3u64 << 1) | 1)?;
                }
            }
            {
                let _tags_arr = &self.tags;
                if !_tags_arr.is_empty() {
                let _cnt_tags = _tags_arr.len();
                let _bef_tags = b.cursor();
                for _e in _tags_arr.iter().rev() { b.store_blob(_e.as_bytes())?; }
                b.store_leb(_cnt_tags as u64)?;
                b.store_leb((b.cursor() - _bef_tags) as u64)?;
                    b.store_leb((2u64 << 1) | 1)?;
                }
            }
            if let Some(_v) = self.ts { let _zz = crate::dagr_runtime::to_zigzag(_v as i64); if crate::dagr_runtime::leb_length(_zz) < 8 { b.store_leb(_zz)?; b.store_leb((1u64 << 1) | 0)?; } else { b.store_i64(_v)?; b.store_leb((1u64 << 1) | 1)?; } }
            if let Some(_s) = self.source.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs)?; b.store_leb(_bs.len() as u64)?; b.store_leb((0u64 << 1) | 1)?; }
            b.store_leb((b.cursor() - _before) as u64)?;
            Ok(NodeStoreRef::Offset(b.cursor()))
        }
    }

    /// 36 §8 — build the finished buffer (body, alignment, framing) into any `PackedSink`,
    /// e.g. a stack `FixedBuilder`: no heap. Start from an empty (reset) builder; returns the
    /// buffer length, the bytes are `b.record_bytes()`.
    pub fn write_into<B: PackedSink + ?Sized>(root: &Telemetry<'_>, b: &mut B) -> Result<usize, DagrError> {
        let root_ref = root.store_packed(b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2)?;
        Ok(b.cursor())
    }

    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &Telemetry<'_>) -> Result<Vec<u8>, DagrError> {
        let mut b = DagrBuilder::with_capacity(4096);   // direct = tree → small buffer, grows if needed
        write_into(root, &mut b)?;
        Ok(b.finalize())
    }

    #[cfg(not(dagr_no_std))]
    pub struct Writer;
    #[cfg(not(dagr_no_std))]
    impl Writer {
        pub fn new() -> Self { Writer }
        pub fn to_bytes(&mut self, root: &Telemetry<'_>) -> Result<Vec<u8>, DagrError> { to_bytes(root) }
    }
    #[cfg(not(dagr_no_std))]
    impl Default for Writer { fn default() -> Self { Writer::new() } }
}

pub struct TelemetryGraph;
impl TelemetryGraph {
    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &direct::Telemetry<'_>) -> Result<Vec<u8>, crate::dagr_runtime::DagrError> { direct::to_bytes(root) }
    pub fn write_into<B: crate::dagr_runtime::PackedSink + ?Sized>(root: &direct::Telemetry<'_>, b: &mut B) -> Result<usize, crate::dagr_runtime::DagrError> { direct::write_into(root, b) }
}