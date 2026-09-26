from avro_json.parse import parse_json
from avro_json.value import JSON_ARRAY, JSON_OBJECT, JSON_STRING, JsonDoc
from avro_schema.model import SchemaError, SchemaPool
from avro_schema.parse_avsc import parse_schema


def parse_avpr(text: String) raises SchemaError -> SchemaPool:
    """Parse Avro protocol JSON. Keep types, ignore messages."""
    var doc: JsonDoc
    try:
        doc = parse_json(text)
    except _:
        raise SchemaError("invalid protocol JSON")
    if doc.kind(doc.root) != JSON_OBJECT:
        raise SchemaError("protocol must be a JSON object")
    var proto = doc.find(doc.root, String("protocol"))
    if proto < 0 or doc.kind(proto) != JSON_STRING:
        raise SchemaError("protocol missing protocol name")
    var ns = String()
    var nsf = doc.find(doc.root, String("namespace"))
    if nsf >= 0 and doc.kind(nsf) == JSON_STRING:
        ns = doc.as_string(nsf)
    var types = doc.find(doc.root, String("types"))
    if types < 0 or doc.kind(types) != JSON_ARRAY:
        raise SchemaError("protocol missing types")
    var pool = SchemaPool()
    pool.original_json = text
    var n = doc.nodes[types].count
    if n == 0:
        raise SchemaError("protocol types empty")
    var i = 0
    var first = -1
    while i < n:
        var sid = parse_schema(pool, doc, doc.child(types, i), ns)
        if first < 0:
            first = sid
        i += 1
    pool.root = first
    return pool^
