#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

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

// ── TelemetryRegularGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait TelemetryRegularGraphGraph: TelemetryArena {
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
impl<T: TelemetryArena> TelemetryRegularGraphGraph for T {}

// ── Telemetry handle ────────────────────────────────────────────────────────
pub struct Telemetry<'arena, G: TelemetryRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: TelemetryRegularGraphGraph> Clone for Telemetry<'arena, G> {
    fn clone(&self) -> Self { Telemetry { index: self.index, graph: self.graph } }
}
impl<'arena, G: TelemetryRegularGraphGraph> Copy for Telemetry<'arena, G> {}

impl<'arena, G: TelemetryRegularGraphGraph> Telemetry<'arena, G> {
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

    fn _cycle_eq<B: TelemetryRegularGraphGraph>(&self, other: &Telemetry<'_, B>,
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

impl<'a, 'b, A: TelemetryRegularGraphGraph, B: TelemetryRegularGraphGraph> PartialEq<Telemetry<'b, B>> for Telemetry<'a, A> {
    fn eq(&self, other: &Telemetry<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: TelemetryRegularGraphGraph> Eq for Telemetry<'arena, G> {}

impl<'arena, G: TelemetryRegularGraphGraph> std::hash::Hash for Telemetry<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: TelemetryRegularGraphGraph> fmt::Display for Telemetry<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── TelemetryRegularGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct TelemetryRegularGraphArena<const ID: u64> {
    arena_of_telemetry: RefCell<Vec<TelemetryValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> TelemetryArena for TelemetryRegularGraphArena<ID> {
    const TELEMETRY_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_telemetry(&self) -> &RefCell<Vec<TelemetryValues>> {
        &self.arena_of_telemetry
    }
}

impl<const ID: u64> TelemetryRegularGraphArena<ID> {
    pub fn new() -> Self {
        TelemetryRegularGraphArena {
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

impl<const ID: u64> Default for TelemetryRegularGraphArena<ID> {
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
impl<'arena, G: TelemetryRegularGraphGraph> Telemetry<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::TELEMETRY_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_telemetry().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _values_off = {
            let _brw_values = self.graph.arena_of_telemetry().borrow();
            let _values_arr = &_brw_values[self.index as usize].values;
            #[cfg(target_endian = "little")]
            b.store_raw(unsafe { core::slice::from_raw_parts(_values_arr.as_ptr() as *const u8, _values_arr.len() * 8) });
            #[cfg(not(target_endian = "little"))]
            for _x in _values_arr.iter().rev() { b.store_f64(*_x); }
            Some(b.store_leb(_values_arr.len() as u64))
        };
        let _tags_offsets: Vec<Option<usize>> = (&_pr.tags).iter().rev()
            .map(|s| Some(b.store_string(s))).collect();
        let _tags_off = Some(_store_prim_array(&_tags_offsets, b.cursor(), b));
        let _source_off = _pr.source.as_deref().map(|s| b.store_string(s));
        let _values_ptr = _values_off.map(|off| b.store_forward_pointer(off));
        let _tags_ptr = _tags_off.map(|off| b.store_forward_pointer(off));
        let _ts_ptr = self.ts().map(|v| b.store_i64(v));
        let _source_ptr = _source_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_source_ptr, _ts_ptr, _tags_ptr, _values_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
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
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_telemetry<'arena, G: TelemetryRegularGraphGraph>(
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
    let _blank = TelemetryValues { source: None, ts: None, tags: vec![], values: vec![] };
    let _idx = {
        let mut _arr = arena.arena_of_telemetry().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Telemetry { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _source_val = _slots.slot(0).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _ts_val = _slots.slot(1).map(|at| crate::dagr_runtime::read_i64(data, at).unwrap_or_default() as i64);
    let _tags_val = if let Some(fwd) = _slots.slot(2) {
        let at = crate::dagr_runtime::read_forward_pointer(data, fwd)?;
        crate::dagr_runtime::read_value_ref_array(data, at)?.into_iter()
            .filter_map(|p| p.map(|a| crate::dagr_runtime::read_string(data, a).unwrap_or_default()))
            .collect()
    } else { vec![] };
    let _values_val = if let Some(fwd) = _slots.slot(3) {
        let at = crate::dagr_runtime::read_forward_pointer(data, fwd)?;
        crate::dagr_runtime::read_inline_prim_array_native::<f64>(data, at)?
    } else { vec![] };
    _node.set_source(_source_val.as_deref());
    _node.set_ts(_ts_val);
    _node.set_tags(_tags_val);
    _node.set_values(_values_val);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> TelemetryRegularGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_telemetry().borrow().len());
        let root_ref = root.store(&mut b)?;
        let root_off = root_ref.to_offset().unwrap_or(0);
        b.store_leb(((b.cursor() - root_off) as u64) << 2);
        Ok(b.finalize())
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