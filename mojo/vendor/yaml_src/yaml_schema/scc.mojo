from std.collections import List

from yaml_schema.model import ST_ARRAY, ST_OBJECT, ST_OPTIONAL, ST_REF, ST_UNION, SchemaDoc


def scc_ids(doc: SchemaDoc) -> List[Int]:
    """Tarjan SCC. Returns component id per type index."""
    var n = len(doc.types)
    var index = List[Int]()
    var low = List[Int]()
    var on = List[Int]()
    var comp = List[Int]()
    var i = 0
    while i < n:
        index.append(-1)
        low.append(0)
        on.append(0)
        comp.append(-1)
        i += 1
    var stack = List[Int]()
    var next_index = 0
    var next_comp = 0
    i = 0
    while i < n:
        if index[i] < 0:
            _strong(doc, i, index, low, on, stack, next_index, next_comp, comp)
        i += 1
    return comp^


def _strong(
    doc: SchemaDoc,
    v: Int,
    mut index: List[Int],
    mut low: List[Int],
    mut on: List[Int],
    mut stack: List[Int],
    mut next_index: Int,
    mut next_comp: Int,
    mut comp: List[Int],
):
    index[v] = next_index
    low[v] = next_index
    next_index += 1
    stack.append(v)
    on[v] = 1
    var succs = _succ(doc, v)
    var i = 0
    while i < len(succs):
        var w = succs[i]
        if index[w] < 0:
            _strong(doc, w, index, low, on, stack, next_index, next_comp, comp)
            if low[w] < low[v]:
                low[v] = low[w]
        elif on[w] == 1:
            if index[w] < low[v]:
                low[v] = index[w]
        i += 1
    if low[v] == index[v]:
        while True:
            var w = stack[len(stack) - 1]
            _ = stack.pop()
            on[w] = 0
            comp[w] = next_comp
            if w == v:
                break
        next_comp += 1


def _succ(doc: SchemaDoc, v: Int) -> List[Int]:
    var out = List[Int]()
    var ty = doc.types[v].copy()
    if ty.kind == ST_REF or ty.kind == ST_OPTIONAL or ty.kind == ST_ARRAY:
        if ty.inner >= 0:
            out.append(ty.inner)
    elif ty.kind == ST_OBJECT:
        var i = 0
        while i < len(ty.props):
            out.append(ty.props[i].copy().type_id)
            i += 1
    elif ty.kind == ST_UNION:
        var i = 0
        while i < len(ty.branch_ids):
            out.append(ty.branch_ids[i])
            i += 1
    return out^
