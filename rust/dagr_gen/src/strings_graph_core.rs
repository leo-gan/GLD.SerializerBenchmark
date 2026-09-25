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
    pub struct Strings<'a> {
        pub items: &'a [&'a str],
    }

    impl<'a> Strings<'a> {
        pub fn store_packed<B: PackedSink + ?Sized>(&self, b: &mut B) -> Result<NodeStoreRef, DagrError> {
            let _before = b.cursor();
            {
                let _items_arr = &self.items;
                if !_items_arr.is_empty() {
                let _cnt_items = _items_arr.len();
                let _bef_items = b.cursor();
                for _e in _items_arr.iter().rev() { b.store_blob(_e.as_bytes())?; }
                b.store_leb(_cnt_items as u64)?;
                b.store_leb((b.cursor() - _bef_items) as u64)?;
                    b.store_leb((0u64 << 1) | 1)?;
                }
            }
            b.store_leb((b.cursor() - _before) as u64)?;
            Ok(NodeStoreRef::Offset(b.cursor()))
        }
    }

    /// 36 §8 — build the finished buffer (body, alignment, framing) into any `PackedSink`,
    /// e.g. a stack `FixedBuilder`: no heap. Start from an empty (reset) builder; returns the
    /// buffer length, the bytes are `b.record_bytes()`.
    pub fn write_into<B: PackedSink + ?Sized>(root: &Strings<'_>, b: &mut B) -> Result<usize, DagrError> {
        let root_ref = root.store_packed(b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2)?;
        Ok(b.cursor())
    }

    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &Strings<'_>) -> Result<Vec<u8>, DagrError> {
        let mut b = DagrBuilder::with_capacity(4096);   // direct = tree → small buffer, grows if needed
        write_into(root, &mut b)?;
        Ok(b.finalize())
    }

    #[cfg(not(dagr_no_std))]
    pub struct Writer;
    #[cfg(not(dagr_no_std))]
    impl Writer {
        pub fn new() -> Self { Writer }
        pub fn to_bytes(&mut self, root: &Strings<'_>) -> Result<Vec<u8>, DagrError> { to_bytes(root) }
    }
    #[cfg(not(dagr_no_std))]
    impl Default for Writer { fn default() -> Self { Writer::new() } }
}

pub struct StringsGraph;
impl StringsGraph {
    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &direct::Strings<'_>) -> Result<Vec<u8>, crate::dagr_runtime::DagrError> { direct::to_bytes(root) }
    pub fn write_into<B: crate::dagr_runtime::PackedSink + ?Sized>(root: &direct::Strings<'_>, b: &mut B) -> Result<usize, crate::dagr_runtime::DagrError> { direct::write_into(root, b) }
}