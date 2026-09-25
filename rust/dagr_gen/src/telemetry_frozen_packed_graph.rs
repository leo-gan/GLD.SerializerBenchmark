#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

pub use crate::telemetry_frozen_packed_graph_core::*;

// ── TelemetryValues ──────────────────────────────────────────────────────────
pub struct TelemetryValues {
    pub source: Option<String>,
    pub ts: Option<i64>,
    pub tags: Vec<String>,
    pub values: Vec<f64>,
}

pub trait TelemetryArena {
    const TELEMETRY_TYPE_ID: u64;
    fn arena_of_telemetry(&self) -> &RefCell<Vec<TelemetryValues>>;
}

// ── TelemetryFrozenPackedGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait TelemetryFrozenPackedGraphGraph: TelemetryArena {
    fn new_telemetry(&self, source: Option<&str>, ts: Option<i64>, tags: Vec<String>, values: Vec<f64>) -> Telemetry<'_, Self> where Self: Sized {
        let _values = TelemetryValues {
                source: source.map(str::to_owned),
                ts: ts,
                tags: tags,
                values: values,
        };
        let index = {
            let mut _arena = self.arena_of_telemetry().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Telemetry { index: index, graph: self }
    }
    fn new_telemetry_defaulted(&self) -> Telemetry<'_, Self> where Self: Sized {
        self.new_telemetry(None, None, Vec::new(), Vec::new())
    }
}
impl<T: TelemetryArena> TelemetryFrozenPackedGraphGraph for T {}

// ── Telemetry handle ────────────────────────────────────────────────────────
pub struct Telemetry<'arena, G: TelemetryFrozenPackedGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: TelemetryFrozenPackedGraphGraph> Clone for Telemetry<'arena, G> {
    fn clone(&self) -> Self { Telemetry { index: self.index, graph: self.graph } }
}
impl<'arena, G: TelemetryFrozenPackedGraphGraph> Copy for Telemetry<'arena, G> {}

impl<'arena, G: TelemetryFrozenPackedGraphGraph> Telemetry<'arena, G> {
    pub fn source(&self) -> Option<String> {
        self.graph.arena_of_telemetry().borrow()[self.index as usize].source.clone()
    }
    pub fn set_source(&self, v: Option<&str>) {
        self.graph.arena_of_telemetry().borrow_mut()[self.index as usize].source = v.map(str::to_owned);
    }
    pub fn ts(&self) -> Option<i64> {
        self.graph.arena_of_telemetry().borrow()[self.index as usize].ts
    }
    pub fn set_ts(&self, v: Option<i64>) {
        self.graph.arena_of_telemetry().borrow_mut()[self.index as usize].ts = v;
    }
    pub fn tags(&self) -> Vec<String> {
        self.graph.arena_of_telemetry().borrow()[self.index as usize].tags.clone()
    }
    pub fn set_tags(&self, vs: Vec<String>) {
        self.graph.arena_of_telemetry().borrow_mut()[self.index as usize].tags = vs;
    }
    pub fn push_tags(&self, v: String) {
        self.graph.arena_of_telemetry().borrow_mut()[self.index as usize].tags.push(v);
    }
    pub fn values(&self) -> Vec<f64> {
        self.graph.arena_of_telemetry().borrow()[self.index as usize].values.clone()
    }
    pub fn set_values(&self, vs: Vec<f64>) {
        self.graph.arena_of_telemetry().borrow_mut()[self.index as usize].values = vs;
    }
    pub fn push_values(&self, v: f64) {
        self.graph.arena_of_telemetry().borrow_mut()[self.index as usize].values.push(v);
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::TELEMETRY_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.source().hash(state);
        self.ts().hash(state);
        self.tags().hash(state);
        for v in &self.values() { v.to_bits().hash(state); }
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Telemetry@{}", self.index);
        }
        write!(f, "Telemetry@{} {{ ", self.index)?;
        write!(f, "source: {:?}, ", self.source())?;
        write!(f, "ts: {:?}, ", self.ts())?;
        write!(f, "tags: {:?}, ", self.tags())?;
        write!(f, "values: {:?}", self.values())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: TelemetryFrozenPackedGraphGraph>(&self, other: &Telemetry<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.source() != other.source() { return false; }
        if self.ts() != other.ts() { return false; }
        if self.tags() != other.tags() { return false; }
        if self.values() != other.values() { return false; }
        true
    }
}

impl<'a, 'b, A: TelemetryFrozenPackedGraphGraph, B: TelemetryFrozenPackedGraphGraph> PartialEq<Telemetry<'b, B>> for Telemetry<'a, A> {
    fn eq(&self, other: &Telemetry<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: TelemetryFrozenPackedGraphGraph> Eq for Telemetry<'arena, G> {}

impl<'arena, G: TelemetryFrozenPackedGraphGraph> std::hash::Hash for Telemetry<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: TelemetryFrozenPackedGraphGraph> fmt::Display for Telemetry<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── TelemetryFrozenPackedGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct TelemetryFrozenPackedGraphArena<const ID: u64> {
    arena_of_telemetry: RefCell<Vec<TelemetryValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> TelemetryArena for TelemetryFrozenPackedGraphArena<ID> {
    const TELEMETRY_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_telemetry(&self) -> &RefCell<Vec<TelemetryValues>> {
        &self.arena_of_telemetry
    }
}

impl<const ID: u64> TelemetryFrozenPackedGraphArena<ID> {
    pub fn new() -> Self {
        TelemetryFrozenPackedGraphArena {
            arena_of_telemetry: RefCell::new(Vec::new()),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Telemetry<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_telemetry().borrow();
            a.get(nr.index as usize)
                .map(|_| Telemetry { index: nr.index, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Telemetry<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index }));
    }
}

impl<const ID: u64> Default for TelemetryFrozenPackedGraphArena<ID> {
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

// ── Telemetry serde ──────────────────────────────────────────────────────────
impl<'arena, G: TelemetryFrozenPackedGraphGraph> Telemetry<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::TELEMETRY_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _ = self.store_packed(b)?;
        let _offset = b.cursor();
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::TELEMETRY_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_telemetry().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _obs0 = 0u8;
        _obs0 |= u8::from(_pr.source.is_some()) << 0;
        _obs0 |= u8::from(self.ts().is_some()) << 1;
        _obs0 |= u8::from(!_pr.tags.is_empty()) << 2;
        _obs0 |= u8::from(!_pr.values.is_empty()) << 3;
        let mut _ebs0 = 0u8;
        if let Some(_v_ts) = self.ts() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_ts as i64)) >= 8) << 0; }
        {
            let _values_arr = &_pr.values;
            if !_values_arr.is_empty() {
                let _cnt_values = _values_arr.len();
                let _bef_values = b.cursor();
                for &_e in _values_arr.iter().rev() { b.store_f64(_e); }
                b.store_leb(((_cnt_values as u64) << 2) | 1);
                b.store_leb((b.cursor() - _bef_values) as u64);
            }
        }
        {
            let _tags_arr = &_pr.tags;
            if !_tags_arr.is_empty() {
                let _cnt_tags = _tags_arr.len();
                let _bef_tags = b.cursor();
                for _e in _tags_arr.iter().rev() { b.store_blob(_e.as_bytes()); }
                b.store_leb(_cnt_tags as u64);
                b.store_leb((b.cursor() - _bef_tags) as u64);
            }
        }
        if let Some(_v_ts) = self.ts() { if _ebs0 & 1 != 0 { b.store_i64(_v_ts); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_ts as i64)); } }
        if let Some(_s_source) = _pr.source.as_deref() {
            let _bs_source = _s_source.as_bytes();
            b.store_raw(_bs_source);
            b.store_leb(_bs_source.len() as u64);
        }
        b.store_u8(_ebs0);
        b.store_u8(_obs0);
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_telemetry<'arena, G: TelemetryFrozenPackedGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Telemetry<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::TELEMETRY_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_telemetry().borrow();
        let _ = &a;
        return Ok(Telemetry { index: idx, graph: arena });
    }
    let (_, _fp_leb_sz) = crate::dagr_runtime::read_leb(data, at)?;
    let _obs0 = *data.get(at + _fp_leb_sz + 0).ok_or(DagrError::InvalidData)?;
    let _ebs0 = *data.get(at + _fp_leb_sz + 1).ok_or(DagrError::InvalidData)?;
    let _blank = TelemetryValues { source: None, ts: None, tags: vec![], values: vec![] };
    let _idx = {
        let mut _arr = arena.arena_of_telemetry().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Telemetry { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let mut _cur = at + _fp_leb_sz + 2;
    let _source_val = if _obs0 & 1 != 0 {
        let (_sv_source, _slb_source) = crate::dagr_runtime::read_leb(data, _cur)?;
        _cur += _slb_source;
        let _s_source = String::from_utf8_lossy(data.get(_cur.._cur + _sv_source as usize).ok_or(DagrError::InvalidData)?).into_owned();
        _cur += _sv_source as usize;
        Some(_s_source)
    } else { None };
    let _ts_val = if _obs0 & 2 != 0 {
        let _rv = if _ebs0 & 1 != 0 {
            let _v = crate::dagr_runtime::read_i64(data, _cur)? as i64; _cur += 8; _v
        } else {
            let (_lv, _lb) = crate::dagr_runtime::read_leb(data, _cur)?; _cur += _lb; crate::dagr_runtime::from_zigzag(_lv) as i64
        };
        Some(_rv)
    } else { None };
    let _tags_val = if _obs0 & 4 != 0 {
        let (_bsz_tags, _blb_tags) = crate::dagr_runtime::read_leb(data, _cur)?;
        _cur += _blb_tags;
        let _arr_end_tags = _cur + _bsz_tags as usize;
        let (_cnt_tags, _clb_tags) = crate::dagr_runtime::read_leb(data, _cur)?;
        _cur += _clb_tags;
        let mut _arr_tags = Vec::with_capacity(_cnt_tags as usize);
        _arr_tags = crate::dagr_runtime::PackedStrArray::new(data, _cur - _clb_tags)?.iter().map(|r| r.map(|s| s.to_string())).collect::<Result<Vec<_>, _>>()?;
        _cur = _arr_end_tags;
        _cur = _arr_end_tags;
        _arr_tags
    } else { vec![] };
    let _values_val = if _obs0 & 8 != 0 {
        let (_bsz_values, _blb_values) = crate::dagr_runtime::read_leb(data, _cur)?;
        _cur += _blb_values;
        let _arr_end_values = _cur + _bsz_values as usize;
        let (_cnt_values, _clb_values) = crate::dagr_runtime::read_leb(data, _cur)?;
        _cur += _clb_values;
        let mut _arr_values = Vec::with_capacity(_cnt_values as usize);
        _arr_values = crate::dagr_runtime::PackedF64Array::new(data, _cur - _clb_values)?.iter().collect::<Result<Vec<_>, _>>()?;
        _cur = _arr_end_values;
        _cur = _arr_end_values;
        _arr_values
    } else { vec![] };
    _node.set_source(_source_val.as_deref());
    _node.set_ts(_ts_val);
    _node.set_tags(_tags_val);
    _node.set_values(_values_val);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> TelemetryFrozenPackedGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_telemetry().borrow().len());
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
        let root = _restore_telemetry(data, root_at, &arena, &mut cache)?;
        arena.set_root(Some(root));
        Ok(arena)
    }
}