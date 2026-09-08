"""Curated re-export of the names everyday json code reaches for.

A typical module that talks to JSON in Mojo touches the same handful
of names: ``loads`` / ``dumps`` / ``load`` / ``dump`` for the Python-
like entry points, ``Value`` / ``Null`` for the result type,
``ParserConfig`` / ``SerializerConfig`` for the rare-tuning knob, and
the reflection serde shortcuts ``serialize_json`` /
``deserialize_json`` / ``try_deserialize_json``. ``json.prelude`` is
the wildcard-importable shortcut for that exact set, so the canonical
import block shrinks from 5-6 lines to one::

    from json.prelude import *

    @fieldwise_init
    struct Person(Defaultable, Movable):
        var name: String
        var age:  Int

        def __init__(out self):
            self.name = ""
            self.age = 0

    def main() raises:
        var p = deserialize_json[Person]('{"name":"Alice","age":30}')
        print(p.name, p.age)
        print(dumps(serialize_value(p), indent="  "))

Domain-specific surfaces are deliberately *not* re-exported so the
prelude stays small enough that the import block of a real module
still documents which features it actually uses:

* JSONPath (``jsonpath_query``, ``jsonpath_one``) -- import from
  ``json.jsonpath``.
* JSON Patch / Merge Patch (``apply_patch``, ``merge_patch``,
  ``create_merge_patch``) -- import from ``json.patch``.
* JSON Schema (``validate``, ``is_valid``, ``ValidationResult``,
  ``ValidationError``) -- import from ``json.schema``.
* Streaming / lazy (``LazyValue``, ``StreamingParser``,
  ``ArrayStreamingParser``) -- import from ``json.lazy`` /
  ``json.streaming``.
* Manual serde traits (``Serializable``, ``Deserializable``,
  ``to_json_value``, ``to_json_string``, ``get_int`` / ``get_string``
  / ``get_bool`` / ``get_float``) -- import from ``json.serialize``
  and ``json.deserialize``.
* simdjson FFI (``SimdjsonFFI``) -- import from
  ``json.cpu.simdjson_ffi``.

For those, import the specific names from the matching module. The
prelude is the "first ten lines of code" surface, not the kitchen sink.
"""

# Core entry points.
from .parser import loads, load
from .serialize import dumps, dump
from .config import ParserConfig, SerializerConfig

# Value view + null sentinel.
from .value import Value, Null

# Reflection serde -- the zero-boilerplate path most apps use.
from .reflection import (
    serialize_json,
    serialize_value,
    deserialize_json,
    deserialize_value,
    try_deserialize_json,
    JsonSerializable,
    JsonDeserializable,
)
