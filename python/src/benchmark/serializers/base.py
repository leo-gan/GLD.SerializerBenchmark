"""
Base serializer interface, analogous to C#'s ISerDeser.

Every serializer wrapper implements both `bytes` and `stream` modes.
For libraries without native stream APIs, the wrapper adapts via io.BytesIO.
"""

from __future__ import annotations

import io
from abc import ABC, abstractmethod
from typing import Any, Optional


class Serializer(ABC):
    """Abstract base for all serializer benchmarks."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable serializer name."""
        ...

    def supports(self, test_data_name: str) -> bool:
        """
        Return False if this serializer is known to fail on a given test data type.
        Default is True (optimistic).
        """
        return True

    @abstractmethod
    def serialize_bytes(self, obj: Any) -> bytes:
        """Serialize `obj` to a `bytes` object."""
        ...

    @abstractmethod
    def deserialize_bytes(self, data: bytes) -> Any:
        """Deserialize `bytes` back to a Python object."""
        ...

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        """
        Serialize `obj` into a file-like `io.BytesIO` object.

        Default implementation: delegates to `serialize_bytes` and writes the result.
        Serializers with native stream APIs should override this.
        """
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        """
        Deserialize from a file-like `io.BytesIO` object.

        Default implementation: reads all bytes and delegates to `deserialize_bytes`.
        Serializers with native stream APIs should override this.
        """
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
