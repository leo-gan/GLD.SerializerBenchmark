#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

// ── StringsValues ──────────────────────────────────────────────────────────
pub struct StringsValues {
    pub items: Vec<String>,
}

pub trait StringsArena {
    const STRINGS_TYPE_ID: u64;
    fn arena_of_strings(&self) -> &RefCell<Vec<StringsValues>>;
}

// ── StringsFrozenGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait StringsFrozenGraphGraph: StringsArena {
    fn new_strings(&self, items: Vec<String>) -> Strings<'_, Self> where Self: Sized {
        let _values = StringsValues {
                items: items,
        };
        let index = {
            let mut _arena = self.arena_of_strings().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Strings { index: index, graph: self }
    }
    fn new_strings_defaulted(&self) -> Strings<'_, Self> where Self: Sized {
        self.new_strings(Vec::new())
    }
}
impl<T: StringsArena> StringsFrozenGraphGraph for T {}

// ── Strings handle ────────────────────────────────────────────────────────
pub struct Strings<'arena, G: StringsFrozenGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: StringsFrozenGraphGraph> Clone for Strings<'arena, G> {
    fn clone(&self) -> Self { Strings { index: self.index, graph: self.graph } }
}
impl<'arena, G: StringsFrozenGraphGraph> Copy for Strings<'arena, G> {}

impl<'arena, G: StringsFrozenGraphGraph> Strings<'arena, G> {
    pub fn items(&self) -> Vec<String> {
        self.graph.arena_of_strings().borrow()[self.index as usize].items.clone()
    }
    pub fn set_items(&self, vs: Vec<String>) {
        self.graph.arena_of_strings().borrow_mut()[self.index as usize].items = vs;
    }
    pub fn push_items(&self, v: String) {
        self.graph.arena_of_strings().borrow_mut()[self.index as usize].items.push(v);
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::STRINGS_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.items().hash(state);
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Strings@{}", self.index);
        }
        write!(f, "Strings@{} {{ ", self.index)?;
        write!(f, "items: {:?}", self.items())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: StringsFrozenGraphGraph>(&self, other: &Strings<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.items() != other.items() { return false; }
        true
    }
}

impl<'a, 'b, A: StringsFrozenGraphGraph, B: StringsFrozenGraphGraph> PartialEq<Strings<'b, B>> for Strings<'a, A> {
    fn eq(&self, other: &Strings<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: StringsFrozenGraphGraph> Eq for Strings<'arena, G> {}

impl<'arena, G: StringsFrozenGraphGraph> std::hash::Hash for Strings<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: StringsFrozenGraphGraph> fmt::Display for Strings<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── StringsFrozenGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct StringsFrozenGraphArena<const ID: u64> {
    arena_of_strings: RefCell<Vec<StringsValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> StringsArena for StringsFrozenGraphArena<ID> {
    const STRINGS_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_strings(&self) -> &RefCell<Vec<StringsValues>> {
        &self.arena_of_strings
    }
}

impl<const ID: u64> StringsFrozenGraphArena<ID> {
    pub fn new() -> Self {
        StringsFrozenGraphArena {
            arena_of_strings: RefCell::new(Vec::new()),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Strings<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_strings().borrow();
            a.get(nr.index as usize)
                .map(|_| Strings { index: nr.index, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Strings<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index }));
    }
}

impl<const ID: u64> Default for StringsFrozenGraphArena<ID> {
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

// ── Strings serde ──────────────────────────────────────────────────────────
impl<'arena, G: StringsFrozenGraphGraph> Strings<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::STRINGS_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_strings().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _items_offsets: Vec<Option<usize>> = (&_pr.items).iter().rev()
            .map(|s| Some(b.store_string(s))).collect();
        let _items_off = Some(_store_prim_array(&_items_offsets, b.cursor(), b));
        if let Some(off) = _items_off { b.store_forward_pointer(off); }
        b.store_u8(u8::from(!_pr.items.is_empty()));
        let _offset = b.cursor();
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::STRINGS_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_strings().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _obs0 = 0u8;
        _obs0 |= u8::from(!_pr.items.is_empty()) << 0;
        {
            let _items_arr = &_pr.items;
            if !_items_arr.is_empty() {
                let _cnt_items = _items_arr.len();
                let _bef_items = b.cursor();
                for _e in _items_arr.iter().rev() { b.store_blob(_e.as_bytes()); }
                b.store_leb(_cnt_items as u64);
                b.store_leb((b.cursor() - _bef_items) as u64);
            }
        }
        b.store_u8(_obs0);
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_strings<'arena, G: StringsFrozenGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Strings<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::STRINGS_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_strings().borrow();
        let _ = &a;
        return Ok(Strings { index: idx, graph: arena });
    }
    let _obs0 = *data.get(at + 0).ok_or(DagrError::InvalidData)?;
    let _blank = StringsValues { items: vec![] };
    let _idx = {
        let mut _arr = arena.arena_of_strings().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Strings { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let mut _cur = at + 1;
    let _items_val = if _cur < data.len() {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _at_items = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        crate::dagr_runtime::read_value_ref_array(data, _at_items)?.into_iter()
            .filter_map(|p| p.map(|a| crate::dagr_runtime::read_string(data, a).unwrap_or_default()))
            .collect()
    } else { vec![] };
    _node.set_items(_items_val);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> StringsFrozenGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_strings().borrow().len());
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
        let root = _restore_strings(data, root_at, &arena, &mut cache)?;
        arena.set_root(Some(root));
        Ok(arena)
    }
}