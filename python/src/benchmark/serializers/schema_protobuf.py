"""
Protobuf benchmark wrapper.

Uses the pre-generated `benchmark_data_pb2` module. Data is converted between
canonical Python dataclasses and Protobuf messages before/after serialization.
"""

from __future__ import annotations

import calendar
import datetime
import io
import os
from typing import Any, Dict, List, Optional, Type

from .base import Serializer
from ..data.models import (
    Claim, EDI835, Gender, GraphNode, Passport, Person,
    PoliceRecord, ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
)


def _dt_to_ms(dt: datetime.datetime) -> int:
    """Convert a naive (assumed UTC) datetime to milliseconds since epoch."""
    return int(calendar.timegm(dt.utctimetuple()) * 1000 + dt.microsecond // 1000)


def _ms_to_dt(ms: int) -> datetime.datetime:
    """Convert milliseconds since epoch to a naive UTC datetime."""
    return datetime.datetime.utcfromtimestamp(ms / 1000.0)

# The generated module path depends on build-time compilation.
# We attempt two locations: the legacy `generated` package and a local fallback.
try:
    from generated import benchmark_data_pb2 as pb2
except ImportError:
    import sys
    _generated_dir = os.path.join(os.path.dirname(__file__), "..", "..", "..", "generated")
    if _generated_dir not in sys.path:
        sys.path.insert(0, _generated_dir)
    from generated import benchmark_data_pb2 as pb2  # type: ignore[no-redef]


class ProtobufSerializer(Serializer):
    @property
    def name(self) -> str:
        return "protobuf"

    def supports(self, test_data_name: str) -> bool:
        # Protobuf does not natively support circular references or bare primitives
        return test_data_name not in ("ObjectGraph", "Integer")

    def serialize_bytes(self, obj: Any) -> bytes:
        msg = _to_protobuf(obj)
        return msg.SerializeToString()

    def deserialize_bytes(self, data: bytes) -> Any:
        # We need to know the type; the runner passes the original object,
        # but here we only have bytes. We delegate type inference to the
        # caller via _deserialize_with_type helper.
        # To keep the interface simple, we assume the caller has set
        # _last_type hint. This is a pragmatic concession to the benchmark design.
        cls = getattr(self, "_last_type", None)
        if cls is None:
            raise RuntimeError("_last_type must be set before deserialization")
        msg = _protobuf_class_for(cls)()
        msg.ParseFromString(data)
        return _from_protobuf(msg, cls)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


# ---------------------------------------------------------------------------
# Type mapping
# ---------------------------------------------------------------------------

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


def _protobuf_class_for(cls: Type[Any]) -> Type[Any]:
    return _TYPE_MAP.get(cls, pb2.SimpleObject)


def _to_protobuf(obj: Any) -> Any:
    """Recursively convert a Python dataclass to a protobuf message."""
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

    if isinstance(obj, int):
        # Primitive fallback
        return obj

    raise TypeError(f"Unsupported type for protobuf conversion: {type(obj)}")


def _from_protobuf(msg: Any, cls: Type[Any]) -> Any:
    """Recursively convert a protobuf message back to a Python dataclass."""
    if cls is Person:
        return Person(
            FirstName=msg.FirstName,
            LastName=msg.LastName,
            Age=msg.Age,
            Gender=Gender.Male if msg.Gender == pb2.Gender.MALE else Gender.Female,
            Passport=_from_protobuf(msg.Passport, Passport) if msg.HasField("Passport") else None,
            PoliceRecords=[_from_protobuf(r, PoliceRecord) for r in msg.PoliceRecords],
        )

    if cls is Passport:
        return Passport(
            Number=msg.Number,
            Authority=msg.Authority,
            ExpirationDate=_ms_to_dt(msg.ExpirationDate),
        )

    if cls is PoliceRecord:
        return PoliceRecord(
            Id=msg.Id,
            CrimeCode=msg.CrimeCode,
        )

    if cls is SimpleObject:
        return SimpleObject(
            Id=msg.Id,
            Name=msg.Name,
            Timestamp=_ms_to_dt(msg.Timestamp),
            IsActive=msg.IsActive,
        )

    if cls is StringArrayObject:
        return StringArrayObject(
            Items=list(msg.Items),
        )

    if cls is TelemetryData:
        return TelemetryData(
            Id=msg.Id,
            DataSource=msg.DataSource,
            TimeStamp=_ms_to_dt(msg.TimeStamp),
            Param1=msg.Param1,
            Param2=msg.Param2,
            Measurements=list(msg.Measurements),
            AssociatedProblemID=msg.AssociatedProblemID,
            AssociatedLogID=msg.AssociatedLogID,
            WasProcessed=msg.WasProcessed,
        )

    if cls is ServiceLine:
        return ServiceLine(
            ServiceCode=msg.ServiceCode,
            ChargeAmount=msg.ChargeAmount,
            AdjudicatedAmount=msg.AdjudicatedAmount,
        )

    if cls is Claim:
        return Claim(
            ClaimId=msg.ClaimId,
            PatientName=msg.PatientName,
            TotalCharge=msg.TotalCharge,
            PaymentAmount=msg.PaymentAmount,
            Lines=[_from_protobuf(l, ServiceLine) for l in msg.Lines],
        )

    if cls is EDI835:
        return EDI835(
            PayerName=msg.PayerName,
            PayeeName=msg.PayeeName,
            PaymentDate=_ms_to_dt(msg.PaymentDate),
            TotalActualAmount=msg.TotalActualAmount,
            TransactionControlNumber=msg.TransactionControlNumber,
            Claims=[_from_protobuf(c, Claim) for c in msg.Claims],
        )

    if cls is int:
        return msg

    raise TypeError(f"Unsupported type for protobuf reconstruction: {cls}")
