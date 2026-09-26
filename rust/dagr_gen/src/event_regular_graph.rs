#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

// ── EventAttrValues ──────────────────────────────────────────────────────────
pub struct EventAttrValues {
    pub key: Option<String>,
    pub value: Option<String>,
}

// ── EventValues ──────────────────────────────────────────────────────────
pub struct EventValues {
    pub event_id: Option<String>,
    pub event_type: Option<String>,
    pub occurred_at: Option<i64>,
    pub producer: Option<String>,
    pub attrs: Vec<NodeRef>,
}

pub trait EventAttrArena {
    const EVENTATTR_TYPE_ID: u64;
    fn arena_of_event_attr(&self) -> &RefCell<Vec<EventAttrValues>>;
}

pub trait EventArena {
    const EVENT_TYPE_ID: u64;
    fn arena_of_event(&self) -> &RefCell<Vec<EventValues>>;
}

// ── EventRegularGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait EventRegularGraphGraph: EventAttrArena + EventArena {
    fn new_event_attr(&self, key: Option<&str>, value: Option<&str>) -> EventAttr<'_, Self> where Self: Sized {
        let _values = EventAttrValues {
                key: key.map(str::to_owned),
                value: value.map(str::to_owned),
        };
        let index = {
            let mut _arena = self.arena_of_event_attr().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        EventAttr { index: index, graph: self }
    }
    fn new_event_attr_defaulted(&self) -> EventAttr<'_, Self> where Self: Sized {
        self.new_event_attr(None, None)
    }
    fn new_event(&self, event_id: Option<&str>, event_type: Option<&str>, occurred_at: Option<i64>, producer: Option<&str>, attrs: &[EventAttr<'_, Self>]) -> Event<'_, Self> where Self: Sized {
        let _values = EventValues {
                event_id: event_id.map(str::to_owned),
                event_type: event_type.map(str::to_owned),
                occurred_at: occurred_at,
                producer: producer.map(str::to_owned),
                attrs: attrs.iter().filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }).collect(),
        };
        let index = {
            let mut _arena = self.arena_of_event().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Event { index: index, graph: self }
    }
    fn new_event_defaulted(&self) -> Event<'_, Self> where Self: Sized {
        self.new_event(None, None, None, None, &[])
    }
}
impl<T: EventAttrArena + EventArena> EventRegularGraphGraph for T {}

// ── EventAttr handle ────────────────────────────────────────────────────────
pub struct EventAttr<'arena, G: EventRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: EventRegularGraphGraph> Clone for EventAttr<'arena, G> {
    fn clone(&self) -> Self { EventAttr { index: self.index, graph: self.graph } }
}
impl<'arena, G: EventRegularGraphGraph> Copy for EventAttr<'arena, G> {}

impl<'arena, G: EventRegularGraphGraph> EventAttr<'arena, G> {
    pub fn key(&self) -> Option<String> {
        self.graph.arena_of_event_attr().borrow()[self.index as usize].key.clone()
    }
    pub fn set_key(&self, v: Option<&str>) {
        self.graph.arena_of_event_attr().borrow_mut()[self.index as usize].key = v.map(str::to_owned);
    }
    pub fn value(&self) -> Option<String> {
        self.graph.arena_of_event_attr().borrow()[self.index as usize].value.clone()
    }
    pub fn set_value(&self, v: Option<&str>) {
        self.graph.arena_of_event_attr().borrow_mut()[self.index as usize].value = v.map(str::to_owned);
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::EVENTATTR_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.key().hash(state);
        self.value().hash(state);
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "EventAttr@{}", self.index);
        }
        write!(f, "EventAttr@{} {{ ", self.index)?;
        write!(f, "key: {:?}, ", self.key())?;
        write!(f, "value: {:?}", self.value())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: EventRegularGraphGraph>(&self, other: &EventAttr<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.key() != other.key() { return false; }
        if self.value() != other.value() { return false; }
        true
    }
}

impl<'a, 'b, A: EventRegularGraphGraph, B: EventRegularGraphGraph> PartialEq<EventAttr<'b, B>> for EventAttr<'a, A> {
    fn eq(&self, other: &EventAttr<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: EventRegularGraphGraph> Eq for EventAttr<'arena, G> {}

impl<'arena, G: EventRegularGraphGraph> std::hash::Hash for EventAttr<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: EventRegularGraphGraph> fmt::Display for EventAttr<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── Event handle ────────────────────────────────────────────────────────
pub struct Event<'arena, G: EventRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: EventRegularGraphGraph> Clone for Event<'arena, G> {
    fn clone(&self) -> Self { Event { index: self.index, graph: self.graph } }
}
impl<'arena, G: EventRegularGraphGraph> Copy for Event<'arena, G> {}

impl<'arena, G: EventRegularGraphGraph> Event<'arena, G> {
    pub fn event_id(&self) -> Option<String> {
        self.graph.arena_of_event().borrow()[self.index as usize].event_id.clone()
    }
    pub fn set_event_id(&self, v: Option<&str>) {
        self.graph.arena_of_event().borrow_mut()[self.index as usize].event_id = v.map(str::to_owned);
    }
    pub fn event_type(&self) -> Option<String> {
        self.graph.arena_of_event().borrow()[self.index as usize].event_type.clone()
    }
    pub fn set_event_type(&self, v: Option<&str>) {
        self.graph.arena_of_event().borrow_mut()[self.index as usize].event_type = v.map(str::to_owned);
    }
    pub fn occurred_at(&self) -> Option<i64> {
        self.graph.arena_of_event().borrow()[self.index as usize].occurred_at
    }
    pub fn set_occurred_at(&self, v: Option<i64>) {
        self.graph.arena_of_event().borrow_mut()[self.index as usize].occurred_at = v;
    }
    pub fn producer(&self) -> Option<String> {
        self.graph.arena_of_event().borrow()[self.index as usize].producer.clone()
    }
    pub fn set_producer(&self, v: Option<&str>) {
        self.graph.arena_of_event().borrow_mut()[self.index as usize].producer = v.map(str::to_owned);
    }
    pub fn attrs(&self) -> Vec<EventAttr<'arena, G>> {
        let nrs: Vec<_> = {
            let arena = self.graph.arena_of_event().borrow();
            match arena.get(self.index as usize) {
                Some(v) => v.attrs.clone(),
                _ => return vec![],
            }
        };
        nrs.into_iter().map(|nr| EventAttr { index: nr.index, graph: self.graph }).collect()
    }
    pub fn set_attrs(&self, vs: &[EventAttr<'_, G>]) {
        let nrs = vs.iter()
            .filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
            .map(|h| NodeRef { index: h.index }).collect();
        self.graph.arena_of_event().borrow_mut()[self.index as usize].attrs = nrs;
    }
    pub fn push_attrs(&self, v: EventAttr<'_, G>) {
        if std::ptr::eq(v.graph as *const G, self.graph as *const G) {
            let nr = NodeRef { index: v.index };
            self.graph.arena_of_event().borrow_mut()[self.index as usize].attrs.push(nr);
        }
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::EVENT_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.event_id().hash(state);
        self.event_type().hash(state);
        self.occurred_at().hash(state);
        self.producer().hash(state);
        for v in &self.attrs() { v._hash_with(state, visited); }
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Event@{}", self.index);
        }
        write!(f, "Event@{} {{ ", self.index)?;
        write!(f, "event_id: {:?}, ", self.event_id())?;
        write!(f, "event_type: {:?}, ", self.event_type())?;
        write!(f, "occurred_at: {:?}, ", self.occurred_at())?;
        write!(f, "producer: {:?}, ", self.producer())?;
        write!(f, "attrs: [")?;
        { let _items = self.attrs(); for (_i, _v) in _items.iter().enumerate() {
            if _i > 0 { write!(f, ", ")?; } _v._fmt_with(f, visited)?;
        } }
        write!(f, "]")?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: EventRegularGraphGraph>(&self, other: &Event<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.event_id() != other.event_id() { return false; }
        if self.event_type() != other.event_type() { return false; }
        if self.occurred_at() != other.occurred_at() { return false; }
        if self.producer() != other.producer() { return false; }
        { let sa = self.attrs(); let sb = other.attrs();
          if sa.len() != sb.len() { return false; }
          if !sa.iter().zip(sb.iter()).all(|(a, b)| a._cycle_eq(b, visited)) { return false; } }
        true
    }
}

impl<'a, 'b, A: EventRegularGraphGraph, B: EventRegularGraphGraph> PartialEq<Event<'b, B>> for Event<'a, A> {
    fn eq(&self, other: &Event<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: EventRegularGraphGraph> Eq for Event<'arena, G> {}

impl<'arena, G: EventRegularGraphGraph> std::hash::Hash for Event<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: EventRegularGraphGraph> fmt::Display for Event<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── EventRegularGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct EventRegularGraphArena<const ID: u64> {
    arena_of_event_attr: RefCell<Vec<EventAttrValues>>,
    arena_of_event: RefCell<Vec<EventValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> EventAttrArena for EventRegularGraphArena<ID> {
    const EVENTATTR_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_event_attr(&self) -> &RefCell<Vec<EventAttrValues>> {
        &self.arena_of_event_attr
    }
}

impl<const ID: u64> EventArena for EventRegularGraphArena<ID> {
    const EVENT_TYPE_ID: u64 = ID * 100 + 1;
    fn arena_of_event(&self) -> &RefCell<Vec<EventValues>> {
        &self.arena_of_event
    }
}

impl<const ID: u64> EventRegularGraphArena<ID> {
    pub fn new() -> Self {
        EventRegularGraphArena {
            arena_of_event_attr: RefCell::new(Vec::new()),
            arena_of_event: RefCell::new(Vec::new()),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Event<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_event().borrow();
            a.get(nr.index as usize)
                .map(|_| Event { index: nr.index, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Event<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index }));
    }
}

impl<const ID: u64> Default for EventRegularGraphArena<ID> {
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

// ── EventAttr serde ──────────────────────────────────────────────────────────
impl<'arena, G: EventRegularGraphGraph> EventAttr<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::EVENTATTR_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_event_attr().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _value_off = _pr.value.as_deref().map(|s| b.store_string(s));
        let _key_off = _pr.key.as_deref().map(|s| b.store_string(s));
        let _value_ptr = _value_off.map(|off| b.store_forward_pointer(off));
        let _key_ptr = _key_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_key_ptr, _value_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::EVENTATTR_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_event_attr().borrow();
        let _pr = &_pr_row[self.index as usize];
        if let Some(_s) = _pr.value.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((1u64 << 1) | 1); }
        if let Some(_s) = _pr.key.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((0u64 << 1) | 1); }
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

// ── Event serde ──────────────────────────────────────────────────────────
impl<'arena, G: EventRegularGraphGraph> Event<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::EVENT_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_event().borrow();
        let _pr = &_pr_row[self.index as usize];
        let mut _attrs_items = b.take_ref_scratch();
        {
            let _row_attrs = self.graph.arena_of_event().borrow();
            let _refs_attrs = &_row_attrs[self.index as usize].attrs;
            let _cb_attrs = self.graph.arena_of_event_attr().borrow();
            for _nr in _refs_attrs.iter().rev() {
                if _cb_attrs.get(_nr.index as usize).is_some() {
                    _attrs_items.push(EventAttr { index: _nr.index, graph: self.graph }.store(b).unwrap_or(NodeStoreRef::Offset(0)));
                }
            }
        }
        let _attrs_off = Some(b.store_node_ref_array(&_attrs_items, b.cursor()));
        b.return_ref_scratch(_attrs_items);
        let _producer_off = _pr.producer.as_deref().map(|s| b.store_string(s));
        let _event_type_off = _pr.event_type.as_deref().map(|s| b.store_string(s));
        let _event_id_off = _pr.event_id.as_deref().map(|s| b.store_string(s));
        let _attrs_ptr = _attrs_off.map(|off| b.store_forward_pointer(off));
        let _producer_ptr = _producer_off.map(|off| b.store_forward_pointer(off));
        let _occurred_at_ptr = self.occurred_at().map(|v| b.store_i64(v));
        let _event_type_ptr = _event_type_off.map(|off| b.store_forward_pointer(off));
        let _event_id_ptr = _event_id_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_event_id_ptr, _event_type_ptr, _occurred_at_ptr, _producer_ptr, _attrs_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::EVENT_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_event().borrow();
        let _pr = &_pr_row[self.index as usize];
        {
            let _row_attrs = self.graph.arena_of_event().borrow();
            let _refs_attrs = &_row_attrs[self.index as usize].attrs;
            let _cb_attrs = self.graph.arena_of_event_attr().borrow();
            let _valid_attrs = _refs_attrs.iter().filter(|_nr| _cb_attrs.get(_nr.index as usize).is_some()).count();
            if _valid_attrs > 0 {
                let _bef = b.cursor();
                for _nr in _refs_attrs.iter().rev() {
                    if _cb_attrs.get(_nr.index as usize).is_some() {
                        EventAttr { index: _nr.index, graph: self.graph }.store_packed(b)?;
                    }
                }
                b.store_leb(_valid_attrs as u64);
                b.store_leb((b.cursor() - _bef) as u64);
                b.store_leb((4u64 << 1) | 1);
            }
        }
        if let Some(_s) = _pr.producer.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((3u64 << 1) | 1); }
        if let Some(_v) = self.occurred_at() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 8 {
                b.store_leb(_zz); b.store_leb((2u64 << 1) | 0);
            } else { b.store_i64(_v); b.store_leb((2u64 << 1) | 1); }
        }
        if let Some(_s) = _pr.event_type.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((1u64 << 1) | 1); }
        if let Some(_s) = _pr.event_id.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((0u64 << 1) | 1); }
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_event_attr<'arena, G: EventRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<EventAttr<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::EVENTATTR_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_event_attr().borrow();
        let _ = &a;
        return Ok(EventAttr { index: idx, graph: arena });
    }
    let _blank = EventAttrValues { key: None, value: None };
    let _idx = {
        let mut _arr = arena.arena_of_event_attr().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = EventAttr { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _key_val = _slots.slot(0).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _value_val = _slots.slot(1).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    _node.set_key(_key_val.as_deref());
    _node.set_value(_value_val.as_deref());
    Ok(_node)
}

fn _restore_event<'arena, G: EventRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Event<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::EVENT_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_event().borrow();
        let _ = &a;
        return Ok(Event { index: idx, graph: arena });
    }
    let _blank = EventValues { event_id: None, event_type: None, occurred_at: None, producer: None, attrs: vec![] };
    let _idx = {
        let mut _arr = arena.arena_of_event().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Event { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _event_id_val = _slots.slot(0).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _event_type_val = _slots.slot(1).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _occurred_at_val = _slots.slot(2).map(|at| crate::dagr_runtime::read_i64(data, at).unwrap_or_default() as i64);
    let _producer_val = _slots.slot(3).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _attrs_val = if let Some(fwd) = _slots.slot(4) {
        let at = crate::dagr_runtime::read_forward_pointer(data, fwd)?;
        let _items: Result<Vec<_>, DagrError> = crate::dagr_runtime::read_node_ref_array(data, at)?.into_iter()
            .filter_map(|p| p.map(|a| _restore_event_attr(data, a, arena, cache)))
            .collect();
        _items?
    } else { vec![] };
    _node.set_event_id(_event_id_val.as_deref());
    _node.set_event_type(_event_type_val.as_deref());
    _node.set_occurred_at(_occurred_at_val);
    _node.set_producer(_producer_val.as_deref());
    _node.set_attrs(&_attrs_val);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> EventRegularGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_event_attr().borrow().len() + self.arena_of_event().borrow().len());
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
        let root = _restore_event(data, root_at, &arena, &mut cache)?;
        arena.set_root(Some(root));
        Ok(arena)
    }
}