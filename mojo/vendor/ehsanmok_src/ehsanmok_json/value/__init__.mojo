# json - `Value` package
#
# The split isolates pure string utilities (`raw_ops.mojo`) from the
# type itself (`value.mojo`):
#   - `value.mojo`     : tape-backed `Value` view over a `Document`.
#   - `owned.mojo`     : copy-on-write `OwnedValue` mutation tree.
#   - `raw_ops.mojo`   : pure JSON byte-level helpers shared with the
#       lazy parser.
#
# Public re-exports below are the cross-module surface that other
# subpackages (patch, jsonpath, schema, serialize, reflection, lazy)
# build against.

from .value import (
    Value,
    Null,
    make_view_value,
    _value_to_json,
)
from .raw_ops import (
    _extract_field_value,
    _extract_array_element,
    _extract_json_value,
    _count_array_elements,
    _extract_object_keys,
    _parse_json_pointer,
)
from .owned import (
    OwnedValue,
    _value_to_owned,
    _parse_owned_value,
    _owned_to_json,
    _materialize_for_write,
    _serialize_into_value,
    _set_at_pointer,
)
