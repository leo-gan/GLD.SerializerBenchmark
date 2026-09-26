#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

// ── DocumentMetaValues ──────────────────────────────────────────────────────────
pub struct DocumentMetaValues {
    pub region: Option<String>,
    pub version: Option<i32>,
}

// ── DocumentItemValues ──────────────────────────────────────────────────────────
pub struct DocumentItemValues {
    pub sku: Option<String>,
    pub qty: Option<i32>,
    pub price_minor: Option<i64>,
}

// ── DocumentValues ──────────────────────────────────────────────────────────
pub struct DocumentValues {
    pub id: Option<String>,
    pub status: Option<i32>,
    pub meta: Option<NodeRef>,
    pub items: Vec<NodeRef>,
}

pub trait DocumentMetaArena {
    const DOCUMENTMETA_TYPE_ID: u64;
    fn arena_of_document_meta(&self) -> &RefCell<Vec<DocumentMetaValues>>;
}

pub trait DocumentItemArena {
    const DOCUMENTITEM_TYPE_ID: u64;
    fn arena_of_document_item(&self) -> &RefCell<Vec<DocumentItemValues>>;
}

pub trait DocumentArena {
    const DOCUMENT_TYPE_ID: u64;
    fn arena_of_document(&self) -> &RefCell<Vec<DocumentValues>>;
}

// ── DocumentFrozenGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait DocumentFrozenGraphGraph: DocumentMetaArena + DocumentItemArena + DocumentArena {
    fn new_document_meta(&self, region: Option<&str>, version: Option<i32>) -> DocumentMeta<'_, Self> where Self: Sized {
        let _values = DocumentMetaValues {
                region: region.map(str::to_owned),
                version: version,
        };
        let index = {
            let mut _arena = self.arena_of_document_meta().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        DocumentMeta { index: index, graph: self }
    }
    fn new_document_meta_defaulted(&self) -> DocumentMeta<'_, Self> where Self: Sized {
        self.new_document_meta(None, None)
    }
    fn new_document_item(&self, sku: Option<&str>, qty: Option<i32>, price_minor: Option<i64>) -> DocumentItem<'_, Self> where Self: Sized {
        let _values = DocumentItemValues {
                sku: sku.map(str::to_owned),
                qty: qty,
                price_minor: price_minor,
        };
        let index = {
            let mut _arena = self.arena_of_document_item().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        DocumentItem { index: index, graph: self }
    }
    fn new_document_item_defaulted(&self) -> DocumentItem<'_, Self> where Self: Sized {
        self.new_document_item(None, None, None)
    }
    fn new_document(&self, id: Option<&str>, status: Option<i32>, meta: Option<DocumentMeta<'_, Self>>, items: &[DocumentItem<'_, Self>]) -> Document<'_, Self> where Self: Sized {
        let _values = DocumentValues {
                id: id.map(str::to_owned),
                status: status,
                meta: meta.filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }),
                items: items.iter().filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }).collect(),
        };
        let index = {
            let mut _arena = self.arena_of_document().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Document { index: index, graph: self }
    }
    fn new_document_defaulted(&self) -> Document<'_, Self> where Self: Sized {
        self.new_document(None, None, None, &[])
    }
}
impl<T: DocumentMetaArena + DocumentItemArena + DocumentArena> DocumentFrozenGraphGraph for T {}

// ── DocumentMeta handle ────────────────────────────────────────────────────────
pub struct DocumentMeta<'arena, G: DocumentFrozenGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: DocumentFrozenGraphGraph> Clone for DocumentMeta<'arena, G> {
    fn clone(&self) -> Self { DocumentMeta { index: self.index, graph: self.graph } }
}
impl<'arena, G: DocumentFrozenGraphGraph> Copy for DocumentMeta<'arena, G> {}

impl<'arena, G: DocumentFrozenGraphGraph> DocumentMeta<'arena, G> {
    pub fn region(&self) -> Option<String> {
        self.graph.arena_of_document_meta().borrow()[self.index as usize].region.clone()
    }
    pub fn set_region(&self, v: Option<&str>) {
        self.graph.arena_of_document_meta().borrow_mut()[self.index as usize].region = v.map(str::to_owned);
    }
    pub fn version(&self) -> Option<i32> {
        self.graph.arena_of_document_meta().borrow()[self.index as usize].version
    }
    pub fn set_version(&self, v: Option<i32>) {
        self.graph.arena_of_document_meta().borrow_mut()[self.index as usize].version = v;
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::DOCUMENTMETA_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.region().hash(state);
        self.version().hash(state);
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "DocumentMeta@{}", self.index);
        }
        write!(f, "DocumentMeta@{} {{ ", self.index)?;
        write!(f, "region: {:?}, ", self.region())?;
        write!(f, "version: {:?}", self.version())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: DocumentFrozenGraphGraph>(&self, other: &DocumentMeta<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.region() != other.region() { return false; }
        if self.version() != other.version() { return false; }
        true
    }
}

impl<'a, 'b, A: DocumentFrozenGraphGraph, B: DocumentFrozenGraphGraph> PartialEq<DocumentMeta<'b, B>> for DocumentMeta<'a, A> {
    fn eq(&self, other: &DocumentMeta<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: DocumentFrozenGraphGraph> Eq for DocumentMeta<'arena, G> {}

impl<'arena, G: DocumentFrozenGraphGraph> std::hash::Hash for DocumentMeta<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: DocumentFrozenGraphGraph> fmt::Display for DocumentMeta<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── DocumentItem handle ────────────────────────────────────────────────────────
pub struct DocumentItem<'arena, G: DocumentFrozenGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: DocumentFrozenGraphGraph> Clone for DocumentItem<'arena, G> {
    fn clone(&self) -> Self { DocumentItem { index: self.index, graph: self.graph } }
}
impl<'arena, G: DocumentFrozenGraphGraph> Copy for DocumentItem<'arena, G> {}

impl<'arena, G: DocumentFrozenGraphGraph> DocumentItem<'arena, G> {
    pub fn sku(&self) -> Option<String> {
        self.graph.arena_of_document_item().borrow()[self.index as usize].sku.clone()
    }
    pub fn set_sku(&self, v: Option<&str>) {
        self.graph.arena_of_document_item().borrow_mut()[self.index as usize].sku = v.map(str::to_owned);
    }
    pub fn qty(&self) -> Option<i32> {
        self.graph.arena_of_document_item().borrow()[self.index as usize].qty
    }
    pub fn set_qty(&self, v: Option<i32>) {
        self.graph.arena_of_document_item().borrow_mut()[self.index as usize].qty = v;
    }
    pub fn price_minor(&self) -> Option<i64> {
        self.graph.arena_of_document_item().borrow()[self.index as usize].price_minor
    }
    pub fn set_price_minor(&self, v: Option<i64>) {
        self.graph.arena_of_document_item().borrow_mut()[self.index as usize].price_minor = v;
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::DOCUMENTITEM_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.sku().hash(state);
        self.qty().hash(state);
        self.price_minor().hash(state);
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "DocumentItem@{}", self.index);
        }
        write!(f, "DocumentItem@{} {{ ", self.index)?;
        write!(f, "sku: {:?}, ", self.sku())?;
        write!(f, "qty: {:?}, ", self.qty())?;
        write!(f, "price_minor: {:?}", self.price_minor())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: DocumentFrozenGraphGraph>(&self, other: &DocumentItem<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.sku() != other.sku() { return false; }
        if self.qty() != other.qty() { return false; }
        if self.price_minor() != other.price_minor() { return false; }
        true
    }
}

impl<'a, 'b, A: DocumentFrozenGraphGraph, B: DocumentFrozenGraphGraph> PartialEq<DocumentItem<'b, B>> for DocumentItem<'a, A> {
    fn eq(&self, other: &DocumentItem<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: DocumentFrozenGraphGraph> Eq for DocumentItem<'arena, G> {}

impl<'arena, G: DocumentFrozenGraphGraph> std::hash::Hash for DocumentItem<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: DocumentFrozenGraphGraph> fmt::Display for DocumentItem<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── Document handle ────────────────────────────────────────────────────────
pub struct Document<'arena, G: DocumentFrozenGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: DocumentFrozenGraphGraph> Clone for Document<'arena, G> {
    fn clone(&self) -> Self { Document { index: self.index, graph: self.graph } }
}
impl<'arena, G: DocumentFrozenGraphGraph> Copy for Document<'arena, G> {}

impl<'arena, G: DocumentFrozenGraphGraph> Document<'arena, G> {
    pub fn id(&self) -> Option<String> {
        self.graph.arena_of_document().borrow()[self.index as usize].id.clone()
    }
    pub fn set_id(&self, v: Option<&str>) {
        self.graph.arena_of_document().borrow_mut()[self.index as usize].id = v.map(str::to_owned);
    }
    pub fn status(&self) -> Option<i32> {
        self.graph.arena_of_document().borrow()[self.index as usize].status
    }
    pub fn set_status(&self, v: Option<i32>) {
        self.graph.arena_of_document().borrow_mut()[self.index as usize].status = v;
    }
    pub fn meta(&self) -> Option<DocumentMeta<'arena, G>> {
        let nr = {
            let arena = self.graph.arena_of_document().borrow();
            arena.get(self.index as usize)
                .and_then(|v| v.meta)
        };
        nr.and_then(|nr| {
            let a = self.graph.arena_of_document_meta().borrow();
            a.get(nr.index as usize)
                .map(|_| DocumentMeta { index: nr.index, graph: self.graph })
        })
    }
    pub fn set_meta(&self, v: Option<DocumentMeta<'_, G>>) {
        let nr = v.filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
                  .map(|h| NodeRef { index: h.index });
        self.graph.arena_of_document().borrow_mut()[self.index as usize].meta = nr;
    }
    pub fn items(&self) -> Vec<DocumentItem<'arena, G>> {
        let nrs: Vec<_> = {
            let arena = self.graph.arena_of_document().borrow();
            match arena.get(self.index as usize) {
                Some(v) => v.items.clone(),
                _ => return vec![],
            }
        };
        nrs.into_iter().map(|nr| DocumentItem { index: nr.index, graph: self.graph }).collect()
    }
    pub fn set_items(&self, vs: &[DocumentItem<'_, G>]) {
        let nrs = vs.iter()
            .filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
            .map(|h| NodeRef { index: h.index }).collect();
        self.graph.arena_of_document().borrow_mut()[self.index as usize].items = nrs;
    }
    pub fn push_items(&self, v: DocumentItem<'_, G>) {
        if std::ptr::eq(v.graph as *const G, self.graph as *const G) {
            let nr = NodeRef { index: v.index };
            self.graph.arena_of_document().borrow_mut()[self.index as usize].items.push(nr);
        }
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::DOCUMENT_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.id().hash(state);
        self.status().hash(state);
        if let Some(v) = self.meta() { v._hash_with(state, visited); }
        for v in &self.items() { v._hash_with(state, visited); }
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Document@{}", self.index);
        }
        write!(f, "Document@{} {{ ", self.index)?;
        write!(f, "id: {:?}, ", self.id())?;
        write!(f, "status: {:?}, ", self.status())?;
        write!(f, "meta: ")?;
        match self.meta() { Some(v) => v._fmt_with(f, visited)?, None => write!(f, "None")? };
        write!(f, ", ")?;
        write!(f, "items: [")?;
        { let _items = self.items(); for (_i, _v) in _items.iter().enumerate() {
            if _i > 0 { write!(f, ", ")?; } _v._fmt_with(f, visited)?;
        } }
        write!(f, "]")?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: DocumentFrozenGraphGraph>(&self, other: &Document<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.id() != other.id() { return false; }
        if self.status() != other.status() { return false; }
        match (self.meta(), other.meta()) {
            (None, None) => {}
            (Some(a), Some(b)) => { if !a._cycle_eq(&b, visited) { return false; } }
            _ => return false,
        }
        { let sa = self.items(); let sb = other.items();
          if sa.len() != sb.len() { return false; }
          if !sa.iter().zip(sb.iter()).all(|(a, b)| a._cycle_eq(b, visited)) { return false; } }
        true
    }
}

impl<'a, 'b, A: DocumentFrozenGraphGraph, B: DocumentFrozenGraphGraph> PartialEq<Document<'b, B>> for Document<'a, A> {
    fn eq(&self, other: &Document<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: DocumentFrozenGraphGraph> Eq for Document<'arena, G> {}

impl<'arena, G: DocumentFrozenGraphGraph> std::hash::Hash for Document<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: DocumentFrozenGraphGraph> fmt::Display for Document<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── DocumentFrozenGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct DocumentFrozenGraphArena<const ID: u64> {
    arena_of_document_meta: RefCell<Vec<DocumentMetaValues>>,
    arena_of_document_item: RefCell<Vec<DocumentItemValues>>,
    arena_of_document: RefCell<Vec<DocumentValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> DocumentMetaArena for DocumentFrozenGraphArena<ID> {
    const DOCUMENTMETA_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_document_meta(&self) -> &RefCell<Vec<DocumentMetaValues>> {
        &self.arena_of_document_meta
    }
}

impl<const ID: u64> DocumentItemArena for DocumentFrozenGraphArena<ID> {
    const DOCUMENTITEM_TYPE_ID: u64 = ID * 100 + 1;
    fn arena_of_document_item(&self) -> &RefCell<Vec<DocumentItemValues>> {
        &self.arena_of_document_item
    }
}

impl<const ID: u64> DocumentArena for DocumentFrozenGraphArena<ID> {
    const DOCUMENT_TYPE_ID: u64 = ID * 100 + 2;
    fn arena_of_document(&self) -> &RefCell<Vec<DocumentValues>> {
        &self.arena_of_document
    }
}

impl<const ID: u64> DocumentFrozenGraphArena<ID> {
    pub fn new() -> Self {
        DocumentFrozenGraphArena {
            arena_of_document_meta: RefCell::new(Vec::new()),
            arena_of_document_item: RefCell::new(Vec::new()),
            arena_of_document: RefCell::new(Vec::new()),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Document<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_document().borrow();
            a.get(nr.index as usize)
                .map(|_| Document { index: nr.index, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Document<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index }));
    }
}

impl<const ID: u64> Default for DocumentFrozenGraphArena<ID> {
    fn default() -> Self { Self::new() }
}


// ── Serde: use dagr_runtime ─────────────────────────────────────────────────
use crate::dagr_runtime::{DagrBuilder, NodeStoreRef, CycleId, DagrError};
use crate::dagr_runtime;

fn _store_prim_array(offsets: &[Option<usize>], content_cursor: usize, b: &mut DagrBuilder) -> usize {
    // Value refs (utf8/data/nested arrays): inline just before the table -> UNSIGNED slots (spec §4.5).
    let mut width_code = 0usize;
    for opt in offsets {
        if let Some(off) = opt {
            let rel = (content_cursor - *off + 1) as u64;
            let wc = if rel <= u8::MAX as u64 { 0 } else if rel <= u16::MAX as u64 { 1 } else if rel <= u32::MAX as u64 { 2 } else { 3 };
            if wc > width_code { width_code = wc; }
        }
    }
    for opt in offsets.iter() {
        match opt {
            Some(off) => { let rel = (content_cursor - *off + 1) as u64; b.store_uint_w(rel, width_code); }
            None => { b.store_uint_w(0, width_code); }
        }
    }
    b.store_leb(((offsets.len() as u64) << 2) | (width_code as u64))
}

// ── DocumentMeta serde ──────────────────────────────────────────────────────────
impl<'arena, G: DocumentFrozenGraphGraph> DocumentMeta<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::DOCUMENTMETA_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_document_meta().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _region_off = _pr.region.as_deref().map(|s| b.store_string(s));
        if let Some(_v_version) = self.version() { b.store_i32(_v_version); }
        if let Some(off) = _region_off { b.store_forward_pointer(off); }
        b.store_u8(u8::from(_pr.region.is_some()) | (u8::from(self.version().is_some()) << 1));
        let _offset = b.cursor();
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::DOCUMENTMETA_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_document_meta().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _obs0 = 0u8;
        _obs0 |= u8::from(_pr.region.is_some()) << 0;
        _obs0 |= u8::from(self.version().is_some()) << 1;
        let mut _ebs0 = 0u8;
        if let Some(_v_version) = self.version() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_version as i64)) >= 4) << 0; }
        if let Some(_v_version) = self.version() { if _ebs0 & 1 != 0 { b.store_i32(_v_version); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_version as i64)); } }
        if let Some(_s_region) = _pr.region.as_deref() {
            let _bs_region = _s_region.as_bytes();
            b.store_raw(_bs_region);
            b.store_leb(_bs_region.len() as u64);
        }
        b.store_u8(_ebs0);
        b.store_u8(_obs0);
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

// ── DocumentItem serde ──────────────────────────────────────────────────────────
impl<'arena, G: DocumentFrozenGraphGraph> DocumentItem<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::DOCUMENTITEM_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_document_item().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _sku_off = _pr.sku.as_deref().map(|s| b.store_string(s));
        if let Some(_v_price_minor) = self.price_minor() { b.store_i64(_v_price_minor); }
        if let Some(_v_qty) = self.qty() { b.store_i32(_v_qty); }
        if let Some(off) = _sku_off { b.store_forward_pointer(off); }
        b.store_u8(u8::from(_pr.sku.is_some()) | (u8::from(self.qty().is_some()) << 1) | (u8::from(self.price_minor().is_some()) << 2));
        let _offset = b.cursor();
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::DOCUMENTITEM_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_document_item().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _obs0 = 0u8;
        _obs0 |= u8::from(_pr.sku.is_some()) << 0;
        _obs0 |= u8::from(self.qty().is_some()) << 1;
        _obs0 |= u8::from(self.price_minor().is_some()) << 2;
        let mut _ebs0 = 0u8;
        if let Some(_v_qty) = self.qty() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_qty as i64)) >= 4) << 0; }
        if let Some(_v_price_minor) = self.price_minor() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_price_minor as i64)) >= 8) << 1; }
        if let Some(_v_price_minor) = self.price_minor() { if _ebs0 & 2 != 0 { b.store_i64(_v_price_minor); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_price_minor as i64)); } }
        if let Some(_v_qty) = self.qty() { if _ebs0 & 1 != 0 { b.store_i32(_v_qty); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_qty as i64)); } }
        if let Some(_s_sku) = _pr.sku.as_deref() {
            let _bs_sku = _s_sku.as_bytes();
            b.store_raw(_bs_sku);
            b.store_leb(_bs_sku.len() as u64);
        }
        b.store_u8(_ebs0);
        b.store_u8(_obs0);
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

// ── Document serde ──────────────────────────────────────────────────────────
impl<'arena, G: DocumentFrozenGraphGraph> Document<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::DOCUMENT_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_document().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _items_items = b.take_ref_scratch();
        {
            let _row_items = self.graph.arena_of_document().borrow();
            let _refs_items = &_row_items[self.index as usize].items;
            let _cb_items = self.graph.arena_of_document_item().borrow();
            for _nr in _refs_items.iter().rev() {
                if _cb_items.get(_nr.index as usize).is_some() {
                    _items_items.push(DocumentItem { index: _nr.index, graph: self.graph }.store(b).unwrap_or(NodeStoreRef::Offset(0)));
                }
            }
        }
        let _items_off = Some(b.store_node_ref_array(&_items_items, b.cursor()));
        b.return_ref_scratch(_items_items);
        let _meta_off = if let Some(n) = self.meta() { n.store(b).ok() } else { None };
        let _id_off = _pr.id.as_deref().map(|s| b.store_string(s));
        if let Some(off) = _items_off { b.store_forward_pointer(off); }
        if let Some(r) = _meta_off { b.store_bidir_pointer(r); }
        if let Some(_v_status) = self.status() { b.store_i32(_v_status); }
        if let Some(off) = _id_off { b.store_forward_pointer(off); }
        b.store_u8(u8::from(_pr.id.is_some()) | (u8::from(self.status().is_some()) << 1) | (u8::from(self.meta().is_some()) << 2) | (u8::from(!self.items().is_empty()) << 3));
        let _offset = b.cursor();
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::DOCUMENT_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_document().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _obs0 = 0u8;
        _obs0 |= u8::from(_pr.id.is_some()) << 0;
        _obs0 |= u8::from(self.status().is_some()) << 1;
        _obs0 |= u8::from(self.meta().is_some()) << 2;
        _obs0 |= u8::from(!self.items().is_empty()) << 3;
        let mut _ebs0 = 0u8;
        if let Some(_v_status) = self.status() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_status as i64)) >= 4) << 0; }
        {
            let _items_arr = self.items();
            if !_items_arr.is_empty() {
                let _cnt_items = _items_arr.len();
                let _bef_items = b.cursor();
                for _e in _items_arr.iter().rev() {
                    _e.store_packed(b)?;
                }
                b.store_leb(_cnt_items as u64);
                b.store_leb((b.cursor() - _bef_items) as u64);
            }
        }
        if let Some(_n_meta) = self.meta() {
            _n_meta.store_packed(b)?;
        }
        if let Some(_v_status) = self.status() { if _ebs0 & 1 != 0 { b.store_i32(_v_status); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_status as i64)); } }
        if let Some(_s_id) = _pr.id.as_deref() {
            let _bs_id = _s_id.as_bytes();
            b.store_raw(_bs_id);
            b.store_leb(_bs_id.len() as u64);
        }
        b.store_u8(_ebs0);
        b.store_u8(_obs0);
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_document_meta<'arena, G: DocumentFrozenGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<DocumentMeta<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::DOCUMENTMETA_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_document_meta().borrow();
        let _ = &a;
        return Ok(DocumentMeta { index: idx, graph: arena });
    }
    let _obs0 = *data.get(at + 0).ok_or(DagrError::InvalidData)?;
    let _blank = DocumentMetaValues { region: None, version: None };
    let _idx = {
        let mut _arr = arena.arena_of_document_meta().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = DocumentMeta { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let mut _cur = at + 1;
    let _region_val = if _obs0 & 1 != 0 {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _fwd_target = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        Some(crate::dagr_runtime::read_string(data, _fwd_target)?)
    } else { None };
    let _version_val = if _obs0 & 2 != 0 {
        let _rv = crate::dagr_runtime::read_i32(data, _cur)? as i32; _cur += 4; Some(_rv)
    } else { None };
    _node.set_region(_region_val.as_deref());
    _node.set_version(_version_val);
    Ok(_node)
}

fn _restore_document_item<'arena, G: DocumentFrozenGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<DocumentItem<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::DOCUMENTITEM_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_document_item().borrow();
        let _ = &a;
        return Ok(DocumentItem { index: idx, graph: arena });
    }
    let _obs0 = *data.get(at + 0).ok_or(DagrError::InvalidData)?;
    let _blank = DocumentItemValues { sku: None, qty: None, price_minor: None };
    let _idx = {
        let mut _arr = arena.arena_of_document_item().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = DocumentItem { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let mut _cur = at + 1;
    let _sku_val = if _obs0 & 1 != 0 {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _fwd_target = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        Some(crate::dagr_runtime::read_string(data, _fwd_target)?)
    } else { None };
    let _qty_val = if _obs0 & 2 != 0 {
        let _rv = crate::dagr_runtime::read_i32(data, _cur)? as i32; _cur += 4; Some(_rv)
    } else { None };
    let _price_minor_val = if _obs0 & 4 != 0 {
        let _rv = crate::dagr_runtime::read_i64(data, _cur)? as i64; _cur += 8; Some(_rv)
    } else { None };
    _node.set_sku(_sku_val.as_deref());
    _node.set_qty(_qty_val);
    _node.set_price_minor(_price_minor_val);
    Ok(_node)
}

fn _restore_document<'arena, G: DocumentFrozenGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Document<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::DOCUMENT_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_document().borrow();
        let _ = &a;
        return Ok(Document { index: idx, graph: arena });
    }
    let _obs0 = *data.get(at + 0).ok_or(DagrError::InvalidData)?;
    let _blank = DocumentValues { id: None, status: None, meta: None, items: vec![] };
    let _idx = {
        let mut _arr = arena.arena_of_document().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Document { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let mut _cur = at + 1;
    let _id_val = if _obs0 & 1 != 0 {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _fwd_target = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        Some(crate::dagr_runtime::read_string(data, _fwd_target)?)
    } else { None };
    let _status_val = if _obs0 & 2 != 0 {
        let _rv = crate::dagr_runtime::read_i32(data, _cur)? as i32; _cur += 4; Some(_rv)
    } else { None };
    let _meta_val = if _obs0 & 4 != 0 {
        let (_bd_raw, _bd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _bd_diff = crate::dagr_runtime::from_zigzag(_bd_raw) as isize;
        let _bd_target = (_cur + _bd_bs).wrapping_add_signed(_bd_diff);
        _cur += _bd_bs;
        Some(_restore_document_meta(data, _bd_target, arena, cache)?)
    } else { None };
    let _items_val = if _cur < data.len() {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _at_items = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        let _items: Result<Vec<_>, DagrError> = crate::dagr_runtime::read_node_ref_array(data, _at_items)?.into_iter()
            .filter_map(|p| p.map(|a| _restore_document_item(data, a, arena, cache)))
            .collect();
        _items?
    } else { vec![] };
    _node.set_id(_id_val.as_deref());
    _node.set_status(_status_val);
    _node.set_meta(_meta_val);
    _node.set_items(&_items_val);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> DocumentFrozenGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_document_meta().borrow().len() + self.arena_of_document_item().borrow().len() + self.arena_of_document().borrow().len());
        let root_ref = root.store(&mut b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2);
        Ok(b.finalize())
    }

    /// Build the finished buffer (body, alignment, framing) into a caller-owned builder, so an
    /// encode loop reuses one buffer and its dedup maps. Start from a fresh or `reset()` builder;
    /// returns the buffer length, the bytes are `b.record_bytes()`. Same contract as the direct
    /// builder's `write_into`.
    pub fn write_into(&self, b: &mut DagrBuilder) -> Result<usize, DagrError> {
        let root = self.get_root().ok_or(DagrError::StaleReference)?;
        let root_ref = root.store(b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2);
        Ok(b.cursor())
    }

    /// Like `to_bytes`, but with an explicit `max_size` bound that sets the back-reference
    /// placeholder width (2 MiB -> 4 B, 1024 -> 2 B). Must match across producers for byte-identity.
    pub fn to_bytes_with_max_size(&self, max_size: usize) -> Result<Vec<u8>, DagrError> {
        let root = self.get_root().ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_max_size(max_size);
        let root_ref = root.store(&mut b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2);
        Ok(b.finalize())
    }

    pub fn from_bytes(data: &[u8]) -> Result<Self, DagrError> {
        if data.is_empty() { return Ok(Self::new()); }
        let (framing, rl) = dagr_runtime::read_leb(data, 0)?;
        if (framing & 1) != 0 || ((framing >> 1) & 1) != 0 { return Err(DagrError::InvalidData); }
        let root_at = rl + (framing >> 2) as usize;
        let arena = Self::new();
        let mut cache = std::collections::HashMap::new();
        let root = _restore_document(data, root_at, &arena, &mut cache)?;
        arena.set_root(Some(root));
        Ok(arena)
    }
}