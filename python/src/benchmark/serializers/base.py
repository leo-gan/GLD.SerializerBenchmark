"""
Base serializer interface, analogous to C#'s ISerDeser.

Every serializer wrapper implements both `bytes` and `stream` modes.
For libraries without native stream APIs, the wrapper adapts via io.BytesIO.

Call-path contract (fair timing)
--------------------------------
Timed methods must only measure encode/decode of *library-native* values:

1. ``prepare(name, type)`` — pre-build encoders, schemas, buffers (untimed).
2. ``prepare_data(obj, ...)`` — convert shared dataclasses to native form (untimed).
3. ``serialize_*`` / ``deserialize_*`` — codec only (timed).

Conversion helpers (dataclass ↔ dict/Message/Struct) must not run inside the
timed path. Stream mode is either a *native* stream API or an *adapted*
bytes-then-write path; subclasses set ``stream_mode`` accordingly.
"""

from __future__ import annotations

import io
from abc import ABC, abstractmethod
from typing import Any, Literal

# What the timed serialize path expects as input after prepare_data.
NativeKind = Literal[
    "dataclass",  # pickle-family: original fixtures
    "dict",  # JSON/binary schemaless after to_dict
    "struct",  # msgspec.Struct
    "message",  # protobuf Message / flatbuffer builder payload
    "model",  # pydantic / mashumaro / serpyco-style models
]

# How stream mode is implemented for this serializer.
StreamMode = Literal[
    "native",  # library has real stream/file API used in stream methods
    "adapted",  # serialize_bytes + write / read + deserialize_bytes
]


class Serializer(ABC):
    """Abstract base for all serializer benchmarks."""

    #: Documented input kind after ``prepare_data`` (for analysis/docs).
    native_kind: NativeKind = "dataclass"

    #: Whether stream methods use a real stream API or adapt from bytes.
    stream_mode: StreamMode = "adapted"

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable serializer name (CSV log key)."""
        ...

    def supports(self, test_data_name: str) -> bool:
        """
        Return False if this serializer is known to fail on a given test data type.
        Default is True (optimistic).
        """
        return True

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        """
        Prepare reusable serializer state for one benchmark data type.

        Implementations pre-build schemas/codecs/buffers here (outside timing).
        The default is a no-op.
        """
        self._test_data_name = test_data_name
        self._test_data_type = test_data_type

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        """
        Convert the shared benchmark fixture into a serializer-native object.

        The default is identity. Serializers that need dicts, Structs, Messages,
        or framework models must override this so conversion is untimed.
        """
        return obj

    @abstractmethod
    def serialize_bytes(self, obj: Any) -> bytes:
        """Serialize a *native* ``obj`` to ``bytes`` (timed; no conversion)."""
        ...

    @abstractmethod
    def deserialize_bytes(self, data: bytes) -> Any:
        """Deserialize ``bytes`` to a library-native Python object (timed)."""
        ...

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        """
        Serialize a *native* ``obj`` into a file-like ``io.BytesIO``.

        Default (adapted): ``stream.write(serialize_bytes(obj))``.
        """
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        """
        Deserialize from a file-like ``io.BytesIO`` to a library-native object.

        Default (adapted): read all bytes, then ``deserialize_bytes``.
        """
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
