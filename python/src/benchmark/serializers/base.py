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
import sys
from abc import ABC, abstractmethod
from functools import lru_cache
from typing import Any, Literal, Optional

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


@lru_cache(maxsize=64)
def installed_package_version(distribution_name: str) -> str:
    """Return the installed distribution version (importlib.metadata), or \"\"."""
    if not distribution_name:
        return ""
    try:
        from importlib.metadata import PackageNotFoundError, version

        return version(distribution_name)
    except PackageNotFoundError:
        return ""
    except Exception:
        return ""


class Serializer(ABC):
    """Abstract base for all serializer benchmarks."""

    #: Documented input kind after ``prepare_data`` (for analysis/docs).
    native_kind: NativeKind = "dataclass"

    #: Whether stream methods use a real stream API or adapt from bytes.
    stream_mode: StreamMode = "adapted"

    #: PyPI / importlib distribution name for version reporting (CSV SerializerVersion).
    #: Override when the log ``name`` differs from the install name (e.g. rapidjson).
    package_name: Optional[str] = None

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable serializer name (CSV log key)."""
        ...

    @property
    def version(self) -> str:
        """Installed library version written to CSV after SerializerName."""
        dist = self.package_name if self.package_name is not None else self.name
        if dist in ("json", "stdlib-json", "pickle"):
            return f"python-{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        return installed_package_version(dist)

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
