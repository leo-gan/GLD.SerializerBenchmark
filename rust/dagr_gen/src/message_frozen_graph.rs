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

// ── MessageFrozenGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait MessageFrozenGraphGraph: MessageArena {
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
impl<T: MessageArena> MessageFrozenGraphGraph for T {}

// ── Message handle ────────────────────────────────────────────────────────
pub struct Message<'arena, G: MessageFrozenGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: MessageFrozenGraphGraph> Clone for Message<'arena, G> {
    fn clone(&self) -> Self { Message { index: self.index, graph: self.graph } }
}
impl<'arena, G: MessageFrozenGraphGraph> Copy for Message<'arena, G> {}

impl<'arena, G: MessageFrozenGraphGraph> Message<'arena, G> {
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

    fn _cycle_eq<B: MessageFrozenGraphGraph>(&self, other: &Message<'_, B>,
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

impl<'a, 'b, A: MessageFrozenGraphGraph, B: MessageFrozenGraphGraph> PartialEq<Message<'b, B>> for Message<'a, A> {
    fn eq(&self, other: &Message<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: MessageFrozenGraphGraph> Eq for Message<'arena, G> {}

impl<'arena, G: MessageFrozenGraphGraph> std::hash::Hash for Message<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: MessageFrozenGraphGraph> fmt::Display for Message<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── MessageFrozenGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct MessageFrozenGraphArena<const ID: u64> {
    arena_of_message: RefCell<Vec<MessageValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> MessageArena for MessageFrozenGraphArena<ID> {
    const MESSAGE_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_message(&self) -> &RefCell<Vec<MessageValues>> {
        &self.arena_of_message
    }
}

impl<const ID: u64> MessageFrozenGraphArena<ID> {
    pub fn new() -> Self {
        MessageFrozenGraphArena {
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

impl<const ID: u64> Default for MessageFrozenGraphArena<ID> {
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
impl<'arena, G: MessageFrozenGraphGraph> Message<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::MESSAGE_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_message().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _f_string_2_off = _pr.f_string_2.as_deref().map(|s| b.store_string(s));
        let _f_string_off = _pr.f_string.as_deref().map(|s| b.store_string(s));
        if let Some(off) = _f_string_2_off { b.store_forward_pointer(off); }
        if let Some(_v_f_int32_2) = self.f_int32_2() { b.store_i32(_v_f_int32_2); }
        if let Some(_v_f_bool_2) = self.f_bool_2() { b.store_bool(_v_f_bool_2); }
        if let Some(off) = _f_string_off { b.store_forward_pointer(off); }
        if let Some(_v_f_float64) = self.f_float64() { b.store_f64(_v_f_float64); }
        if let Some(_v_f_int64) = self.f_int64() { b.store_i64(_v_f_int64); }
        if let Some(_v_f_int32) = self.f_int32() { b.store_i32(_v_f_int32); }
        if let Some(_v_f_bool) = self.f_bool() { b.store_bool(_v_f_bool); }
        b.store_u8(u8::from(self.f_bool().is_some()) | (u8::from(self.f_int32().is_some()) << 1) | (u8::from(self.f_int64().is_some()) << 2) | (u8::from(self.f_float64().is_some()) << 3) | (u8::from(_pr.f_string.is_some()) << 4) | (u8::from(self.f_bool_2().is_some()) << 5) | (u8::from(self.f_int32_2().is_some()) << 6) | (u8::from(_pr.f_string_2.is_some()) << 7));
        let _offset = b.cursor();
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::MESSAGE_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_message().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _obs0 = 0u8;
        _obs0 |= u8::from(self.f_bool().is_some()) << 0;
        _obs0 |= u8::from(self.f_int32().is_some()) << 1;
        _obs0 |= u8::from(self.f_int64().is_some()) << 2;
        _obs0 |= u8::from(self.f_float64().is_some()) << 3;
        _obs0 |= u8::from(_pr.f_string.is_some()) << 4;
        _obs0 |= u8::from(self.f_bool_2().is_some()) << 5;
        _obs0 |= u8::from(self.f_int32_2().is_some()) << 6;
        _obs0 |= u8::from(_pr.f_string_2.is_some()) << 7;
        let mut _ebs0 = 0u8;
        if let Some(_v_f_int32) = self.f_int32() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_f_int32 as i64)) >= 4) << 0; }
        if let Some(_v_f_int64) = self.f_int64() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_f_int64 as i64)) >= 8) << 1; }
        if self.f_float64().is_some() { _ebs0 |= 1u8 << 2; }
        if let Some(_v_f_int32_2) = self.f_int32_2() { _ebs0 |= u8::from(crate::dagr_runtime::leb_length(crate::dagr_runtime::to_zigzag(_v_f_int32_2 as i64)) >= 4) << 3; }
        if let Some(_s_f_string_2) = _pr.f_string_2.as_deref() {
            let _bs_f_string_2 = _s_f_string_2.as_bytes();
            b.store_raw(_bs_f_string_2);
            b.store_leb(_bs_f_string_2.len() as u64);
        }
        if let Some(_v_f_int32_2) = self.f_int32_2() { if _ebs0 & 8 != 0 { b.store_i32(_v_f_int32_2); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_f_int32_2 as i64)); } }
        if let Some(_v_f_bool_2) = self.f_bool_2() { b.store_bool(_v_f_bool_2); }
        if let Some(_s_f_string) = _pr.f_string.as_deref() {
            let _bs_f_string = _s_f_string.as_bytes();
            b.store_raw(_bs_f_string);
            b.store_leb(_bs_f_string.len() as u64);
        }
        if let Some(_v_f_float64) = self.f_float64() { b.store_f64(_v_f_float64); }
        if let Some(_v_f_int64) = self.f_int64() { if _ebs0 & 2 != 0 { b.store_i64(_v_f_int64); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_f_int64 as i64)); } }
        if let Some(_v_f_int32) = self.f_int32() { if _ebs0 & 1 != 0 { b.store_i32(_v_f_int32); } else { b.store_leb(crate::dagr_runtime::to_zigzag(_v_f_int32 as i64)); } }
        if let Some(_v_f_bool) = self.f_bool() { b.store_bool(_v_f_bool); }
        b.store_u8(_ebs0);
        b.store_u8(_obs0);
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_message<'arena, G: MessageFrozenGraphGraph>(
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
    let _obs0 = *data.get(at + 0).ok_or(DagrError::InvalidData)?;
    let _blank = MessageValues { f_bool: None, f_int32: None, f_int64: None, f_float64: None, f_string: None, f_bool_2: None, f_int32_2: None, f_string_2: None };
    let _idx = {
        let mut _arr = arena.arena_of_message().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Message { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let mut _cur = at + 1;
    let _f_bool_val = if _obs0 & 1 != 0 {
        let _rv = crate::dagr_runtime::read_bool(data, _cur)?; _cur += 1; Some(_rv)
    } else { None };
    let _f_int32_val = if _obs0 & 2 != 0 {
        let _rv = crate::dagr_runtime::read_i32(data, _cur)? as i32; _cur += 4; Some(_rv)
    } else { None };
    let _f_int64_val = if _obs0 & 4 != 0 {
        let _rv = crate::dagr_runtime::read_i64(data, _cur)? as i64; _cur += 8; Some(_rv)
    } else { None };
    let _f_float64_val = if _obs0 & 8 != 0 {
        let _rv = crate::dagr_runtime::read_f64(data, _cur)? as f64; _cur += 8; Some(_rv)
    } else { None };
    let _f_string_val = if _obs0 & 16 != 0 {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _fwd_target = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        Some(crate::dagr_runtime::read_string(data, _fwd_target)?)
    } else { None };
    let _f_bool_2_val = if _obs0 & 32 != 0 {
        let _rv = crate::dagr_runtime::read_bool(data, _cur)?; _cur += 1; Some(_rv)
    } else { None };
    let _f_int32_2_val = if _obs0 & 64 != 0 {
        let _rv = crate::dagr_runtime::read_i32(data, _cur)? as i32; _cur += 4; Some(_rv)
    } else { None };
    let _f_string_2_val = if _obs0 & 128 != 0 {
        let (_fwd_raw, _fwd_bs) = crate::dagr_runtime::read_v62(data, _cur)?;
        let _fwd_target = _cur + _fwd_bs + _fwd_raw as usize;
        _cur += _fwd_bs;
        Some(crate::dagr_runtime::read_string(data, _fwd_target)?)
    } else { None };
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
impl<const ID: u64> MessageFrozenGraphArena<ID> {
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