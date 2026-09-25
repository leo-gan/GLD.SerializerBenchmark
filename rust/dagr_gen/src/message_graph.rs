#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32, pub generation: u32 }

pub use crate::message_graph_core::*;

// ── MessageValues ──────────────────────────────────────────────────────────
pub struct MessageValues {
    pub(crate) _gen: u32,
    pub f_bool: Option<bool>,
    pub f_int32: Option<i32>,
    pub f_int64: Option<i64>,
    pub f_float64: Option<f64>,
    pub f_string: Option<String>,
    pub f_bool_2: Option<bool>,
    pub f_int32_2: Option<i32>,
    pub f_string_2: Option<String>,
}

pub trait MessageArena {
    const MESSAGE_TYPE_ID: u64;
    fn arena_of_message(&self) -> &RefCell<Vec<MessageValues>>;
    fn free_slots_of_message(&self) -> &RefCell<Vec<u32>>;
    fn _message_next_gen(&self) -> &Cell<u32>;
}

// ── MessageGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait MessageGraphGraph: MessageArena {
    fn new_message(&self, f_bool: Option<bool>, f_int32: Option<i32>, f_int64: Option<i64>, f_float64: Option<f64>, f_string: Option<&str>, f_bool_2: Option<bool>, f_int32_2: Option<i32>, f_string_2: Option<&str>) -> Message<'_, Self> where Self: Sized {
        let generation = self._message_next_gen().get();
        self._message_next_gen().set(generation.wrapping_add(1));
        let _values = MessageValues {
            _gen: generation,
                f_bool: f_bool,
                f_int32: f_int32,
                f_int64: f_int64,
                f_float64: f_float64,
                f_string: f_string.map(str::to_owned),
                f_bool_2: f_bool_2,
                f_int32_2: f_int32_2,
                f_string_2: f_string_2.map(str::to_owned),
        };
        let index = if let Some(idx) = self.free_slots_of_message().borrow_mut().pop() {
            self.arena_of_message().borrow_mut()[idx as usize] = _values;
            idx
        } else {
            let mut _arena = self.arena_of_message().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Message { index: index, generation: generation, graph: self }
    }
    fn new_message_defaulted(&self) -> Message<'_, Self> where Self: Sized {
        self.new_message(None, None, None, None, None, None, None, None)
    }
}
impl<T: MessageArena> MessageGraphGraph for T {}

// ── Message handle ────────────────────────────────────────────────────────
pub struct Message<'arena, G: MessageGraphGraph> {
    pub(crate) index: u32,
    pub(crate) generation: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: MessageGraphGraph> Clone for Message<'arena, G> {
    fn clone(&self) -> Self { Message { index: self.index, generation: self.generation, graph: self.graph } }
}
impl<'arena, G: MessageGraphGraph> Copy for Message<'arena, G> {}

impl<'arena, G: MessageGraphGraph> Message<'arena, G> {
    pub fn f_bool(&self) -> Option<bool> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_bool
    }
    pub fn set_f_bool(&self, v: Option<bool>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_bool = v;
    }
    pub fn f_int32(&self) -> Option<i32> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_int32
    }
    pub fn set_f_int32(&self, v: Option<i32>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_int32 = v;
    }
    pub fn f_int64(&self) -> Option<i64> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_int64
    }
    pub fn set_f_int64(&self, v: Option<i64>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_int64 = v;
    }
    pub fn f_float64(&self) -> Option<f64> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_float64
    }
    pub fn set_f_float64(&self, v: Option<f64>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_float64 = v;
    }
    pub fn f_string(&self) -> Option<String> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_string.clone()
    }
    pub fn set_f_string(&self, v: Option<&str>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_string = v.map(str::to_owned);
    }
    pub fn f_bool_2(&self) -> Option<bool> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_bool_2
    }
    pub fn set_f_bool_2(&self, v: Option<bool>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_bool_2 = v;
    }
    pub fn f_int32_2(&self) -> Option<i32> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_int32_2
    }
    pub fn set_f_int32_2(&self, v: Option<i32>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_int32_2 = v;
    }
    pub fn f_string_2(&self) -> Option<String> {
        self.graph.arena_of_message().borrow()[self.index as usize].f_string_2.clone()
    }
    pub fn set_f_string_2(&self, v: Option<&str>) {
        self.graph.arena_of_message().borrow_mut()[self.index as usize].f_string_2 = v.map(str::to_owned);
    }

    pub fn is_valid(&self) -> bool {
        self.graph.arena_of_message().borrow()
            .get(self.index as usize)
            .map_or(false, |v| v._gen == self.generation)
    }

    pub fn delete(&self) {
        let freed = {
            let mut a = self.graph.arena_of_message().borrow_mut();
            if let Some(v) = a.get_mut(self.index as usize) {
                if v._gen == self.generation { v._gen = u32::MAX; true } else { false }
            } else { false }
        };
        if freed {
            self.graph.free_slots_of_message().borrow_mut().push(self.index);
        }
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::MESSAGE_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.f_bool().hash(state);
        self.f_int32().hash(state);
        self.f_int64().hash(state);
        if let Some(_fv) = self.f_float64() { _fv.to_bits().hash(state); }
        self.f_string().hash(state);
        self.f_bool_2().hash(state);
        self.f_int32_2().hash(state);
        self.f_string_2().hash(state);
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Message@{}", self.index);
        }
        write!(f, "Message@{} {{ ", self.index)?;
        write!(f, "f_bool: {:?}, ", self.f_bool())?;
        write!(f, "f_int32: {:?}, ", self.f_int32())?;
        write!(f, "f_int64: {:?}, ", self.f_int64())?;
        write!(f, "f_float64: {:?}, ", self.f_float64())?;
        write!(f, "f_string: {:?}, ", self.f_string())?;
        write!(f, "f_bool_2: {:?}, ", self.f_bool_2())?;
        write!(f, "f_int32_2: {:?}, ", self.f_int32_2())?;
        write!(f, "f_string_2: {:?}", self.f_string_2())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: MessageGraphGraph>(&self, other: &Message<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.f_bool() != other.f_bool() { return false; }
        if self.f_int32() != other.f_int32() { return false; }
        if self.f_int64() != other.f_int64() { return false; }
        if self.f_float64() != other.f_float64() { return false; }
        if self.f_string() != other.f_string() { return false; }
        if self.f_bool_2() != other.f_bool_2() { return false; }
        if self.f_int32_2() != other.f_int32_2() { return false; }
        if self.f_string_2() != other.f_string_2() { return false; }
        true
    }
}

impl<'a, 'b, A: MessageGraphGraph, B: MessageGraphGraph> PartialEq<Message<'b, B>> for Message<'a, A> {
    fn eq(&self, other: &Message<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: MessageGraphGraph> Eq for Message<'arena, G> {}

impl<'arena, G: MessageGraphGraph> std::hash::Hash for Message<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: MessageGraphGraph> fmt::Display for Message<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── MessageGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct MessageGraphArena<const ID: u64> {
    arena_of_message: RefCell<Vec<MessageValues>>,
    free_slots_of_message: RefCell<Vec<u32>>,
    _message_next_gen: Cell<u32>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> MessageArena for MessageGraphArena<ID> {
    const MESSAGE_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_message(&self) -> &RefCell<Vec<MessageValues>> {
        &self.arena_of_message
    }
    fn free_slots_of_message(&self) -> &RefCell<Vec<u32>> {
        &self.free_slots_of_message
    }
    fn _message_next_gen(&self) -> &Cell<u32> {
        &self._message_next_gen
    }
}

impl<const ID: u64> MessageGraphArena<ID> {
    pub fn new() -> Self {
        MessageGraphArena {
            arena_of_message: RefCell::new(Vec::new()),
            free_slots_of_message: RefCell::new(Vec::new()),
            _message_next_gen: Cell::new(0),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Message<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_message().borrow();
            a.get(nr.index as usize)
                .filter(|v| v._gen == nr.generation)
                .map(|_| Message { index: nr.index, generation: nr.generation, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Message<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index, generation: h.generation }));
    }
}

impl<const ID: u64> Default for MessageGraphArena<ID> {
    fn default() -> Self { Self::new() }
}


// ── Serde: use dagr_runtime ─────────────────────────────────────────────────
use crate::dagr_runtime::{DagrBuilder, NodeStoreRef, UnionApplied, CycleId, DagrError};
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

// ── Message serde ──────────────────────────────────────────────────────────
impl<'arena, G: MessageGraphGraph> Message<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        if !self.is_valid() { return Err(DagrError::StaleReference); }
        let _id = CycleId { type_id: G::MESSAGE_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _ = self.store_packed(b)?;
        Ok(NodeStoreRef::Offset(b.cursor()))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        if !self.is_valid() { return Err(DagrError::StaleReference); }
        let _id = CycleId { type_id: G::MESSAGE_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_message().borrow();
        let _pr = &_pr_row[self.index as usize];
        if let Some(_s) = _pr.f_string_2.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((7u64 << 1) | 1); }
        if let Some(_v) = self.f_int32_2() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 4 {
                b.store_leb(_zz); b.store_leb((6u64 << 1) | 0);
            } else { b.store_i32(_v); b.store_leb((6u64 << 1) | 1); }
        }
        if let Some(_v) = self.f_bool_2() {
            b.store_bool(_v); b.store_leb((5u64 << 1) | 1);
        }
        if let Some(_s) = _pr.f_string.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((4u64 << 1) | 1); }
        if let Some(_v) = self.f_float64() { b.store_f64(_v); b.store_leb((3u64 << 1) | 1); }
        if let Some(_v) = self.f_int64() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 8 {
                b.store_leb(_zz); b.store_leb((2u64 << 1) | 0);
            } else { b.store_i64(_v); b.store_leb((2u64 << 1) | 1); }
        }
        if let Some(_v) = self.f_int32() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 4 {
                b.store_leb(_zz); b.store_leb((1u64 << 1) | 0);
            } else { b.store_i32(_v); b.store_leb((1u64 << 1) | 1); }
        }
        if let Some(_v) = self.f_bool() {
            b.store_bool(_v); b.store_leb((0u64 << 1) | 1);
        }
        b.store_leb((b.cursor() - _before) as u64);
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_message<'arena, G: MessageGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Message<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::MESSAGE_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_message().borrow();
        let _node_gen = a[idx as usize]._gen;
        return Ok(Message { index: idx, generation: _node_gen, graph: arena });
    }
    let (_total_size, _ts_len) = crate::dagr_runtime::read_leb(data, at)?;
    let _payload_end = at + _ts_len + _total_size as usize;
    let mut _f_bool_val = None;
    let mut _f_int32_val = None;
    let mut _f_int64_val = None;
    let mut _f_float64_val = None;
    let mut _f_string_val = None;
    let mut _f_bool_2_val = None;
    let mut _f_int32_2_val = None;
    let mut _f_string_2_val = None;
    let mut _pos = at + _ts_len;
    while _pos < _payload_end {
        let (_tag, _tl) = crate::dagr_runtime::read_leb(data, _pos)?;
        _pos += _tl;
        let _field_idx = (_tag >> 1) as usize;
        let _is_raw = _tag & 1 != 0;
        match _field_idx {
            0 => { _f_bool_val = Some(crate::dagr_runtime::read_bool(data, _pos)? as bool); _pos += 1; }
            1 => { if _is_raw { _f_int32_val = Some(crate::dagr_runtime::read_i32(data, _pos)? as i32); _pos += 4; } else { let (_v, _vl) = crate::dagr_runtime::read_leb(data, _pos)?; _f_int32_val = Some(crate::dagr_runtime::from_zigzag(_v) as i32); _pos += _vl; } }
            2 => { if _is_raw { _f_int64_val = Some(crate::dagr_runtime::read_i64(data, _pos)? as i64); _pos += 8; } else { let (_v, _vl) = crate::dagr_runtime::read_leb(data, _pos)?; _f_int64_val = Some(crate::dagr_runtime::from_zigzag(_v) as i64); _pos += _vl; } }
            3 => { if _is_raw { _f_float64_val = Some(crate::dagr_runtime::read_f64(data, _pos)? as f64); _pos += 8; } else { let (_pv, _pl) = crate::dagr_runtime::read_packed_f64(data, _pos)?; _f_float64_val = Some(_pv as f64); _pos += _pl; } }
            4 => { _f_string_val = Some(crate::dagr_runtime::read_string(data, _pos)?); let (_lv, _ll) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _lv as usize + _ll; }
            5 => { _f_bool_2_val = Some(crate::dagr_runtime::read_bool(data, _pos)? as bool); _pos += 1; }
            6 => { if _is_raw { _f_int32_2_val = Some(crate::dagr_runtime::read_i32(data, _pos)? as i32); _pos += 4; } else { let (_v, _vl) = crate::dagr_runtime::read_leb(data, _pos)?; _f_int32_2_val = Some(crate::dagr_runtime::from_zigzag(_v) as i32); _pos += _vl; } }
            7 => { _f_string_2_val = Some(crate::dagr_runtime::read_string(data, _pos)?); let (_lv, _ll) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _lv as usize + _ll; }
            _ => { if _is_raw { let (_sz, _sl) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _sl + _sz as usize; } else { let (_, _vl) = crate::dagr_runtime::read_leb(data, _pos)?; _pos += _vl; } }
        }
    }
    let _node = arena.new_message(_f_bool_val, _f_int32_val, _f_int64_val, _f_float64_val, _f_string_val.as_deref(), _f_bool_2_val, _f_int32_2_val, _f_string_2_val.as_deref());
    cache.insert(_cache_key, _node.index);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> MessageGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_message().borrow().len());
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
        let root = _restore_message(data, root_at, &arena, &mut cache)?;
        arena.set_root(Some(root));
        Ok(arena)
    }
}