"""
Base serializer interface, analogous to C#'s ISerDeser.

Every serializer wrapper implements both `bytes` and `stream` modes.
For libraries without native stream APIs, the wrapper adapts via io.BytesIO.
"""

from __future__ import annotations

import io
from abc import ABC, abstractmethod
from typing import Any


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

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        """
        Prepare reusable serializer state for one benchmark data type.

        Implementations can use this to pre-build schemas/codecs outside the
        timed loop. The default is a no-op.
        """
        return None

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        """
        Convert the shared benchmark fixture into a serializer-native object.

        The default is identity. Serializers with their own recommended model
        types can override this to avoid measuring conversion inside the timed loop.
        """
        return obj

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
