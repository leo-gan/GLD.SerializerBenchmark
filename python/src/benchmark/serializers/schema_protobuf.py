"""
Protobuf benchmark wrapper.

Call-path: prepare_data converts canonical dataclasses to protobuf Messages
(untimed). Timed path only runs SerializeToString / ParseFromString.
Deserialize returns the Message so materialization is not timed; the semantic
comparer understands protobuf attribute / HasField semantics.
"""

from __future__ import annotations

import calendar
import datetime
import io
import os
from typing import Any, Dict, Type

from .base import Serializer
from ..data.models import (
    Claim, EDI835, Gender, Passport, Person,
    PoliceRecord, ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
)


def _dt_to_ms(dt: datetime.datetime) -> int:
    return int(calendar.timegm(dt.utctimetuple()) * 1000 + dt.microsecond // 1000)


try:
    from generated import benchmark_data_pb2 as pb2
except ImportError:
    import sys
    _generated_dir = os.path.join(os.path.dirname(__file__), "..", "..", "..", "generated")
    if _generated_dir not in sys.path:
        sys.path.insert(0, _generated_dir)
    from generated import benchmark_data_pb2 as pb2  # type: ignore[no-redef]


_TYPE_MAP: Dict[Type[Any], Type[Any]] = {
    Person: pb2.Person,
    SimpleObject: pb2.SimpleObject,
    StringArrayObject: pb2.StringArrayObject,
    TelemetryData: pb2.TelemetryData,
    EDI835: pb2.EDI835,
    Claim: pb2.Claim,
    ServiceLine: pb2.ServiceLine,
    Passport: pb2.Passport,
    PoliceRecord: pb2.PoliceRecord,
}


class ProtobufSerializer(Serializer):
    package_name = "protobuf"
    native_kind = "message"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._msg_cls: Type[Any] | None = None

    @property
    def name(self) -> str:
        return "protobuf"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name not in ("ObjectGraph", "Integer")

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._msg_cls = _TYPE_MAP.get(test_data_type)
        if self._msg_cls is None and test_data_type is not int:
            raise TypeError(f"No protobuf mapping for {test_data_type}")

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return _to_protobuf(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        # obj is a protobuf Message
        return obj.SerializeToString()

    def deserialize_bytes(self, data: bytes) -> Any:
        if self._msg_cls is None:
            raise RuntimeError("prepare() must be called before deserialize")
        msg = self._msg_cls()
        msg.ParseFromString(data)
        return msg

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


def _to_protobuf(obj: Any) -> Any:
    """Recursively convert a Python dataclass to a protobuf message (untimed)."""
    if isinstance(obj, Person):
        p = pb2.Person()
        p.FirstName = obj.FirstName
        p.LastName = obj.LastName
        p.Age = obj.Age
        p.Gender = pb2.Gender.MALE if obj.Gender == Gender.Male else pb2.Gender.FEMALE
        if obj.Passport:
            p.Passport.CopyFrom(_to_protobuf(obj.Passport))
        for rec in obj.PoliceRecords:
            pr = p.PoliceRecords.add()
            pr.CopyFrom(_to_protobuf(rec))
        return p

    if isinstance(obj, Passport):
        p = pb2.Passport()
        p.Number = obj.Number
        p.Authority = obj.Authority
        p.ExpirationDate = _dt_to_ms(obj.ExpirationDate)
        return p

    if isinstance(obj, PoliceRecord):
        p = pb2.PoliceRecord()
        p.Id = obj.Id
        p.CrimeCode = obj.CrimeCode
        return p

    if isinstance(obj, SimpleObject):
        p = pb2.SimpleObject()
        p.Id = obj.Id
        p.Name = obj.Name
        p.Timestamp = _dt_to_ms(obj.Timestamp)
        p.IsActive = obj.IsActive
        return p

    if isinstance(obj, StringArrayObject):
        p = pb2.StringArrayObject()
        p.Items.extend(obj.Items)
        return p

    if isinstance(obj, TelemetryData):
        p = pb2.TelemetryData()
        p.Id = obj.Id
        p.DataSource = obj.DataSource
        p.TimeStamp = _dt_to_ms(obj.TimeStamp)
        p.Param1 = obj.Param1
        p.Param2 = obj.Param2
        p.Measurements.extend(obj.Measurements)
        p.AssociatedProblemID = obj.AssociatedProblemID
        p.AssociatedLogID = obj.AssociatedLogID
        p.WasProcessed = obj.WasProcessed
        return p

    if isinstance(obj, ServiceLine):
        p = pb2.ServiceLine()
        p.ServiceCode = obj.ServiceCode
        p.ChargeAmount = obj.ChargeAmount
        p.AdjudicatedAmount = obj.AdjudicatedAmount
        return p

    if isinstance(obj, Claim):
        p = pb2.Claim()
        p.ClaimId = obj.ClaimId
        p.PatientName = obj.PatientName
        p.TotalCharge = obj.TotalCharge
        p.PaymentAmount = obj.PaymentAmount
        for line in obj.Lines:
            l = p.Lines.add()
            l.CopyFrom(_to_protobuf(line))
        return p

    if isinstance(obj, EDI835):
        p = pb2.EDI835()
        p.PayerName = obj.PayerName
        p.PayeeName = obj.PayeeName
        p.PaymentDate = _dt_to_ms(obj.PaymentDate)
        p.TotalActualAmount = obj.TotalActualAmount
        p.TransactionControlNumber = obj.TransactionControlNumber
        for claim in obj.Claims:
            c = p.Claims.add()
            c.CopyFrom(_to_protobuf(claim))
        return p

    raise TypeError(f"Unsupported type for protobuf conversion: {type(obj)}")
