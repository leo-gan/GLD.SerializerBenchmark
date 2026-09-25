#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

// ── MessageValues ──────────────────────────────────────────────────────────
pub struct MessageValues {
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
}

// ── MessageRegularGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait MessageRegularGraphGraph: MessageArena {
    fn new_message(&self, f_bool: Option<bool>, f_int32: Option<i32>, f_int64: Option<i64>, f_float64: Option<f64>, f_string: Option<&str>, f_bool_2: Option<bool>, f_int32_2: Option<i32>, f_string_2: Option<&str>) -> Message<'_, Self> where Self: Sized {
        let _values = MessageValues {
                f_bool: f_bool,
                f_int32: f_int32,
                f_int64: f_int64,
                f_float64: f_float64,
                f_string: f_string.map(str::to_owned),
                f_bool_2: f_bool_2,
                f_int32_2: f_int32_2,
                f_string_2: f_string_2.map(str::to_owned),
        };
        let index = {
            let mut _arena = self.arena_of_message().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Message { index: index, graph: self }
    }
    fn new_message_defaulted(&self) -> Message<'_, Self> where Self: Sized {
        self.new_message(None, None, None, None, None, None, None, None)
    }
}
impl<T: MessageArena> MessageRegularGraphGraph for T {}

// ── Message handle ────────────────────────────────────────────────────────
pub struct Message<'arena, G: MessageRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: MessageRegularGraphGraph> Clone for Message<'arena, G> {
    fn clone(&self) -> Self { Message { index: self.index, graph: self.graph } }
}
impl<'arena, G: MessageRegularGraphGraph> Copy for Message<'arena, G> {}

impl<'arena, G: MessageRegularGraphGraph> Message<'arena, G> {
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

    fn _cycle_eq<B: MessageRegularGraphGraph>(&self, other: &Message<'_, B>,
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

impl<'a, 'b, A: MessageRegularGraphGraph, B: MessageRegularGraphGraph> PartialEq<Message<'b, B>> for Message<'a, A> {
    fn eq(&self, other: &Message<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: MessageRegularGraphGraph> Eq for Message<'arena, G> {}

impl<'arena, G: MessageRegularGraphGraph> std::hash::Hash for Message<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: MessageRegularGraphGraph> fmt::Display for Message<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── MessageRegularGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct MessageRegularGraphArena<const ID: u64> {
    arena_of_message: RefCell<Vec<MessageValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> MessageArena for MessageRegularGraphArena<ID> {
    const MESSAGE_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_message(&self) -> &RefCell<Vec<MessageValues>> {
        &self.arena_of_message
    }
}

impl<const ID: u64> MessageRegularGraphArena<ID> {
    pub fn new() -> Self {
        MessageRegularGraphArena {
            arena_of_message: RefCell::new(Vec::new()),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Message<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_message().borrow();
            a.get(nr.index as usize)
                .map(|_| Message { index: nr.index, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Message<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index }));
    }
}

impl<const ID: u64> Default for MessageRegularGraphArena<ID> {
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

// ── Message serde ──────────────────────────────────────────────────────────
impl<'arena, G: MessageRegularGraphGraph> Message<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::MESSAGE_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_message().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _f_string_2_off = _pr.f_string_2.as_deref().map(|s| b.store_string(s));
        let _f_string_off = _pr.f_string.as_deref().map(|s| b.store_string(s));
        let _f_string_2_ptr = _f_string_2_off.map(|off| b.store_forward_pointer(off));
        let _f_int32_2_ptr = self.f_int32_2().map(|v| b.store_i32(v));
        let _f_bool_2_ptr = self.f_bool_2().map(|v| b.store_bool(v));
        let _f_string_ptr = _f_string_off.map(|off| b.store_forward_pointer(off));
        let _f_float64_ptr = self.f_float64().map(|v| b.store_f64(v));
        let _f_int64_ptr = self.f_int64().map(|v| b.store_i64(v));
        let _f_int32_ptr = self.f_int32().map(|v| b.store_i32(v));
        let _f_bool_ptr = self.f_bool().map(|v| b.store_bool(v));
        let _offset = b.store_vtable(&[_f_bool_ptr, _f_int32_ptr, _f_int64_ptr, _f_float64_ptr, _f_string_ptr, _f_bool_2_ptr, _f_int32_2_ptr, _f_string_2_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
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
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_message<'arena, G: MessageRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Message<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::MESSAGE_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_message().borrow();
        let _ = &a;
        return Ok(Message { index: idx, graph: arena });
    }
    let _blank = MessageValues { f_bool: None, f_int32: None, f_int64: None, f_float64: None, f_string: None, f_bool_2: None, f_int32_2: None, f_string_2: None };
    let _idx = {
        let mut _arr = arena.arena_of_message().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Message { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _f_bool_val = _slots.slot(0).map(|at| crate::dagr_runtime::read_bool(data, at).unwrap_or_default() as bool);
    let _f_int32_val = _slots.slot(1).map(|at| crate::dagr_runtime::read_i32(data, at).unwrap_or_default() as i32);
    let _f_int64_val = _slots.slot(2).map(|at| crate::dagr_runtime::read_i64(data, at).unwrap_or_default() as i64);
    let _f_float64_val = _slots.slot(3).map(|at| crate::dagr_runtime::read_f64(data, at).unwrap_or_default() as f64);
    let _f_string_val = _slots.slot(4).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _f_bool_2_val = _slots.slot(5).map(|at| crate::dagr_runtime::read_bool(data, at).unwrap_or_default() as bool);
    let _f_int32_2_val = _slots.slot(6).map(|at| crate::dagr_runtime::read_i32(data, at).unwrap_or_default() as i32);
    let _f_string_2_val = _slots.slot(7).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    _node.set_f_bool(_f_bool_val);
    _node.set_f_int32(_f_int32_val);
    _node.set_f_int64(_f_int64_val);
    _node.set_f_float64(_f_float64_val);
    _node.set_f_string(_f_string_val.as_deref());
    _node.set_f_bool_2(_f_bool_2_val);
    _node.set_f_int32_2(_f_int32_2_val);
    _node.set_f_string_2(_f_string_2_val.as_deref());
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> MessageRegularGraphArena<ID> {
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