from ion_runtime.doc import (
    K_INT,
    K_LIST,
    K_NULL,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    IonDoc,
    SymRef,
)
from ion_runtime.error import DecodeError
from ion_runtime.symtab import Catalog, LocalTab, SharedTable


def sym_unknown() -> SymRef:
    return SymRef(-1, 0, -1, 0)


def sym_from_sid(mut doc: IonDoc, tab: LocalTab, sid: Int, offset: Int) raises DecodeError -> Int:
    """Resolve `sid` and return a symbol node. Local gaps become symbol zero."""
    if sid < 0:
        raise DecodeError(DecodeError.KIND_SYMBOL, offset)
    var got = tab.lookup(sid, offset)
    if sid == 0 or (not got.known and got.imp.byte_length() == 0):
        return doc.add_symbol_ref(sym_unknown())
    if got.known:
        var node = doc.add_symbol_text(got.text)
        var s = doc.syms[doc.nodes[node].a]
        s.sid = sid
        doc.syms[doc.nodes[node].a] = s
        return node
    var imp = doc.intern(got.imp)
    return doc.add_symbol_ref(SymRef(-1, sid, imp, got.imp_sid))


def _count_field(doc: IonDoc, id: Int, name: String) -> Int:
    var n = 0
    var i = 0
    while i < doc.nodes[id].nchild:
        var sym = doc.field_at(id, i)
        var s = doc.syms[sym]
        if s.text >= 0 and doc.texts[s.text] == name:
            n += 1
        i += 1
    return n


def _field(doc: IonDoc, id: Int, name: String) -> Int:
    var i = 0
    var n = doc.nodes[id].nchild
    while i < n:
        var sym = doc.field_at(id, i)
        var s = doc.syms[sym]
        if s.text >= 0 and doc.texts[s.text] == name:
            return doc.child_at(id, i)
        i += 1
    return -1


def _i64(doc: IonDoc, id: Int, offset: Int) raises DecodeError -> Int:
    var n = doc.nodes[id]
    if n.kind != K_INT:
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    if n.b > 2:
        raise DecodeError(DecodeError.KIND_RANGE, offset)
    var mag = UInt64(0)
    if n.b > 0:
        mag = UInt64(doc.limbs[n.a])
    if n.b > 1:
        mag = mag | (UInt64(doc.limbs[n.a + 1]) << UInt64(32))
    if n.c != 0:
        if mag > UInt64(9223372036854775808):
            raise DecodeError(DecodeError.KIND_RANGE, offset)
        return 0 - Int(mag)
    if mag > UInt64(9223372036854775807):
        raise DecodeError(DecodeError.KIND_RANGE, offset)
    return Int(mag)


def is_local_table(doc: IonDoc, id: Int) -> Bool:
    var n = doc.nodes[id]
    if n.ann_n == 0:
        return False
    var s = doc.syms[doc.anns[n.ann]]
    if s.text < 0:
        return False
    if doc.texts[s.text] != "$ion_symbol_table":
        return False
    if n.kind == K_STRUCT:
        return True
    return n.kind == K_NULL and n.a == K_STRUCT


def _sym_text_of(doc: IonDoc, id: Int) -> String:
    var n = doc.nodes[id]
    if n.kind != K_SYMBOL:
        return String()
    return doc.sym_text(n.a)


def apply_lst(mut doc: IonDoc, id: Int, mut tab: LocalTab, cat: Catalog, offset: Int) raises DecodeError:
    """Install the top-level local symbol table at `id`. The node is not a user value."""
    var n = doc.nodes[id]
    if n.kind == K_NULL:
        tab.reset_system()
        return
    var imp = _field(doc, id, "imports")
    if _count_field(doc, id, "imports") > 1 or _count_field(doc, id, "symbols") > 1:
        raise DecodeError(DecodeError.KIND_SYMBOL, offset)
    var extend = imp >= 0 and doc.nodes[imp].kind == K_SYMBOL and _sym_text_of(doc, imp) == "$ion_symbol_table"
    if not extend:
        if imp >= 0 and doc.nodes[imp].kind == K_LIST:
            tab.reset_system()
            var i = 0
            while i < doc.nodes[imp].nchild:
                var el = doc.child_at(imp, i)
                if doc.nodes[el].kind == K_STRUCT:
                    _import_one(doc, el, tab, cat, offset)
                i += 1
        elif imp < 0 or (doc.nodes[imp].kind == K_NULL):
            tab.reset_system()
        else:
            raise DecodeError(DecodeError.KIND_SYMBOL, offset)
    var syms = _field(doc, id, "symbols")
    if syms >= 0 and doc.nodes[syms].kind == K_LIST:
        var i = 0
        while i < doc.nodes[syms].nchild:
            var el = doc.child_at(syms, i)
            if doc.nodes[el].kind == K_STRING:
                _ = tab.add_text(doc.text_at(el))
            else:
                _ = tab.add_gap()
            i += 1


def _import_one(doc: IonDoc, id: Int, mut tab: LocalTab, cat: Catalog, offset: Int) raises DecodeError:
    var name_id = _field(doc, id, "name")
    if name_id < 0 or doc.nodes[name_id].kind != K_STRING:
        return
    var name = doc.text_at(name_id)
    if name.byte_length() == 0 or name == "$ion":
        return
    var version = 1
    var ver_id = _field(doc, id, "version")
    if ver_id >= 0 and doc.nodes[ver_id].kind == K_INT:
        var v = _i64(doc, ver_id, offset)
        if v >= 1:
            version = v
    var has_max = False
    var max_id = 0
    var max_at = _field(doc, id, "max_id")
    if max_at >= 0 and doc.nodes[max_at].kind == K_INT:
        var m = _i64(doc, max_at, offset)
        if m >= 0:
            has_max = True
            max_id = m
    if has_max and max_id == 0:
        return
    var idx = cat.exact(name, version)
    if idx < 0:
        if not has_max:
            raise DecodeError(DecodeError.KIND_SYMBOL, offset)
        idx = cat.greatest(name)
    if idx < 0:
        var dummy = SharedTable(name, version)
        tab.import_table(dummy, max_id, offset)
        return
    if not has_max:
        max_id = len(cat.tables[idx].texts)
    tab.import_table(cat.tables[idx], max_id, offset)
