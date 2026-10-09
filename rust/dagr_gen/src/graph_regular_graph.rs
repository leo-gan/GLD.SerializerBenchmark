#![allow(unsafe_code, dead_code, non_snake_case)]
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef { pub index: u32 }

// ── RegionValues ──────────────────────────────────────────────────────────
pub struct RegionValues {
    pub code: Option<String>,
    pub note: Option<String>,
    pub version: Option<i32>,
}

// ── OrderValues ──────────────────────────────────────────────────────────
pub struct OrderValues {
    pub sku: Option<String>,
    pub qty: Option<i32>,
    pub region: Option<NodeRef>,
}

// ── PersonValues ──────────────────────────────────────────────────────────
pub struct PersonValues {
    pub name: Option<String>,
    pub next: Option<NodeRef>,
}

// ── BookValues ──────────────────────────────────────────────────────────
pub struct BookValues {
    pub orders: Vec<NodeRef>,
    pub people: Vec<NodeRef>,
}

pub trait RegionArena {
    const REGION_TYPE_ID: u64;
    fn arena_of_region(&self) -> &RefCell<Vec<RegionValues>>;
}

pub trait OrderArena {
    const ORDER_TYPE_ID: u64;
    fn arena_of_order(&self) -> &RefCell<Vec<OrderValues>>;
}

pub trait PersonArena {
    const PERSON_TYPE_ID: u64;
    fn arena_of_person(&self) -> &RefCell<Vec<PersonValues>>;
}

pub trait BookArena {
    const BOOK_TYPE_ID: u64;
    fn arena_of_book(&self) -> &RefCell<Vec<BookValues>>;
}

// ── GraphRegularGraphGraph ─────────────────────────────────────────────────────────────────────
pub trait GraphRegularGraphGraph: RegionArena + OrderArena + PersonArena + BookArena {
    fn new_region(&self, code: Option<&str>, note: Option<&str>, version: Option<i32>) -> Region<'_, Self> where Self: Sized {
        let _values = RegionValues {
                code: code.map(str::to_owned),
                note: note.map(str::to_owned),
                version: version,
        };
        let index = {
            let mut _arena = self.arena_of_region().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Region { index: index, graph: self }
    }
    fn new_region_defaulted(&self) -> Region<'_, Self> where Self: Sized {
        self.new_region(None, None, None)
    }
    fn new_order(&self, sku: Option<&str>, qty: Option<i32>, region: Option<Region<'_, Self>>) -> Order<'_, Self> where Self: Sized {
        let _values = OrderValues {
                sku: sku.map(str::to_owned),
                qty: qty,
                region: region.filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }),
        };
        let index = {
            let mut _arena = self.arena_of_order().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Order { index: index, graph: self }
    }
    fn new_order_defaulted(&self) -> Order<'_, Self> where Self: Sized {
        self.new_order(None, None, None)
    }
    fn new_person(&self, name: Option<&str>, next: Option<Person<'_, Self>>) -> Person<'_, Self> where Self: Sized {
        let _values = PersonValues {
                name: name.map(str::to_owned),
                next: next.filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }),
        };
        let index = {
            let mut _arena = self.arena_of_person().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Person { index: index, graph: self }
    }
    fn new_person_defaulted(&self) -> Person<'_, Self> where Self: Sized {
        self.new_person(None, None)
    }
    fn new_book(&self, orders: &[Order<'_, Self>], people: &[Person<'_, Self>]) -> Book<'_, Self> where Self: Sized {
        let _values = BookValues {
                orders: orders.iter().filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }).collect(),
                people: people.iter().filter(|h| std::ptr::eq(h.graph as *const Self, self as *const Self)).map(|h| NodeRef { index: h.index }).collect(),
        };
        let index = {
            let mut _arena = self.arena_of_book().borrow_mut();
            let idx = _arena.len() as u32;
            _arena.push(_values);
            idx
        };
        Book { index: index, graph: self }
    }
    fn new_book_defaulted(&self) -> Book<'_, Self> where Self: Sized {
        self.new_book(&[], &[])
    }
}
impl<T: RegionArena + OrderArena + PersonArena + BookArena> GraphRegularGraphGraph for T {}

// ── Region handle ────────────────────────────────────────────────────────
pub struct Region<'arena, G: GraphRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: GraphRegularGraphGraph> Clone for Region<'arena, G> {
    fn clone(&self) -> Self { Region { index: self.index, graph: self.graph } }
}
impl<'arena, G: GraphRegularGraphGraph> Copy for Region<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> Region<'arena, G> {
    pub fn code(&self) -> Option<String> {
        self.graph.arena_of_region().borrow()[self.index as usize].code.clone()
    }
    pub fn set_code(&self, v: Option<&str>) {
        self.graph.arena_of_region().borrow_mut()[self.index as usize].code = v.map(str::to_owned);
    }
    pub fn note(&self) -> Option<String> {
        self.graph.arena_of_region().borrow()[self.index as usize].note.clone()
    }
    pub fn set_note(&self, v: Option<&str>) {
        self.graph.arena_of_region().borrow_mut()[self.index as usize].note = v.map(str::to_owned);
    }
    pub fn version(&self) -> Option<i32> {
        self.graph.arena_of_region().borrow()[self.index as usize].version
    }
    pub fn set_version(&self, v: Option<i32>) {
        self.graph.arena_of_region().borrow_mut()[self.index as usize].version = v;
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::REGION_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.code().hash(state);
        self.note().hash(state);
        self.version().hash(state);
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Region@{}", self.index);
        }
        write!(f, "Region@{} {{ ", self.index)?;
        write!(f, "code: {:?}, ", self.code())?;
        write!(f, "note: {:?}, ", self.note())?;
        write!(f, "version: {:?}", self.version())?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: GraphRegularGraphGraph>(&self, other: &Region<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.code() != other.code() { return false; }
        if self.note() != other.note() { return false; }
        if self.version() != other.version() { return false; }
        true
    }
}

impl<'a, 'b, A: GraphRegularGraphGraph, B: GraphRegularGraphGraph> PartialEq<Region<'b, B>> for Region<'a, A> {
    fn eq(&self, other: &Region<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: GraphRegularGraphGraph> Eq for Region<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> std::hash::Hash for Region<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: GraphRegularGraphGraph> fmt::Display for Region<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── Order handle ────────────────────────────────────────────────────────
pub struct Order<'arena, G: GraphRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: GraphRegularGraphGraph> Clone for Order<'arena, G> {
    fn clone(&self) -> Self { Order { index: self.index, graph: self.graph } }
}
impl<'arena, G: GraphRegularGraphGraph> Copy for Order<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> Order<'arena, G> {
    pub fn sku(&self) -> Option<String> {
        self.graph.arena_of_order().borrow()[self.index as usize].sku.clone()
    }
    pub fn set_sku(&self, v: Option<&str>) {
        self.graph.arena_of_order().borrow_mut()[self.index as usize].sku = v.map(str::to_owned);
    }
    pub fn qty(&self) -> Option<i32> {
        self.graph.arena_of_order().borrow()[self.index as usize].qty
    }
    pub fn set_qty(&self, v: Option<i32>) {
        self.graph.arena_of_order().borrow_mut()[self.index as usize].qty = v;
    }
    pub fn region(&self) -> Option<Region<'arena, G>> {
        let nr = {
            let arena = self.graph.arena_of_order().borrow();
            arena.get(self.index as usize)
                .and_then(|v| v.region)
        };
        nr.and_then(|nr| {
            let a = self.graph.arena_of_region().borrow();
            a.get(nr.index as usize)
                .map(|_| Region { index: nr.index, graph: self.graph })
        })
    }
    pub fn set_region(&self, v: Option<Region<'_, G>>) {
        let nr = v.filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
                  .map(|h| NodeRef { index: h.index });
        self.graph.arena_of_order().borrow_mut()[self.index as usize].region = nr;
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::ORDER_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.sku().hash(state);
        self.qty().hash(state);
        if let Some(v) = self.region() { v._hash_with(state, visited); }
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Order@{}", self.index);
        }
        write!(f, "Order@{} {{ ", self.index)?;
        write!(f, "sku: {:?}, ", self.sku())?;
        write!(f, "qty: {:?}, ", self.qty())?;
        write!(f, "region: ")?;
        match self.region() { Some(v) => v._fmt_with(f, visited)?, None => write!(f, "None")? };
        write!(f, " }}")
    }

    fn _cycle_eq<B: GraphRegularGraphGraph>(&self, other: &Order<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.sku() != other.sku() { return false; }
        if self.qty() != other.qty() { return false; }
        match (self.region(), other.region()) {
            (None, None) => {}
            (Some(a), Some(b)) => { if !a._cycle_eq(&b, visited) { return false; } }
            _ => return false,
        }
        true
    }
}

impl<'a, 'b, A: GraphRegularGraphGraph, B: GraphRegularGraphGraph> PartialEq<Order<'b, B>> for Order<'a, A> {
    fn eq(&self, other: &Order<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: GraphRegularGraphGraph> Eq for Order<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> std::hash::Hash for Order<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: GraphRegularGraphGraph> fmt::Display for Order<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── Person handle ────────────────────────────────────────────────────────
pub struct Person<'arena, G: GraphRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: GraphRegularGraphGraph> Clone for Person<'arena, G> {
    fn clone(&self) -> Self { Person { index: self.index, graph: self.graph } }
}
impl<'arena, G: GraphRegularGraphGraph> Copy for Person<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> Person<'arena, G> {
    pub fn name(&self) -> Option<String> {
        self.graph.arena_of_person().borrow()[self.index as usize].name.clone()
    }
    pub fn set_name(&self, v: Option<&str>) {
        self.graph.arena_of_person().borrow_mut()[self.index as usize].name = v.map(str::to_owned);
    }
    pub fn next(&self) -> Option<Person<'arena, G>> {
        let nr = {
            let arena = self.graph.arena_of_person().borrow();
            arena.get(self.index as usize)
                .and_then(|v| v.next)
        };
        nr.and_then(|nr| {
            let a = self.graph.arena_of_person().borrow();
            a.get(nr.index as usize)
                .map(|_| Person { index: nr.index, graph: self.graph })
        })
    }
    pub fn set_next(&self, v: Option<Person<'_, G>>) {
        let nr = v.filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
                  .map(|h| NodeRef { index: h.index });
        self.graph.arena_of_person().borrow_mut()[self.index as usize].next = nr;
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::PERSON_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        self.name().hash(state);
        if let Some(v) = self.next() { v._hash_with(state, visited); }
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Person@{}", self.index);
        }
        write!(f, "Person@{} {{ ", self.index)?;
        write!(f, "name: {:?}, ", self.name())?;
        write!(f, "next: ")?;
        match self.next() { Some(v) => v._fmt_with(f, visited)?, None => write!(f, "None")? };
        write!(f, " }}")
    }

    fn _cycle_eq<B: GraphRegularGraphGraph>(&self, other: &Person<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        if self.name() != other.name() { return false; }
        match (self.next(), other.next()) {
            (None, None) => {}
            (Some(a), Some(b)) => { if !a._cycle_eq(&b, visited) { return false; } }
            _ => return false,
        }
        true
    }
}

impl<'a, 'b, A: GraphRegularGraphGraph, B: GraphRegularGraphGraph> PartialEq<Person<'b, B>> for Person<'a, A> {
    fn eq(&self, other: &Person<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: GraphRegularGraphGraph> Eq for Person<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> std::hash::Hash for Person<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: GraphRegularGraphGraph> fmt::Display for Person<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── Book handle ────────────────────────────────────────────────────────
pub struct Book<'arena, G: GraphRegularGraphGraph> {
    pub(crate) index: u32,
    pub(crate) graph: &'arena G,
}

impl<'arena, G: GraphRegularGraphGraph> Clone for Book<'arena, G> {
    fn clone(&self) -> Self { Book { index: self.index, graph: self.graph } }
}
impl<'arena, G: GraphRegularGraphGraph> Copy for Book<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> Book<'arena, G> {
    pub fn orders(&self) -> Vec<Order<'arena, G>> {
        let nrs: Vec<_> = {
            let arena = self.graph.arena_of_book().borrow();
            match arena.get(self.index as usize) {
                Some(v) => v.orders.clone(),
                _ => return vec![],
            }
        };
        nrs.into_iter().map(|nr| Order { index: nr.index, graph: self.graph }).collect()
    }
    pub fn set_orders(&self, vs: &[Order<'_, G>]) {
        let nrs = vs.iter()
            .filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
            .map(|h| NodeRef { index: h.index }).collect();
        self.graph.arena_of_book().borrow_mut()[self.index as usize].orders = nrs;
    }
    pub fn push_orders(&self, v: Order<'_, G>) {
        if std::ptr::eq(v.graph as *const G, self.graph as *const G) {
            let nr = NodeRef { index: v.index };
            self.graph.arena_of_book().borrow_mut()[self.index as usize].orders.push(nr);
        }
    }
    pub fn people(&self) -> Vec<Person<'arena, G>> {
        let nrs: Vec<_> = {
            let arena = self.graph.arena_of_book().borrow();
            match arena.get(self.index as usize) {
                Some(v) => v.people.clone(),
                _ => return vec![],
            }
        };
        nrs.into_iter().map(|nr| Person { index: nr.index, graph: self.graph }).collect()
    }
    pub fn set_people(&self, vs: &[Person<'_, G>]) {
        let nrs = vs.iter()
            .filter(|h| std::ptr::eq(h.graph as *const G, self.graph as *const G))
            .map(|h| NodeRef { index: h.index }).collect();
        self.graph.arena_of_book().borrow_mut()[self.index as usize].people = nrs;
    }
    pub fn push_people(&self, v: Person<'_, G>) {
        if std::ptr::eq(v.graph as *const G, self.graph as *const G) {
            let nr = NodeRef { index: v.index };
            self.graph.arena_of_book().borrow_mut()[self.index as usize].people.push(nr);
        }
    }

    fn _id(&self) -> (u64, usize, usize) {
        (G::BOOK_TYPE_ID, self.graph as *const G as usize, self.index as usize)
    }

    fn _hash_with<H: std::hash::Hasher>(&self, state: &mut H, visited: &mut HashSet<(u64, usize, usize)>) {
        if !visited.insert(self._id()) { return; }
        for v in &self.orders() { v._hash_with(state, visited); }
        for v in &self.people() { v._hash_with(state, visited); }
    }

    fn _fmt_with(&self, f: &mut fmt::Formatter<'_>, visited: &mut HashSet<(u64, usize, usize)>) -> fmt::Result {
        if !visited.insert(self._id()) {
            return write!(f, "Book@{}", self.index);
        }
        write!(f, "Book@{} {{ ", self.index)?;
        write!(f, "orders: [")?;
        { let _items = self.orders(); for (_i, _v) in _items.iter().enumerate() {
            if _i > 0 { write!(f, ", ")?; } _v._fmt_with(f, visited)?;
        } }
        write!(f, "], ")?;
        write!(f, "people: [")?;
        { let _items = self.people(); for (_i, _v) in _items.iter().enumerate() {
            if _i > 0 { write!(f, ", ")?; } _v._fmt_with(f, visited)?;
        } }
        write!(f, "]")?;
        write!(f, " }}")
    }

    fn _cycle_eq<B: GraphRegularGraphGraph>(&self, other: &Book<'_, B>,
        visited: &mut HashSet<((u64, usize, usize), (u64, usize, usize))>) -> bool {
        let pair = (self._id(), other._id());
        if visited.contains(&pair) { return true; }
        visited.insert(pair);
        { let sa = self.orders(); let sb = other.orders();
          if sa.len() != sb.len() { return false; }
          if !sa.iter().zip(sb.iter()).all(|(a, b)| a._cycle_eq(b, visited)) { return false; } }
        { let sa = self.people(); let sb = other.people();
          if sa.len() != sb.len() { return false; }
          if !sa.iter().zip(sb.iter()).all(|(a, b)| a._cycle_eq(b, visited)) { return false; } }
        true
    }
}

impl<'a, 'b, A: GraphRegularGraphGraph, B: GraphRegularGraphGraph> PartialEq<Book<'b, B>> for Book<'a, A> {
    fn eq(&self, other: &Book<'b, B>) -> bool {
        let mut v = HashSet::new(); self._cycle_eq(other, &mut v)
    }
}
impl<'arena, G: GraphRegularGraphGraph> Eq for Book<'arena, G> {}

impl<'arena, G: GraphRegularGraphGraph> std::hash::Hash for Book<'arena, G> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut v = HashSet::new(); self._hash_with(state, &mut v);
    }
}

impl<'arena, G: GraphRegularGraphGraph> fmt::Display for Book<'arena, G> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut v = HashSet::new(); self._fmt_with(f, &mut v)
    }
}

// ── GraphRegularGraphArena<const ID: u64> ─────────────────────────────────────────────────────
pub struct GraphRegularGraphArena<const ID: u64> {
    arena_of_region: RefCell<Vec<RegionValues>>,
    arena_of_order: RefCell<Vec<OrderValues>>,
    arena_of_person: RefCell<Vec<PersonValues>>,
    arena_of_book: RefCell<Vec<BookValues>>,
    root: Cell<Option<NodeRef>>,
}

impl<const ID: u64> RegionArena for GraphRegularGraphArena<ID> {
    const REGION_TYPE_ID: u64 = ID * 100 + 0;
    fn arena_of_region(&self) -> &RefCell<Vec<RegionValues>> {
        &self.arena_of_region
    }
}

impl<const ID: u64> OrderArena for GraphRegularGraphArena<ID> {
    const ORDER_TYPE_ID: u64 = ID * 100 + 1;
    fn arena_of_order(&self) -> &RefCell<Vec<OrderValues>> {
        &self.arena_of_order
    }
}

impl<const ID: u64> PersonArena for GraphRegularGraphArena<ID> {
    const PERSON_TYPE_ID: u64 = ID * 100 + 2;
    fn arena_of_person(&self) -> &RefCell<Vec<PersonValues>> {
        &self.arena_of_person
    }
}

impl<const ID: u64> BookArena for GraphRegularGraphArena<ID> {
    const BOOK_TYPE_ID: u64 = ID * 100 + 3;
    fn arena_of_book(&self) -> &RefCell<Vec<BookValues>> {
        &self.arena_of_book
    }
}

impl<const ID: u64> GraphRegularGraphArena<ID> {
    pub fn new() -> Self {
        GraphRegularGraphArena {
            arena_of_region: RefCell::new(Vec::new()),
            arena_of_order: RefCell::new(Vec::new()),
            arena_of_person: RefCell::new(Vec::new()),
            arena_of_book: RefCell::new(Vec::new()),
            root: Cell::new(None),
        }
    }

    pub fn get_root(&self) -> Option<Book<'_, Self>> {
        self.root.get().and_then(|nr| {
            let a = self.arena_of_book().borrow();
            a.get(nr.index as usize)
                .map(|_| Book { index: nr.index, graph: self })
        })
    }

    pub fn set_root(&self, node: Option<Book<'_, Self>>) {
        self.root.set(node.map(|h| NodeRef { index: h.index }));
    }
}

impl<const ID: u64> Default for GraphRegularGraphArena<ID> {
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

// ── Region serde ──────────────────────────────────────────────────────────
impl<'arena, G: GraphRegularGraphGraph> Region<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::REGION_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_region().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _note_off = _pr.note.as_deref().map(|s| b.store_string(s));
        let _code_off = _pr.code.as_deref().map(|s| b.store_string(s));
        let _version_ptr = self.version().map(|v| b.store_i32(v));
        let _note_ptr = _note_off.map(|off| b.store_forward_pointer(off));
        let _code_ptr = _code_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_code_ptr, _note_ptr, _version_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::REGION_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_region().borrow();
        let _pr = &_pr_row[self.index as usize];
        if let Some(_v) = self.version() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 4 {
                b.store_leb(_zz); b.store_leb((2u64 << 1) | 0);
            } else { b.store_i32(_v); b.store_leb((2u64 << 1) | 1); }
        }
        if let Some(_s) = _pr.note.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((1u64 << 1) | 1); }
        if let Some(_s) = _pr.code.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((0u64 << 1) | 1); }
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

// ── Order serde ──────────────────────────────────────────────────────────
impl<'arena, G: GraphRegularGraphGraph> Order<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::ORDER_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_order().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _region_off = if let Some(n) = self.region() { n.store(b).ok() } else { None };
        let _sku_off = _pr.sku.as_deref().map(|s| b.store_string(s));
        let _region_ptr = _region_off.map(|r| b.store_bidir_pointer(r));
        let _qty_ptr = self.qty().map(|v| b.store_i32(v));
        let _sku_ptr = _sku_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_sku_ptr, _qty_ptr, _region_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::ORDER_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        let _pr_row = self.graph.arena_of_order().borrow();
        let _pr = &_pr_row[self.index as usize];
        if let Some(_n) = self.region() {
            _n.store_packed(b)?;
            b.store_leb((2u64 << 1) | 1);
        }
        if let Some(_v) = self.qty() {
            let _zz = crate::dagr_runtime::to_zigzag(_v as i64);
            if crate::dagr_runtime::leb_length(_zz) < 4 {
                b.store_leb(_zz); b.store_leb((1u64 << 1) | 0);
            } else { b.store_i32(_v); b.store_leb((1u64 << 1) | 1); }
        }
        if let Some(_s) = _pr.sku.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((0u64 << 1) | 1); }
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

// ── Person serde ──────────────────────────────────────────────────────────
impl<'arena, G: GraphRegularGraphGraph> Person<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::PERSON_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing(_id) { return Ok(r); }
        let _pr_row = self.graph.arena_of_person().borrow();
        let _pr = &_pr_row[self.index as usize];
        let _next_off = if let Some(n) = self.next() { n.store(b).ok() } else { None };
        let _name_off = _pr.name.as_deref().map(|s| b.store_string(s));
        let _next_ptr = _next_off.map(|r| b.store_bidir_pointer(r));
        let _name_ptr = _name_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_name_ptr, _next_ptr]);
        b.finish_storing(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::PERSON_TYPE_ID, index: self.index as usize };
        let _before = b.begin_packed_storing(_id).ok_or(DagrError::CycleWhilePackedStoring)?;
        let _pr_row = self.graph.arena_of_person().borrow();
        let _pr = &_pr_row[self.index as usize];
        if let Some(_n) = self.next() {
            _n.store_packed(b)?;
            b.store_leb((1u64 << 1) | 1);
        }
        if let Some(_s) = _pr.name.as_deref() { let _bs = _s.as_bytes(); b.store_raw(_bs); b.store_leb(_bs.len() as u64); b.store_leb((0u64 << 1) | 1); }
        b.store_leb((b.cursor() - _before) as u64);
        b.finish_packed_storing(_id);
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

// ── Book serde ──────────────────────────────────────────────────────────
impl<'arena, G: GraphRegularGraphGraph> Book<'arena, G> {
    pub fn store(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::BOOK_TYPE_ID, index: self.index as usize };
        if let Some(r) = b.begin_storing_acyclic(_id) { return Ok(r); }
        let mut _people_items = b.take_ref_scratch();
        {
            let _row_people = self.graph.arena_of_book().borrow();
            let _refs_people = &_row_people[self.index as usize].people;
            let _cb_people = self.graph.arena_of_person().borrow();
            for _nr in _refs_people.iter().rev() {
                if _cb_people.get(_nr.index as usize).is_some() {
                    if let Ok(_r) = (Person { index: _nr.index, graph: self.graph }).store(b) { _people_items.push(_r); }
                }
            }
        }
        let _people_off = Some(b.store_node_ref_array(&_people_items, b.cursor()));
        b.return_ref_scratch(_people_items);
        let mut _orders_items = b.take_ref_scratch();
        {
            let _row_orders = self.graph.arena_of_book().borrow();
            let _refs_orders = &_row_orders[self.index as usize].orders;
            let _cb_orders = self.graph.arena_of_order().borrow();
            for _nr in _refs_orders.iter().rev() {
                if _cb_orders.get(_nr.index as usize).is_some() {
                    if let Ok(_r) = (Order { index: _nr.index, graph: self.graph }).store(b) { _orders_items.push(_r); }
                }
            }
        }
        let _orders_off = Some(b.store_node_ref_array(&_orders_items, b.cursor()));
        b.return_ref_scratch(_orders_items);
        let _people_ptr = _people_off.map(|off| b.store_forward_pointer(off));
        let _orders_ptr = _orders_off.map(|off| b.store_forward_pointer(off));
        let _offset = b.store_vtable(&[_orders_ptr, _people_ptr]);
        b.record_node_offset(_id, _offset);
        Ok(NodeStoreRef::Offset(_offset))
    }

    pub fn store_packed(&self, b: &mut DagrBuilder) -> Result<NodeStoreRef, DagrError> {
        let _id = CycleId { type_id: G::BOOK_TYPE_ID, index: self.index as usize };
        let _before = b.cursor();
        {
            let _row_people = self.graph.arena_of_book().borrow();
            let _refs_people = &_row_people[self.index as usize].people;
            let _cb_people = self.graph.arena_of_person().borrow();
            let _valid_people = _refs_people.iter().filter(|_nr| _cb_people.get(_nr.index as usize).is_some()).count();
            if _valid_people > 0 {
                let _bef = b.cursor();
                for _nr in _refs_people.iter().rev() {
                    if _cb_people.get(_nr.index as usize).is_some() {
                        Person { index: _nr.index, graph: self.graph }.store_packed(b)?;
                    }
                }
                b.store_leb(_valid_people as u64);
                b.store_leb((b.cursor() - _bef) as u64);
                b.store_leb((1u64 << 1) | 1);
            }
        }
        {
            let _row_orders = self.graph.arena_of_book().borrow();
            let _refs_orders = &_row_orders[self.index as usize].orders;
            let _cb_orders = self.graph.arena_of_order().borrow();
            let _valid_orders = _refs_orders.iter().filter(|_nr| _cb_orders.get(_nr.index as usize).is_some()).count();
            if _valid_orders > 0 {
                let _bef = b.cursor();
                for _nr in _refs_orders.iter().rev() {
                    if _cb_orders.get(_nr.index as usize).is_some() {
                        Order { index: _nr.index, graph: self.graph }.store_packed(b)?;
                    }
                }
                b.store_leb(_valid_orders as u64);
                b.store_leb((b.cursor() - _bef) as u64);
                b.store_leb((0u64 << 1) | 1);
            }
        }
        b.store_leb((b.cursor() - _before) as u64);
        b.record_node_offset(_id, b.cursor());
        Ok(NodeStoreRef::Offset(b.cursor()))
    }
}

fn _restore_region<'arena, G: GraphRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Region<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::REGION_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_region().borrow();
        let _ = &a;
        return Ok(Region { index: idx, graph: arena });
    }
    let _blank = RegionValues { code: None, note: None, version: None };
    let _idx = {
        let mut _arr = arena.arena_of_region().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Region { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _code_val = _slots.slot(0).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _note_val = _slots.slot(1).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _version_val = _slots.slot(2).map(|at| crate::dagr_runtime::read_i32(data, at).unwrap_or_default() as i32);
    _node.set_code(_code_val.as_deref());
    _node.set_note(_note_val.as_deref());
    _node.set_version(_version_val);
    Ok(_node)
}

fn _restore_order<'arena, G: GraphRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Order<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::ORDER_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_order().borrow();
        let _ = &a;
        return Ok(Order { index: idx, graph: arena });
    }
    let _blank = OrderValues { sku: None, qty: None, region: None };
    let _idx = {
        let mut _arr = arena.arena_of_order().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Order { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _sku_val = _slots.slot(0).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _qty_val = _slots.slot(1).map(|at| crate::dagr_runtime::read_i32(data, at).unwrap_or_default() as i32);
    let _region_val = _slots.slot(2).map(|bp_at| _restore_region(data, crate::dagr_runtime::read_bidir_pointer(data, bp_at)?, arena, cache)).transpose()?;
    _node.set_sku(_sku_val.as_deref());
    _node.set_qty(_qty_val);
    _node.set_region(_region_val);
    Ok(_node)
}

fn _restore_person<'arena, G: GraphRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Person<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::PERSON_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_person().borrow();
        let _ = &a;
        return Ok(Person { index: idx, graph: arena });
    }
    let _blank = PersonValues { name: None, next: None };
    let _idx = {
        let mut _arr = arena.arena_of_person().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Person { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _name_val = _slots.slot(0).map(|fwd| -> Result<String, DagrError> { Ok(crate::dagr_runtime::read_string(data, crate::dagr_runtime::read_forward_pointer(data, fwd)?)?) }).transpose()?;
    let _next_val = _slots.slot(1).map(|bp_at| _restore_person(data, crate::dagr_runtime::read_bidir_pointer(data, bp_at)?, arena, cache)).transpose()?;
    _node.set_name(_name_val.as_deref());
    _node.set_next(_next_val);
    Ok(_node)
}

fn _restore_book<'arena, G: GraphRegularGraphGraph>(
    data: &'arena [u8], at: usize, arena: &'arena G,
    cache: &mut std::collections::HashMap<(u64, usize), u32>,
) -> Result<Book<'arena, G>, DagrError> {
    if at >= data.len() { return Err(DagrError::InvalidData); }
    let _cache_key = (G::BOOK_TYPE_ID, at);
    if let Some(&idx) = cache.get(&_cache_key) {
        let a = arena.arena_of_book().borrow();
        let _ = &a;
        return Ok(Book { index: idx, graph: arena });
    }
    let _blank = BookValues { orders: vec![], people: vec![] };
    let _idx = {
        let mut _arr = arena.arena_of_book().borrow_mut();
        let idx = _arr.len() as u32;
        _arr.push(_blank);
        idx
    };
    let _node = Book { index: _idx, graph: arena };
    cache.insert(_cache_key, _node.index);
    let _slots = crate::dagr_runtime::read_vtable(data, at)?;
    let _orders_val = if let Some(fwd) = _slots.slot(0) {
        let at = crate::dagr_runtime::read_forward_pointer(data, fwd)?;
        let _items: Result<Vec<_>, DagrError> = crate::dagr_runtime::read_node_ref_array(data, at)?.into_iter()
            .filter_map(|p| p.map(|a| _restore_order(data, a, arena, cache)))
            .collect();
        _items?
    } else { vec![] };
    let _people_val = if let Some(fwd) = _slots.slot(1) {
        let at = crate::dagr_runtime::read_forward_pointer(data, fwd)?;
        let _items: Result<Vec<_>, DagrError> = crate::dagr_runtime::read_node_ref_array(data, at)?.into_iter()
            .filter_map(|p| p.map(|a| _restore_person(data, a, arena, cache)))
            .collect();
        _items?
    } else { vec![] };
    _node.set_orders(&_orders_val);
    _node.set_people(&_people_val);
    Ok(_node)
}

// ── Arena serde ─────────────────────────────────────────────────────────────
impl<const ID: u64> GraphRegularGraphArena<ID> {
    pub fn to_bytes(&self) -> Result<Vec<u8>, DagrError> {
        let root_opt = self.get_root();
        let root = root_opt.ok_or(DagrError::StaleReference)?;
        let mut b = DagrBuilder::with_hint(self.arena_of_region().borrow().len() + self.arena_of_order().borrow().len() + self.arena_of_person().borrow().len() + self.arena_of_book().borrow().len());
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

    /// Like `to_bytes`, for a buffer that will travel `alignment_offset` bytes into an envelope
    /// (a frame header, a length word — 12 §14): its aligned arrays land on their boundary in
    /// the envelope's frame. With a caller-owned builder, `set_alignment_offset` + `write_into`.
    pub fn to_bytes_with_alignment_offset(&self, alignment_offset: usize) -> Result<Vec<u8>, DagrError> {
        let mut b = DagrBuilder::with_hint(self.arena_of_region().borrow().len() + self.arena_of_order().borrow().len() + self.arena_of_person().borrow().len() + self.arena_of_book().borrow().len());
        b.set_alignment_offset(alignment_offset);
        self.write_into(&mut b)?;
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
        let root = _restore_book(data, root_at, &arena, &mut cache)?;
        arena.set_root(Some(root));
        Ok(arena)
    }
}