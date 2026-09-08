# json - Core Value type.
#
# `Value` is the public JSON value type. Every `Value` is a
# tape-backed view over a `Document`: the data lives in
# `_doc[].tape[_tape_idx]` plus the side pools of `_doc`, and the
# accessors below read it back. Primitive constructors
# (`Value(Null())`, `Value(42)`, `Value("hi")`, ...) build a
# single-entry `Document` and wrap it. Mutations (`set` / `append`
# / `set_at`) materialise the view into an `OwnedValue` tree, splice
# in the change, and rebuild the document so every accessor still
# reads from a tape.

from std.collections import List
from std.memory import ArcPointer

from .raw_ops import _parse_json_pointer
from .owned import (
    OwnedValue,
    _materialize_for_write,
    _serialize_into_value,
    _set_at_pointer,
    _value_to_owned,
)
from ..document import (
    Document,
    TAPE_TAG_NULL,
    TAPE_TAG_BOOL,
    TAPE_TAG_INT,
    TAPE_TAG_FLOAT,
    TAPE_TAG_STRING,
    TAPE_TAG_STRING_OWNED,
    TAPE_TAG_ARRAY,
    TAPE_TAG_OBJECT,
    TAPE_TAG_KEY,
)


struct Null(Writable):
    """Represents JSON null."""

    def __init__(out self):
        pass

    def __str__(self) -> String:
        return "null"

    def write_to[W: Writer](self, mut writer: W):
        writer.write("null")


struct Value(Copyable, Movable, Writable):
    """A JSON value: a tape-backed view over a `Document`.

    `_doc` is shared via an `ArcPointer` so child views (e.g. those
    returned by `array_items()` / `__getitem__`) bump a refcount
    instead of cloning the document. `_tape_idx` is the entry's slot
    in `_doc[].tape`; the tag at that slot is what `is_*` /
    `*_value` / iteration walk.
    """

    var _doc: ArcPointer[Document]
    var _tape_idx: Int

    def __init__(out self, doc: ArcPointer[Document], tape_idx: Int):
        """Primary constructor: a tape-backed view over `doc[].tape[tape_idx]`.

        All other public constructors delegate here by building a
        single-entry `Document` and wrapping it in an `ArcPointer`.
        """
        self._doc = doc
        self._tape_idx = tape_idx

    def __init__(out self, null: Null):
        var d = Document()
        _ = d.append_null()
        self = Self(ArcPointer[Document](d^), 0)

    def __init__(out self, none: NoneType):
        var d = Document()
        _ = d.append_null()
        self = Self(ArcPointer[Document](d^), 0)

    def __init__(out self, b: Bool):
        var d = Document()
        _ = d.append_bool(b)
        self = Self(ArcPointer[Document](d^), 0)

    def __init__(out self, i: Int):
        var d = Document()
        _ = d.append_int(Int64(i))
        self = Self(ArcPointer[Document](d^), 0)

    def __init__(out self, i: Int64):
        var d = Document()
        _ = d.append_int(i)
        self = Self(ArcPointer[Document](d^), 0)

    def __init__(out self, f: Float64):
        var d = Document()
        _ = d.append_float(f)
        self = Self(ArcPointer[Document](d^), 0)

    def __init__(out self, var s: String):
        var d = Document()
        _ = d.append_string_owned(s^)
        self = Self(ArcPointer[Document](d^), 0)

    def copy(self) -> Self:
        """Create a copy of this Value.

        Cheap: the document lives behind an ArcPointer, so we bump a
        refcount and clone the tape index.

        Returns:
            A new Value with the same content.
        """
        return Value(self._doc.copy(), self._tape_idx)

    def clone(self) -> Self:
        """Alias for copy(). Creates a deep copy of this Value.

        Returns:
            A new Value with the same content.
        """
        return self.copy()

    @always_inline
    def _view_tag(self) -> UInt8:
        """Return the tape tag for the entry this view points at."""
        return self._doc[].get_tag(self._tape_idx)

    # Type checking
    def is_null(self) -> Bool:
        return self._view_tag() == TAPE_TAG_NULL

    def is_bool(self) -> Bool:
        return self._view_tag() == TAPE_TAG_BOOL

    def is_int(self) -> Bool:
        return self._view_tag() == TAPE_TAG_INT

    def is_float(self) -> Bool:
        return self._view_tag() == TAPE_TAG_FLOAT

    def is_string(self) -> Bool:
        var t = self._view_tag()
        return t == TAPE_TAG_STRING or t == TAPE_TAG_STRING_OWNED

    def is_array(self) -> Bool:
        return self._view_tag() == TAPE_TAG_ARRAY

    def is_object(self) -> Bool:
        return self._view_tag() == TAPE_TAG_OBJECT

    def is_number(self) -> Bool:
        var t = self._view_tag()
        return t == TAPE_TAG_INT or t == TAPE_TAG_FLOAT

    # Value extraction
    def bool_value(self) -> Bool:
        return self._doc[].get_bool(self._tape_idx)

    def int_value(self) -> Int64:
        return self._doc[].get_int(self._tape_idx)

    def float_value(self) -> Float64:
        return self._doc[].get_float(self._tape_idx)

    def string_value(self) -> String:
        return self._doc[].get_string(self._tape_idx)

    def raw_json(self) -> String:
        return _emit_view_json(self._doc, self._tape_idx)

    def array_count(self) -> Int:
        return self._doc[].get_count(self._tape_idx)

    def object_keys(self) -> List[String]:
        ref doc = self._doc[]
        var pair_count = doc.get_count(self._tape_idx)
        var child_start = doc.get_child_start(self._tape_idx)
        var keys = List[String](capacity=pair_count)
        for i in range(pair_count):
            keys.append(doc.get_key(child_start + 2 * i))
        return keys^

    def object_count(self) -> Int:
        return self._doc[].get_count(self._tape_idx)

    # Stringable
    def __str__(self) -> String:
        return _emit_view_json(self._doc, self._tape_idx)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.__str__())

    def __eq__(self, other: Value) -> Bool:
        """Equality compares serialized JSON form.

        Both sides are tape-backed views, so the only stable
        cross-document definition of equality is "same JSON". For
        primitives this still short-circuits through the typed
        accessors before falling back to a full serialize.
        """
        return _view_eq(self, other)

    def __ne__(self, other: Value) -> Bool:
        return not self.__eq__(other)

    def get(self, key: String) raises -> String:
        """Get a field value from a JSON object as a string.

        This is a helper for deserialization. For objects, it parses
        the raw JSON to extract the field value.

        Args:
            key: The field name to extract.

        Returns:
            The raw JSON value as a string.

        Raises:
            Error if not an object or key not found.
        """
        if not self.is_object():
            raise Error("get() can only be called on JSON objects")

        ref doc = self._doc[]
        var pair_count = doc.get_count(self._tape_idx)
        var child_start = doc.get_child_start(self._tape_idx)
        for i in range(pair_count):
            if doc.get_key(child_start + 2 * i) == key:
                var v = _make_view_child(self._doc, child_start + 2 * i + 1)
                return _view_to_json(v)
        raise Error("Key '" + key + "' not found in JSON object")

    def array_items(self) raises -> List[Value]:
        """Get all items in a JSON array as a list of Values.

        Returns:
            List of Value objects representing array elements.

        Raises:
            Error if not an array.

        Example:
            var data = loads('[1, "hello", true]')
            for item in data.array_items():
                print(item).
        """
        if not self.is_array():
            raise Error("array_items() can only be called on JSON arrays")

        ref doc = self._doc[]
        var count = doc.get_count(self._tape_idx)
        var child_start = doc.get_child_start(self._tape_idx)
        var result = List[Value](capacity=count)
        for i in range(count):
            result.append(_make_view_child(self._doc, child_start + i))
        return result^

    def object_items(self) raises -> List[Tuple[String, Value]]:
        """Get all key-value pairs in a JSON object.

        Returns:
            List of (key, value) tuples.

        Raises:
            Error if not an object.

        Example:
            var data = loads('{"a": 1, "b": 2}')
            for pair in data.object_items():
                var key = pair[0]
                var value = pair[1]
                print(key, value).
        """
        if not self.is_object():
            raise Error("object_items() can only be called on JSON objects")

        ref doc = self._doc[]
        var pair_count = doc.get_count(self._tape_idx)
        var child_start = doc.get_child_start(self._tape_idx)
        var result = List[Tuple[String, Value]](capacity=pair_count)
        for i in range(pair_count):
            var k = doc.get_key(child_start + 2 * i)
            var v = _make_view_child(self._doc, child_start + 2 * i + 1)
            result.append((k, v^))
        return result^

    def __getitem__(self, index: Int) raises -> Value:
        """Get array element by index.

        Args:
            index: Zero-based array index.

        Returns:
            The Value at the given index.

        Example:
            var arr = loads('[1, 2, 3]')
            print(arr[0])  # Prints 1.
        """
        if not self.is_array():
            raise Error("Index access requires a JSON array")

        var count = self._doc[].get_count(self._tape_idx)
        if index < 0 or index >= count:
            raise Error("Array index out of bounds: " + String(index))
        var child_start = self._doc[].get_child_start(self._tape_idx)
        return _make_view_child(self._doc, child_start + index)

    def __getitem__(self, key: String) raises -> Value:
        """Get object value by key.

        Args:
            key: Object key.

        Returns:
            The Value for the given key.

        Example:
            var obj = loads('{"name": "Alice"}')
            print(obj["name"])  # Prints "Alice".
        """
        if not self.is_object():
            raise Error("Key access requires a JSON object")

        ref doc = self._doc[]
        var pair_count = doc.get_count(self._tape_idx)
        var child_start = doc.get_child_start(self._tape_idx)
        for i in range(pair_count):
            if doc.get_key(child_start + 2 * i) == key:
                return _make_view_child(self._doc, child_start + 2 * i + 1)
        raise Error("Key not found: " + key)

    def set(mut self, key: String, value: Value) raises:
        """Set or update a value in a JSON object.

        Routes through `OwnedValue` so the in-memory tree stays the source of
        truth for the mutation. The view is then re-serialized so subsequent
        reads via `raw_json()` / `__str__()` observe the new state.

        Args:
            key: Object key.
            value: New value to set.

        Example:
            var obj = loads('{"name": "Alice"}')
            obj.set("age", Value(30))
            obj.set("name", Value("Bob"))  # Update existing.
        """
        if not self.is_object():
            raise Error("set() can only be called on JSON objects")

        var owned = _materialize_for_write(self)
        var owned_value = _value_to_owned(value)

        var key_pos = -1
        for i in range(len(owned.object_keys)):
            if owned.object_keys[i] == key:
                key_pos = i
                break

        if key_pos >= 0:
            owned.object_values[key_pos] = owned_value^
        else:
            owned.object_keys.append(key)
            owned.object_values.append(owned_value^)

        var rebuilt = _serialize_into_value(owned)
        # Install the rebuilt tape view in place of the current one.
        self._doc = rebuilt._doc.copy()
        self._tape_idx = rebuilt._tape_idx

    def set(mut self, index: Int, value: Value) raises:
        """Set a value at an array index.

        Args:
            index: Array index (must be valid).
            value: New value to set.

        Example:
            var arr = loads('[1, 2, 3]')
            arr.set(1, Value(20))  # Result is `[1, 20, 3]`.
        """
        if not self.is_array():
            raise Error("set(index) can only be called on JSON arrays")
        var current_count = self.array_count()
        if index < 0 or index >= current_count:
            raise Error("Array index out of bounds: " + String(index))

        var owned = _materialize_for_write(self)
        var owned_value = _value_to_owned(value)
        owned.array_val[index] = owned_value^

        var rebuilt = _serialize_into_value(owned)
        self._doc = rebuilt._doc.copy()
        self._tape_idx = rebuilt._tape_idx

    def append(mut self, value: Value) raises:
        """Append a value to a JSON array.

        Args:
            value: Value to append.

        Example:
            var arr = loads('[1, 2]')
            arr.append(Value(3))  # Result is `[1, 2, 3]`.
        """
        if not self.is_array():
            raise Error("append() can only be called on JSON arrays")

        var owned = _materialize_for_write(self)
        var owned_value = _value_to_owned(value)
        owned.array_val.append(owned_value^)

        var rebuilt = _serialize_into_value(owned)
        self._doc = rebuilt._doc.copy()
        self._tape_idx = rebuilt._tape_idx

    def set_at(mut self, pointer: String, value: Value) raises:
        """Set a nested value via JSON Pointer (RFC 6901).

        Unlike chained `__getitem__`, this propagates the mutation through the
        full parent chain. Intermediate objects/arrays are created or updated
        as required by the pointer; missing scalar parents raise.

        Args:
            pointer: JSON Pointer string (`""` for root, `"/a/b"` for nested).
            value: New value to install at `pointer`.

        Example:
            var doc = loads('{"a":{"b":1}}')
            doc.set_at("/a/b", Value(42))  # Result is `{"a":{"b":42}}`.
        """
        if pointer == "":
            # Whole-document replacement.
            self._doc = value._doc.copy()
            self._tape_idx = value._tape_idx
            return

        var tokens = _parse_json_pointer(pointer)
        var tree = _materialize_for_write(self)
        var new_val = _value_to_owned(value)
        _set_at_pointer(tree, tokens, 0, new_val^)

        var rebuilt = _serialize_into_value(tree)
        self._doc = rebuilt._doc.copy()
        self._tape_idx = rebuilt._tape_idx

    def at(self, pointer: String) raises -> Value:
        """Navigate to a value using JSON Pointer (RFC 6901).

        JSON Pointer syntax:
            "" (empty) = the whole document.
            "/foo" = member "foo" of object.
            "/foo/0" = first element of array "foo".
            "/a~1b" = member "a/b" (/ escaped as ~1).
            "/m~0n" = member "m~n" (~ escaped as ~0).

        Args:
            pointer: JSON Pointer string (e.g., "/users/0/name").

        Returns:
            The Value at the pointer location.

        Raises:
            Error if pointer is invalid or path doesn't exist.

        Example:
            var data = loads('{"users":[{"name":"Alice"}]}')
            var name = data.at("/users/0/name")  # `Value("Alice")`.
        """
        if pointer == "":
            return self.copy()

        if not pointer.startswith("/"):
            raise Error("JSON Pointer must start with '/' or be empty")

        var tokens = _parse_json_pointer(pointer)
        var current = self.copy()
        for i in range(len(tokens)):
            var token = tokens[i]
            if current.is_object():
                current = current[token]
            elif current.is_array():
                var index: Int
                try:
                    index = atol(token)
                except:
                    raise Error("Array index must be a number: " + token)
                if index < 0:
                    raise Error("Array index cannot be negative: " + token)
                current = current[index]
            else:
                raise Error(
                    "Cannot navigate into primitive value with pointer: /"
                    + token
                )
        return current^


# ---------------------------------------------------------------------------
# Value-dependent helpers
# ---------------------------------------------------------------------------


def _value_to_json(v: Value) -> String:
    """Convert a Value to its JSON string representation.

    Used by `Value.set` / `Value.append` to render the new value into
    JSON text before splicing it into the raw object/array string.
    The full-featured serializer (indent, escape options, etc.) is
    `serialize.dumps`; mutation uses the structured copy-on-write
    path in `value/owned.mojo`.
    """
    if v.is_null():
        return "null"
    elif v.is_bool():
        return "true" if v.bool_value() else "false"
    elif v.is_int():
        return String(v.int_value())
    elif v.is_float():
        return String(v.float_value())
    elif v.is_string():
        var result = String('"')
        var s = v.string_value()
        var s_bytes = s.as_bytes()
        for i in range(len(s_bytes)):
            var c = s_bytes[i]
            if c == UInt8(ord('"')):
                result += '\\"'
            elif c == UInt8(ord("\\")):
                result += "\\\\"
            elif c == UInt8(ord("\n")):
                result += "\\n"
            elif c == UInt8(ord("\r")):
                result += "\\r"
            elif c == UInt8(ord("\t")):
                result += "\\t"
            else:
                result += chr(Int(c))
        result += '"'
        return result^
    elif v.is_array() or v.is_object():
        return v.raw_json()
    return "null"


# ---------------------------------------------------------------------------
# Tape-backed view helpers
# ---------------------------------------------------------------------------


def make_view_value(doc: ArcPointer[Document], tape_idx: Int) -> Value:
    """Build a tape-backed `Value` view over `doc[].tape[tape_idx]`.

    Thin wrapper around the `Value(doc, tape_idx)` primary
    constructor. Kept as a free function so callers don't need to
    spell out the type, and so the construction site reads as
    "make a view" rather than "build a Value".
    """
    return Value(doc, tape_idx)


def _make_view_child(doc: ArcPointer[Document], tape_idx: Int) -> Value:
    """Build a child view by sharing the parent's `doc`."""
    return Value(doc, tape_idx)


def _view_to_json(v: Value) -> String:
    """Serialize a tape-backed view into a JSON string.

    Used by `Value.raw_json()` / `Value.__str__()` / equality
    comparison. Walks the tape recursively. Non-raising: on a corrupt
    tape the function returns a sentinel "<bad-tape>" string, which is
    a strictly better failure mode than panicking inside `__str__`.
    """
    return _emit_view_json(v._doc, v._tape_idx)


def _emit_view_json(doc: ArcPointer[Document], tape_idx: Int) -> String:
    ref d = doc[]
    var tag = d.get_tag(tape_idx)
    if tag == TAPE_TAG_NULL:
        return "null"
    if tag == TAPE_TAG_BOOL:
        return "true" if d.get_bool(tape_idx) else "false"
    if tag == TAPE_TAG_INT:
        return String(d.get_int(tape_idx))
    if tag == TAPE_TAG_FLOAT:
        return String(d.get_float(tape_idx))
    if tag == TAPE_TAG_STRING or tag == TAPE_TAG_STRING_OWNED:
        var s = d.get_string(tape_idx)
        return _escape_json_string(s)
    if tag == TAPE_TAG_ARRAY:
        var count = d.get_count(tape_idx)
        var child_start = d.get_child_start(tape_idx)
        var out = String("[")
        for i in range(count):
            if i > 0:
                out += ","
            out += _emit_view_json(doc, child_start + i)
        out += "]"
        return out^
    if tag == TAPE_TAG_OBJECT:
        var pair_count = d.get_count(tape_idx)
        var child_start = d.get_child_start(tape_idx)
        var out = String("{")
        for i in range(pair_count):
            if i > 0:
                out += ","
            var key = d.get_key(child_start + 2 * i)
            out += _escape_json_string(key)
            out += ":"
            out += _emit_view_json(doc, child_start + 2 * i + 1)
        out += "}"
        return out^
    return String("<bad-tape>")


def _escape_json_string(s: String) -> String:
    """Wrap a string in quotes and escape the JSON-mandatory bytes
    (`\"`, `\\`, control chars 0..31). Used by `_emit_view_json`.
    """
    var out = String('"')
    var b = s.as_bytes()
    for i in range(len(b)):
        var c = b[i]
        if c == UInt8(ord('"')):
            out += '\\"'
        elif c == UInt8(ord("\\")):
            out += "\\\\"
        elif c == UInt8(ord("\n")):
            out += "\\n"
        elif c == UInt8(ord("\r")):
            out += "\\r"
        elif c == UInt8(ord("\t")):
            out += "\\t"
        elif c == UInt8(ord("\b")):
            out += "\\b"
        elif c == UInt8(ord("\f")):
            out += "\\f"
        elif c < UInt8(0x20):
            out += "\\u00"
            var hi = Int(c) >> 4
            var lo = Int(c) & 0xF
            out += chr(ord("0") + hi) if hi < 10 else chr(ord("a") + hi - 10)
            out += chr(ord("0") + lo) if lo < 10 else chr(ord("a") + lo - 10)
        else:
            out += chr(Int(c))
    out += '"'
    return out^


def _view_eq(a: Value, b: Value) -> Bool:
    """Equality comparison between two tape-backed views.

    Compares by serialized JSON form for containers; primitives still
    short-circuit through the typed accessors so most comparisons stay
    cheap.
    """
    var sa = a.raw_json() if (a.is_array() or a.is_object()) else String()
    var sb = b.raw_json() if (b.is_array() or b.is_object()) else String()
    if a.is_array() or a.is_object() or b.is_array() or b.is_object():
        if a.is_array() != b.is_array():
            return False
        if a.is_object() != b.is_object():
            return False
        return sa == sb
    if a.is_null() != b.is_null():
        return False
    if a.is_null():
        return True
    if a.is_bool() != b.is_bool():
        return False
    if a.is_bool():
        return a.bool_value() == b.bool_value()
    if a.is_int() != b.is_int():
        return False
    if a.is_int():
        return a.int_value() == b.int_value()
    if a.is_float() != b.is_float():
        return False
    if a.is_float():
        return a.float_value() == b.float_value()
    if a.is_string() != b.is_string():
        return False
    if a.is_string():
        return a.string_value() == b.string_value()
    return False
