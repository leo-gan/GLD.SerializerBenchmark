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
    pub struct DocumentMeta<'a> {
        pub region: Option<&'a str>,
        pub version: Option<i32>,
    }

    #[derive(Debug, Clone, PartialEq)]
    pub struct DocumentItem<'a> {
        pub sku: Option<&'a str>,
        pub qty: Option<i32>,
        pub price_minor: Option<i64>,
    }

    #[derive(Debug, Clone, PartialEq)]
    pub struct Document<'a> {
        pub id: Option<&'a str>,
        pub status: Option<i32>,
        pub meta: Option<&'a DocumentMeta<'a>>,
        pub items: &'a [DocumentItem<'a>],
    }

    impl<'a> DocumentMeta<'a> {
        pub fn store_packed<B: PackedSink + ?Sized>(&self, b: &mut B) -> Result<NodeStoreRef, DagrError> {
            let _before = b.cursor();
            let mut _obs0 = 0u8;
            _obs0 |= u8::from(self.region.is_some()) << 0;
            _obs0 |= u8::from(self.version.is_some()) << 1;
            let mut _ebs0 = 0u8;
            if let Some(_v) = self.version { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v as i64)) >= 4) << 0; }
            if let Some(_v) = self.version { if _ebs0 & 1 != 0 { b.store_i32(_v)?; } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v as i64))?; } }
            if let Some(_s) = self.region.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs)?; b.store_leb(_bs.len() as u64)?; }
            b.store_u8(_ebs0)?;
            b.store_u8(_obs0)?;
            b.store_leb((b.cursor() - _before) as u64)?;
            Ok(NodeStoreRef::Offset(b.cursor()))
        }
    }

    impl<'a> DocumentItem<'a> {
        pub fn store_packed<B: PackedSink + ?Sized>(&self, b: &mut B) -> Result<NodeStoreRef, DagrError> {
            let _before = b.cursor();
            let mut _obs0 = 0u8;
            _obs0 |= u8::from(self.sku.is_some()) << 0;
            _obs0 |= u8::from(self.qty.is_some()) << 1;
            _obs0 |= u8::from(self.price_minor.is_some()) << 2;
            let mut _ebs0 = 0u8;
            if let Some(_v) = self.qty { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v as i64)) >= 4) << 0; }
            if let Some(_v) = self.price_minor { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v as i64)) >= 8) << 1; }
            if let Some(_v) = self.price_minor { if _ebs0 & 2 != 0 { b.store_i64(_v)?; } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v as i64))?; } }
            if let Some(_v) = self.qty { if _ebs0 & 1 != 0 { b.store_i32(_v)?; } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v as i64))?; } }
            if let Some(_s) = self.sku.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs)?; b.store_leb(_bs.len() as u64)?; }
            b.store_u8(_ebs0)?;
            b.store_u8(_obs0)?;
            b.store_leb((b.cursor() - _before) as u64)?;
            Ok(NodeStoreRef::Offset(b.cursor()))
        }
    }

    impl<'a> Document<'a> {
        pub fn store_packed<B: PackedSink + ?Sized>(&self, b: &mut B) -> Result<NodeStoreRef, DagrError> {
            let _before = b.cursor();
            let mut _obs0 = 0u8;
            _obs0 |= u8::from(self.id.is_some()) << 0;
            _obs0 |= u8::from(self.status.is_some()) << 1;
            _obs0 |= u8::from(self.meta.is_some()) << 2;
            _obs0 |= u8::from(!self.items.is_empty()) << 3;
            let mut _ebs0 = 0u8;
            if let Some(_v) = self.status { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v as i64)) >= 4) << 0; }
            {
                let _items_arr = &self.items;
                if !_items_arr.is_empty() {
                let _cnt_items = _items_arr.len();
                let _bef_items = b.cursor();
                for _e in _items_arr.iter().rev() { _e.store_packed(b)?; }
                b.store_leb(_cnt_items as u64)?;
                b.store_leb((b.cursor() - _bef_items) as u64)?;
                }
            }
            if let Some(_n) = self.meta { _n.store_packed(b)?; }
            if let Some(_v) = self.status { if _ebs0 & 1 != 0 { b.store_i32(_v)?; } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v as i64))?; } }
            if let Some(_s) = self.id.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs)?; b.store_leb(_bs.len() as u64)?; }
            b.store_u8(_ebs0)?;
            b.store_u8(_obs0)?;
            b.store_leb((b.cursor() - _before) as u64)?;
            Ok(NodeStoreRef::Offset(b.cursor()))
        }
    }

    /// 36 §8 — build the finished buffer (body, alignment, framing) into any `PackedSink`,
    /// e.g. a stack `FixedBuilder`: no heap. Start from an empty (reset) builder; returns the
    /// buffer length, the bytes are `b.record_bytes()`.
    pub fn write_into<B: PackedSink + ?Sized>(root: &Document<'_>, b: &mut B) -> Result<usize, DagrError> {
        let root_ref = root.store_packed(b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2)?;
        Ok(b.cursor())
    }

    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &Document<'_>) -> Result<Vec<u8>, DagrError> {
        let mut b = DagrBuilder::with_capacity(4096);   // direct = tree → small buffer, grows if needed
        write_into(root, &mut b)?;
        Ok(b.finalize())
    }

    #[cfg(not(dagr_no_std))]
    pub struct Writer;
    #[cfg(not(dagr_no_std))]
    impl Writer {
        pub fn new() -> Self { Writer }
        pub fn to_bytes(&mut self, root: &Document<'_>) -> Result<Vec<u8>, DagrError> { to_bytes(root) }
    }
    #[cfg(not(dagr_no_std))]
    impl Default for Writer { fn default() -> Self { Writer::new() } }
}

pub struct DocumentFrozenPackedGraph;
impl DocumentFrozenPackedGraph {
    #[cfg(not(dagr_no_std))]
    pub fn to_bytes(root: &direct::Document<'_>) -> Result<Vec<u8>, crate::dagr_runtime::DagrError> { direct::to_bytes(root) }
    pub fn write_into<B: crate::dagr_runtime::PackedSink + ?Sized>(root: &direct::Document<'_>, b: &mut B) -> Result<usize, crate::dagr_runtime::DagrError> { direct::write_into(root, b) }
}