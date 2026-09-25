"""Dagr — suite Data Model v2 over the generated pure-Python typed API.

Schema: ``schemas/v2/dagr/schema.py`` (one DataGraph per suite type, all nodes
``packed``, Telemetry ``values`` marked ``raw``). ``dagr build`` emits the Python
target into ``python/generated/dagr/``: one typed module per graph
(``message_graph.py`` …) plus a self-contained copy of the ``dagr`` runtime
package and ``dagr_schema.py``.

Call path (mirrors ``schema_protobuf``):

* ``prepare_data`` (untimed): suite dataclass → generated ``@dataclass`` node
  (every field set).
* ``serialize_bytes`` (timed): ``<graph>.to_bytes(root)``.
* ``deserialize_bytes`` (timed): ``<graph>.restore(data)`` → generated dataclass
  (the library-native message; field names match the suite model, so fidelity
  compares it directly).

The Python target is the reflective runtime (spec 29, Fork A): eager only, no
lazy reader, no reusable writer. N>1 cells use the same frame as the Rust
``dagr`` row: ``u32 count`` then ``u32 len + payload`` per instance.
"""

from __future__ import annotations

import importlib
import json
import os
import struct
import sys
from functools import lru_cache
from typing import Any

from .base import Serializer
from ..data_v2 import models as m

_PY_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
# The generated modules import ``dagr_schema`` and ``dagr.runtime`` as top-level
# names, so their output dir (not ``python/generated``) must be on sys.path.
_GEN_DIR = os.path.join(_PY_ROOT, "generated", "dagr")
_LOCK = os.path.join(_PY_ROOT, "..", "schemas", "v2", "dagr", "dagr.lock.json")

_MODULES = {
    "message": "message_graph",
    "document": "document_graph",
    "telemetry": "telemetry_graph",
    "strings": "strings_graph",
    "event": "event_graph",
}

_U32 = struct.Struct("<I")


@lru_cache(maxsize=None)
def _module(type_id: str) -> Any:
    """Import one generated graph module (and the shipped ``dagr`` runtime)."""
    if _GEN_DIR not in sys.path:
        sys.path.insert(0, _GEN_DIR)
    # ``python/generated`` is also on sys.path (protobuf bridge), where
    # ``generated/dagr`` is a directory without ``__init__.py``. A regular package
    # wins over namespace portions, but refuse loudly if some other ``dagr``
    # (e.g. an installed dagr-cli of a different version) got imported first.
    dagr = importlib.import_module("dagr")
    origin = os.path.abspath(getattr(dagr, "__file__", "") or "")
    if not origin.startswith(os.path.join(_GEN_DIR, "dagr") + os.sep):
        raise ImportError(
            f"'dagr' resolved to {origin or dagr!r}, not the generated runtime under {_GEN_DIR}"
        )
    return importlib.import_module(_MODULES[type_id])


@lru_cache(maxsize=1)
def _generator_version() -> str:
    """Generator version from the committed ``dagr build`` receipt (``dagr 2026.9.0``)."""
    try:
        with open(_LOCK, encoding="utf-8") as f:
            tool = json.load(f).get("provenance", {}).get("tool_version", "")
    except (OSError, ValueError):
        return ""
    return tool.split()[-1] if tool else ""


# ── suite dataclass → generated typed node (untimed) ─────────────────────────

def _to_message(g: Any, o: m.Message) -> Any:
    return g.Message(
        f_bool=o.f_bool, f_int32=o.f_int32, f_int64=o.f_int64, f_float64=o.f_float64,
        f_string=o.f_string, f_bool_2=o.f_bool_2, f_int32_2=o.f_int32_2,
        f_string_2=o.f_string_2,
    )


def _to_document(g: Any, o: m.Document) -> Any:
    return g.Document(
        id=o.id,
        status=o.status,
        meta=g.DocumentMeta(region=o.meta.region, version=o.meta.version),
        items=[g.DocumentItem(sku=i.sku, qty=i.qty, price_minor=i.price_minor) for i in o.items],
    )


def _to_telemetry(g: Any, o: m.Telemetry) -> Any:
    return g.Telemetry(source=o.source, ts=o.ts, tags=list(o.tags), values=list(o.values))


def _to_strings(g: Any, o: m.Strings) -> Any:
    return g.Strings(items=list(o.items))


def _to_event(g: Any, o: m.Event) -> Any:
    return g.Event(
        event_id=o.event_id, event_type=o.event_type, occurred_at=o.occurred_at,
        producer=o.producer,
        attrs=[g.EventAttr(key=a.key, value=a.value) for a in o.attrs],
    )


_CONVERT = {
    "message": _to_message,
    "document": _to_document,
    "telemetry": _to_telemetry,
    "strings": _to_strings,
    "event": _to_event,
}


class DagrSerializer(Serializer):
    native_kind = "message"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._type_id = "message"
        self._to_bytes = None
        self._restore = None
        self._batch = False

    @property
    def name(self) -> str:
        return "dagr"

    @property
    def version(self) -> str:
        return _generator_version()

    def supports(self, test_data_name: str) -> bool:
        if test_data_name not in _MODULES:
            return False
        try:
            _module(test_data_name)
        except ImportError:
            return False
        return True

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        g = _module(test_data_name)
        self._type_id = test_data_name
        # Bind the per-graph codec once; the timed path does no lookups.
        self._to_bytes = g.to_bytes
        self._restore = g.restore

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        if self._to_bytes is None or self._type_id != test_data_name:
            self.prepare(test_data_name, test_data_type)
        g = _module(test_data_name)
        conv = _CONVERT[test_data_name]
        self._batch = isinstance(obj, list)
        if self._batch:
            return [conv(g, x) for x in obj]
        return conv(g, obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        to_bytes = self._to_bytes
        if not self._batch:
            return to_bytes(obj)
        pack = _U32.pack
        out = bytearray(pack(len(obj)))
        for x in obj:
            b = to_bytes(x)
            out += pack(len(b))
            out += b
        return bytes(out)

    def deserialize_bytes(self, data: bytes) -> Any:
        restore = self._restore
        if not self._batch:
            return restore(data)
        mv = memoryview(data)
        unpack = _U32.unpack_from
        n = unpack(data, 0)[0]
        o = 4
        items = []
        for _ in range(n):
            ln = unpack(data, o)[0]
            o += 4
            items.append(restore(mv[o:o + ln]))
            o += ln
        return items
