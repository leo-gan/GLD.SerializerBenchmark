"""
Avro benchmark wrapper.

Uses `fastavro` for high-performance Avro encoding/decoding.
Data is converted between canonical Python dataclasses and dicts,
then serialized via schemaless Avro writer/reader.
"""

from __future__ import annotations

import calendar
import datetime
import io
import json
import os
from typing import Any, Dict, Optional, Type

import fastavro

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


_SCHEMA_DIR = os.path.join(os.path.dirname(__file__), "..", "schemas", "avro")


def _load_schema(name: str) -> Dict[str, Any]:
    path = os.path.join(_SCHEMA_DIR, f"{name}.avsc")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


_SCHEMAS = {
    "Person": _load_schema("person"),
    "SimpleObject": _load_schema("simple_object"),
    "StringArray": _load_schema("string_array"),
    "Telemetry": _load_schema("telemetry"),
    "EDI_835": _load_schema("edi835"),
}

_PARSERS = {k: fastavro.parse_schema(v) for k, v in _SCHEMAS.items()}


class AvroSerializer(Serializer):
    @property
    def name(self) -> str:
        return "avro"

    def supports(self, test_data_name: str) -> bool:
        # Avro does not support circular references or bare primitives
        return test_data_name not in ("ObjectGraph", "Integer") and test_data_name in _PARSERS

    def serialize_bytes(self, obj: Any) -> bytes:
        td_name = _test_data_name_for(obj)
        schema = _PARSERS[td_name]
        record = _to_avro(obj)
        buf = io.BytesIO()
        fastavro.schemaless_writer(buf, schema, record)
        return buf.getvalue()

    def deserialize_bytes(self, data: bytes) -> Any:
        # Type inference via _last_type hint (see ProtobufSerializer for rationale)
        cls = getattr(self, "_last_type", None)
        if cls is None:
            raise RuntimeError("_last_type must be set before deserialization")
        td_name = _test_data_name_for_type(cls)
        schema = _PARSERS[td_name]
        buf = io.BytesIO(data)
        record = fastavro.schemaless_reader(buf, schema)
        return _from_avro(record, cls)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        td_name = _test_data_name_for(obj)
        schema = _PARSERS[td_name]
        record = _to_avro(obj)
        fastavro.schemaless_writer(stream, schema, record)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


# ---------------------------------------------------------------------------
# Type helpers
# ---------------------------------------------------------------------------

_TYPE_NAMES: Dict[Type[Any], str] = {
    Person: "Person",
    SimpleObject: "SimpleObject",
    StringArrayObject: "StringArray",
    TelemetryData: "Telemetry",
    EDI835: "EDI_835",
}


def _test_data_name_for(obj: Any) -> str:
    cls = type(obj)
    name = _TYPE_NAMES.get(cls)
    if name is None:
        raise TypeError(f"No Avro schema for type {cls}")
    return name


def _test_data_name_for_type(cls: Type[Any]) -> str:
    name = _TYPE_NAMES.get(cls)
    if name is None:
        raise TypeError(f"No Avro schema for type {cls}")
    return name


# ---------------------------------------------------------------------------
# Conversion helpers
# ---------------------------------------------------------------------------

def _to_avro(obj: Any) -> Any:
    """Convert a dataclass instance to an Avro-compatible dict."""
    if isinstance(obj, Person):
        return {
            "FirstName": obj.FirstName,
            "LastName": obj.LastName,
            "Age": obj.Age,
            "Gender": obj.Gender.name,
            "Passport": _to_avro(obj.Passport) if obj.Passport else None,
            "PoliceRecords": [_to_avro(r) for r in obj.PoliceRecords],
        }

    if isinstance(obj, Passport):
        return {
            "Number": obj.Number,
            "Authority": obj.Authority,
            "ExpirationDate": _dt_to_ms(obj.ExpirationDate),
        }

    if isinstance(obj, PoliceRecord):
        return {
            "Id": obj.Id,
            "CrimeCode": obj.CrimeCode,
        }

    if isinstance(obj, SimpleObject):
        return {
            "Id": obj.Id,
            "Name": obj.Name,
            "Timestamp": _dt_to_ms(obj.Timestamp),
            "IsActive": obj.IsActive,
        }

    if isinstance(obj, StringArrayObject):
        return {
            "Items": obj.Items,
        }

    if isinstance(obj, TelemetryData):
        return {
            "Id": obj.Id,
            "DataSource": obj.DataSource,
            "TimeStamp": _dt_to_ms(obj.TimeStamp),
            "Param1": obj.Param1,
            "Param2": obj.Param2,
            "Measurements": obj.Measurements,
            "AssociatedProblemID": obj.AssociatedProblemID,
            "AssociatedLogID": obj.AssociatedLogID,
            "WasProcessed": obj.WasProcessed,
        }

    if isinstance(obj, ServiceLine):
        return {
            "ServiceCode": obj.ServiceCode,
            "ChargeAmount": obj.ChargeAmount,
            "AdjudicatedAmount": obj.AdjudicatedAmount,
        }

    if isinstance(obj, Claim):
        return {
            "ClaimId": obj.ClaimId,
            "PatientName": obj.PatientName,
            "TotalCharge": obj.TotalCharge,
            "PaymentAmount": obj.PaymentAmount,
            "Lines": [_to_avro(l) for l in obj.Lines],
        }

    if isinstance(obj, EDI835):
        return {
            "PayerName": obj.PayerName,
            "PayeeName": obj.PayeeName,
            "PaymentDate": _dt_to_ms(obj.PaymentDate),
            "TotalActualAmount": obj.TotalActualAmount,
            "TransactionControlNumber": obj.TransactionControlNumber,
            "Claims": [_to_avro(c) for c in obj.Claims],
        }

    if isinstance(obj, int):
        return obj

    raise TypeError(f"Unsupported type for Avro conversion: {type(obj)}")


def _from_avro(record: Any, cls: Type[Any]) -> Any:
    """Convert an Avro dict back to a dataclass instance."""
    if cls is Person:
        return Person(
            FirstName=record["FirstName"],
            LastName=record["LastName"],
            Age=record["Age"],
            Gender=Gender[record["Gender"]],
            Passport=_from_avro(record["Passport"], Passport) if record.get("Passport") else None,
            PoliceRecords=[_from_avro(r, PoliceRecord) for r in record["PoliceRecords"]],
        )

    if cls is Passport:
        return Passport(
            Number=record["Number"],
            Authority=record["Authority"],
            ExpirationDate=_ms_to_dt(record["ExpirationDate"]),
        )

    if cls is PoliceRecord:
        return PoliceRecord(
            Id=record["Id"],
            CrimeCode=record["CrimeCode"],
        )

    if cls is SimpleObject:
        return SimpleObject(
            Id=record["Id"],
            Name=record["Name"],
            Timestamp=_ms_to_dt(record["Timestamp"]),
            IsActive=record["IsActive"],
        )

    if cls is StringArrayObject:
        return StringArrayObject(
            Items=list(record["Items"]),
        )

    if cls is TelemetryData:
        return TelemetryData(
            Id=record["Id"],
            DataSource=record["DataSource"],
            TimeStamp=_ms_to_dt(record["TimeStamp"]),
            Param1=record["Param1"],
            Param2=record["Param2"],
            Measurements=list(record["Measurements"]),
            AssociatedProblemID=record["AssociatedProblemID"],
            AssociatedLogID=record["AssociatedLogID"],
            WasProcessed=record["WasProcessed"],
        )

    if cls is ServiceLine:
        return ServiceLine(
            ServiceCode=record["ServiceCode"],
            ChargeAmount=record["ChargeAmount"],
            AdjudicatedAmount=record["AdjudicatedAmount"],
        )

    if cls is Claim:
        return Claim(
            ClaimId=record["ClaimId"],
            PatientName=record["PatientName"],
            TotalCharge=record["TotalCharge"],
            PaymentAmount=record["PaymentAmount"],
            Lines=[_from_avro(l, ServiceLine) for l in record["Lines"]],
        )

    if cls is EDI835:
        return EDI835(
            PayerName=record["PayerName"],
            PayeeName=record["PayeeName"],
            PaymentDate=_ms_to_dt(record["PaymentDate"]),
            TotalActualAmount=record["TotalActualAmount"],
            TransactionControlNumber=record["TransactionControlNumber"],
            Claims=[_from_avro(c, Claim) for c in record["Claims"]],
        )

    if cls is int:
        return record

    raise TypeError(f"Unsupported type for Avro reconstruction: {cls}")
