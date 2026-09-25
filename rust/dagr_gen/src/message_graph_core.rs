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
    pub struct Message<'a> {
        pub f_bool: Option<bool>,
        pub f_int32: Option<i32>,
        pub f_int64: Option<i64>,
        pub f_float64: Option<f64>,
        pub f_string: Option<&'a str>,
        pub f_bool_2: Option<bool>,
        pub f_int32_2: Option<i32>,
        pub f_string_2: Option<&'a str>,
    }

    impl<'a> Message<'a> {
        pub fn store_packed<B: PackedSink + ?Sized>(&self, b: &mut B) -> Result<NodeStoreRef, DagrError> {
            let _before = b.cursor();
            if let Some(_s) = self.f_string_2.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs)?; b.store_leb(_bs.len() as u64)?; b.store_leb((7u64 << 1) | 1)?; }
            if let Some(_v) = self.f_int32_2 { let _zz = crate::dagr_runtime::to_zigzag(_v as i64); if crate::dagr_runtime::leb_length(_zz) < 4 { b.store_leb(_zz)?; b.store_leb((6u64 << 1) | 0)?; } else { b.store_i32(_v)?; b.store_leb((6u64 << 1) | 1)?; } }
            if let Some(_v) = self.f_bool_2 { b.store_bool(_v)?; b.store_leb((5u64 << 1) | 1)?; }
            if let Some(_s) = self.f_string.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs)?; b.store_leb(_bs.len() as u64)?; b.store_leb((4u64 << 1) | 1)?; }
            if let Some(_v) = self.f_float64 { if b.store_packed_f64(_v)? { b.store_leb((3u64 << 1) | 0)?; } else { b.store_leb((3u64 << 1) | 1)?; } }
            if let Some(_v) = self.f_int64 { let _zz = crate::dagr_runtime::to_zigzag(_v as i64); if crate::dagr_runtime::leb_length(_zz) < 8 { b.store_leb(_zz)?; b.store_leb((2u64 << 1) | 0)?; } else { b.store_i64(_v)?; b.store_leb((2u64 << 1) | 1)?; } }
            if let Some(_v) = self.f_int32 { let _zz = crate::dagr_runtime::to_zigzag(_v as i64); if crate::dagr_runtime::leb_length(_zz) < 4 { b.store_leb(_zz)?; b.store_leb((1u64 << 1) | 0)?; } else { b.store_i32(_v)?; b.store_leb((1u64 << 1) | 1)?; } }
            if let Some(_v) = self.f_bool { b.store_bool(_v)?; b.store_leb((0u64 << 1) | 1)?; }
            b.store_leb((b.cursor() - _before) as u64)?;
            Ok(NodeStoreRef::Offset(b.cursor()))
        }
    }

    /// 36 §8 — build the finished buffer (body, alignment, framing) into any `PackedSink`,
    /// e.g. a stack `FixedBuilder`: no heap. Start from an empty (reset) builder; returns the
    /// buffer length, the bytes are `b.record_bytes()`.
    pub fn write_into<B: PackedSink + ?Sized>(root: &Message<'_>, b: &mut B) -> Result<usize, DagrError> {
        let root_ref = root.store_packed(b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2)?;
        Ok(b.cursor())
    }

    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &Message<'_>) -> Result<Vec<u8>, DagrError> {
        let mut b = DagrBuilder::with_capacity(4096);   // direct = tree → small buffer, grows if needed
        write_into(root, &mut b)?;
        Ok(b.finalize())
    }

    #[cfg(not(dagr_no_std))]
    pub struct Writer;
    #[cfg(not(dagr_no_std))]
    impl Writer {
        pub fn new() -> Self { Writer }
        pub fn to_bytes(&mut self, root: &Message<'_>) -> Result<Vec<u8>, DagrError> { to_bytes(root) }
    }
    #[cfg(not(dagr_no_std))]
    impl Default for Writer { fn default() -> Self { Writer::new() } }
}

pub struct MessageGraph;
impl MessageGraph {
    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &direct::Message<'_>) -> Result<Vec<u8>, crate::dagr_runtime::DagrError> { direct::to_bytes(root) }
    pub fn write_into<B: crate::dagr_runtime::PackedSink + ?Sized>(root: &direct::Message<'_>, b: &mut B) -> Result<usize, crate::dagr_runtime::DagrError> { direct::write_into(root, b) }
}