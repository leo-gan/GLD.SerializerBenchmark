"""
cbor2 benchmark wrapper.

Call-path: prepare_data converts dataclasses to dicts (untimed).
Timed path uses dumps/loads.

Stream note
-----------
``cbor2.dump`` to ``BytesIO`` is fine, but the C-extension ``cbor2.load(fp)``
path mis-decodes some text-string payloads from an in-memory binary buffer
(``CBORDecodeError: error decoding text string`` / underlying UTF-8 error on
the first CBOR map byte). ``cbor2.loads(stream.read())`` is reliable and is
what we use for stream deserialize. Serialize still uses native ``dump``.
"""

from __future__ import annotations

import io
from typing import Any

import cbor2

from .base import Serializer
from ..converters import to_dict


class Cbor2Serializer(Serializer):
    native_kind = "dict"
    # dump is native; load uses loads(read()) due to cbor2+BytesIO bug (see module doc).
    stream_mode = "native"

    @property
    def name(self) -> str:
        return "cbor2"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        # Flat ObjectGraph (index edges) is a plain dict tree after to_dict.
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return cbor2.dumps(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return cbor2.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        cbor2.dump(obj, stream)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        # Avoid cbor2.load(BytesIO): broken for some string-heavy payloads (e.g. StringArray).
        return cbor2.loads(stream.read())
