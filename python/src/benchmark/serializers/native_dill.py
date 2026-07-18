"""
dill benchmark wrapper — extended pickle used heavily in scientific Python.

Why dill serialize looks "slow" in this suite
--------------------------------------------
On ordinary importable dataclasses, ``dill.dumps`` emits a payload similar in
*size* to ``pickle.dumps`` (same protocol family) but walks a much heavier
pure-Python dispatch path (module-dict traversal, type location, recursive
``save`` wrappers). Profiling on message shows ~15–20× more CPU in
``dill._dill.save`` / ``save_module_dict`` than C ``pickle`` for the same
object — with **no** equivalent flags (``byref``, ``recurse``) closing the gap.

That cost is the price of dill's ability to pickle dynamic callables, lambdas,
and interactive-session objects. It is **not** a missing ``prepare_data``
optimization: the timed input is already the native dataclass.

Deserialize is comparatively cheap (close to pickle) once the stream is built.
"""

from __future__ import annotations

import io
from typing import Any

import dill

from .base import Serializer


class DillSerializer(Serializer):
    native_kind = "dataclass"
    stream_mode = "native"

    @property
    def name(self) -> str:
        return "dill"

    def supports(self, test_data_name: str) -> bool:
        return True

    def serialize_bytes(self, obj: Any) -> bytes:
        # HIGHEST_PROTOCOL; byref/recurse do not materially speed simple dataclasses.
        return dill.dumps(obj, protocol=dill.HIGHEST_PROTOCOL)

    def deserialize_bytes(self, data: bytes) -> Any:
        return dill.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        dill.dump(obj, stream, protocol=dill.HIGHEST_PROTOCOL)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return dill.load(stream)
