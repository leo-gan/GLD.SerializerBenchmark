"""Fory's native, registered dataclass path; setup is outside measurement."""

from pyfory import Fory

from ..data_v2.models import (
    Document, DocumentItem, DocumentMeta, Event, EventAttr, Message, Strings, Telemetry,
)
from .base import Serializer


class ForySerializer(Serializer):
    native_kind = "dataclass"
    package_name = "pyfory"

    def __init__(self):
        self._fory = Fory(xlang=False, ref=False)
        for type_id, cls in enumerate((
            Message, DocumentMeta, DocumentItem, Document, Telemetry, Strings, EventAttr, Event,
        ), 1):
            self._fory.register_type(cls, type_id=type_id)

    @property
    def name(self):
        return "fory"

    def serialize_bytes(self, obj):
        return self._fory.serialize(obj)

    def deserialize_bytes(self, data):
        return self._fory.deserialize(data)
