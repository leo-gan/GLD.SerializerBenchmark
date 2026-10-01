from smile_runtime.doc import (
    K_ARRAY,
    K_BIGINT,
    K_BINARY,
    K_BOOL,
    K_DECIMAL,
    K_F32,
    K_F64,
    K_I32,
    K_I64,
    K_NULL,
    K_OBJECT,
    K_STRING,
    SmileDoc,
)


def _bytes_eq(da: SmileDoc, a: Int, db: SmileDoc, b: Int) -> Bool:
    var sa = da.slices[a]
    var sb = db.slices[b]
    if sa.n != sb.n:
        return False
    var i = 0
    while i < sa.n:
        if da.bytes[sa.at + i] != db.bytes[sb.at + i]:
            return False
        i += 1
    return True


def smile_eq(da: SmileDoc, a: Int, db: SmileDoc, b: Int) -> Bool:
    """Structural equality. int32 and int64 stay distinct, as do float widths and decimal scale."""
    if a < 0 or b < 0:
        return False
    var na = da.nodes[a]
    var nb = db.nodes[b]
    if na.kind != nb.kind:
        return False
    if na.kind == K_NULL:
        return True
    if na.kind == K_BOOL or na.kind == K_I32 or na.kind == K_I64 or na.kind == K_F32:
        return na.a == nb.a
    if na.kind == K_F64:
        return da.f64s[na.a] == db.f64s[nb.a]
    if na.kind == K_STRING:
        return da.texts[na.a] == db.texts[nb.a]
    if na.kind == K_BINARY or na.kind == K_BIGINT:
        return _bytes_eq(da, na.a, db, nb.a)
    if na.kind == K_DECIMAL:
        return na.a == nb.a and _bytes_eq(da, na.b, db, nb.b)
    if na.nchild != nb.nchild:
        return False
    var i = 0
    while i < na.nchild:
        var ea = da.edges[na.child + i]
        var eb = db.edges[nb.child + i]
        if na.kind == K_OBJECT and da.texts[ea.key] != db.texts[eb.key]:
            return False
        if not smile_eq(da, ea.val, db, eb.val):
            return False
        i += 1
    return True


def docs_eq(a: SmileDoc, b: SmileDoc) -> Bool:
    if len(a.top) != len(b.top):
        return False
    var i = 0
    while i < len(a.top):
        if not smile_eq(a, a.top[i], b, b.top[i]):
            return False
        i += 1
    return True
