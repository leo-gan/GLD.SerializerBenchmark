#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

pub use crate::telemetry_graph_core::*;

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

// ── TelemetryGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait TelemetryGraphGraph: TelemetryArena {
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
impl<T: TelemetryArena> TelemetryGraphGraph for T {}

// ── Telemetry handle ────────────────────────────────────────────────────────
pub struct Telemetry<'arena, G: TelemetryGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: TelemetryGraphGraph> Clone for Telemetry<'arena, G> {
    fn clone(&self) -> Self { Telemetry { index: self.index, graph: self.graph } }
}
impl<'arena, G: TelemetryGraphGraph> Copy for Telemetry<'arena, G> {}

impl<'arena, G: TelemetryGraphGraph> Telemetry<'arena, G> {
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

    fn _cycle_eq<B: TelemetryGraphGraph>(&self, other: &Telemetry<'_, B>,
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

impl<'a, 'b, A: TelemetryGraphGraph, B: TelemetryGraphGraph> PartialEq<Telemetry<'b, B>> for Telemetry<'a, A> {
    fn eq(&self, other: &Telemetry<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: TelemetryGraphGraph> Eq for Telemetry<'arena, G> {}

impl<'arena, G: TelemetryGraphGraph> std::hash::Hash for Telemetry<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: TelemetryGraphGraph> fmt::Display for Telemetry<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── TelemetryGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct TelemetryGraphArena<const ID: u64> {
    arena_of_telemetry: RefCell<Vec<TelemetryValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> TelemetryArena for TelemetryGraphArena<ID> {
    const TELEMETRY_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_telemetry(&self) -> &RefCell<Vec<TelemetryValues>> {
        &self.arena_of_telemetry
    }
}

impl<const ID: u64> TelemetryGraphArena<ID> {
    pub fn new() -> Self {
        TelemetryGraphArena {
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

impl<const ID: u64> Default for TelemetryGraphArena<ID> {
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
impl<'arena, G: TelemetryGraphGraph> Telemetry<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::TELEMETRY_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _ = self.store_packed(b)?;
        Ok(NodeStoreRef::Offset(b.cursor()))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::TELEMETRY_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_telemetry().borrow();
        let _pr = &_pr_row[self.index as usize];
        {
            let _brw_values = self.graph.arena_of_telemetry().borrow();
            let _arr_values = &_brw_values[self.index as usize].values;
            if !_arr_values.is_empty() {
                let _bef = b.cursor();
                #[cfg(target_endian = "little")]
                b.store_raw(unsafe { core::slice::from_raw_parts(_arr_values.as_ptr() as *const u8, _arr_values.len() * 8) });
                #[cfg(not(target_endian = "little"))]
                for &_v in _arr_values.iter().rev() { b.store_f64(_v); }
                b.store_leb(((_arr_values.len() as u64) << 2) | 1);
                b.store_leb((b.cursor() - _bef) as u64);
                b.store_leb((3u64 << 1) | 1);
            }
        }
        { let _arr_tags = &_pr.tags;
        if !_arr_tags.is_empty() {
            let _bef = b.cursor();
            for _el in _arr_tags.iter().rev() {
                { let _bs = _el.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); }
            }
            b.store_leb(_arr_tags.len() as u64);
            b.store_leb((b.cursor() - _bef) as u64);
            b.store_leb((2u64 << 1) | 1);
        } }
        if let Some(_v) = self.ts() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 8 {
                b.store_leb(_zz); b.store_leb((1u64 << 1) | 0);
            } else { b.store_i64(_v); b.store_leb((1u64 << 1) | 1); }
        }
        if let Some(_s) = _pr.source.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((0u64 << 1) | 1); }
        b.store_leb((b.cursor() - _before) as u64);
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_telemetry<'arena, G: TelemetryGraphGraph>(
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
    let (_total_size, _ts_len) = crate::dagr_runtime::read_leb(data, at)?;
    let _payload_end = at + _ts_len + _total_size as usize;
    let mut _source_val = None;
    let mut _ts_val = None;
    let mut _tags_val = Vec::new();
    let mut _values_val = Vec::new();
    let mut _pos = at + _ts_len;
    while _pos < _payload_end {
        let (_tag, _tl) = crate::dagr_runtime::read_leb(data, _pos)?;
        _pos += _tl;
        let _field_idx = (_tag >> 1) as usize;
        let _is_raw = _tag & 1 != 0;
        match _field_idx {
            0 => { _source_val = Some(crate::dagr_runtime::read_string(data, _pos)?); let (_lv, _ll) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _lv as usize + _ll; }
            1 => { if _is_raw { _ts_val = Some(crate::dagr_runtime::read_i64(data, _pos)? as i64); _pos += 8; } else { let (_v, _vl) = crate::dagr_runtime::read_leb(data, _pos)?; _ts_val = Some(crate::dagr_runtime::from_zigzag(_v) as i64); _pos += _vl; } }
            2 => {
                let (_sz, _sl) = crate::dagr_runtime::read_leb(data, _pos)?;
                let _arr_end = _pos + _sl + _sz as usize;
                let _dp = _pos + _sl;
                let (_count, _cl) = crate::dagr_runtime::read_leb(data, _dp)?;
                let mut _ap = _dp + _cl;
                for _ in 0.._count {
                    let (_el_sz, _el_sl) = crate::dagr_runtime::read_leb(data, _ap)?;
                    _tags_val.push(crate::dagr_runtime::read_string(data, _ap)?);
                    _ap += _el_sl + _el_sz as usize;
                }
                _pos = _arr_end;
            }
            3 => {
                let (_sz, _sl) = crate::dagr_runtime::read_leb(data, _pos)?;
                let _arr_end = _pos + _sl + _sz as usize;
                let _dp = _pos + _sl;
                let (_count, _cl) = crate::dagr_runtime::read_leb(data, _dp)?;
                let _fmode = (_count & 3) as u8;
                let _count = _count >> 2;
                let mut _ap = _dp + _cl;
                if _fmode == 1 {
                    #[cfg(target_endian = "little")]
                    {
                        let _nb = (_count as usize).checked_mul(8).ok_or(DagrError::InvalidData)?;
                        if _ap.checked_add(_nb).map_or(true, |_e| _e > data.len()) { return Err(DagrError::InvalidData); }
                        <Vec<f64>>::reserve(&mut _values_val, _count as usize);
                        unsafe {
                            std::ptr::copy_nonoverlapping(data.as_ptr().add(_ap), _values_val.as_mut_ptr().add(_values_val.len()) as *mut u8, _nb);
                            _values_val.set_len(_values_val.len() + _count as usize);
                        }
                        _ap += _nb;
                    }
                    #[cfg(not(target_endian = "little"))]
                    for _ in 0.._count { _values_val.push(crate::dagr_runtime::read_f64(data, _ap)? as f64); _ap += 8; }
                } else {
                    for _ in 0.._count { let (_pv, _pl) = crate::dagr_runtime::read_packed_f64(data, _ap)?; _values_val.push(_pv as f64); _ap += _pl; }
                }
                _pos = _arr_end;
            }
            _ => { if _is_raw { let (_sz, _sl) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _sl + _sz as usize; } else { let (_, _vl) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _vl; } }
        }
    }
    let _node = arena.new_telemetry(_source_val.as_deref(), _ts_val, _tags_val, _values_val);
    cache.insert(_cache_key, _node.index);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> TelemetryGraphArena<ID> {
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