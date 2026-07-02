"""
Avro (fastavro) benchmark wrapper.

Call-path: prepare_data converts dataclasses to Avro-compatible dict records
(untimed). Timed path only runs schemaless_writer / schemaless_reader.
"""

from __future__ import annotations

import calendar
import datetime
import io
import json
import os
from typing import Any, Dict, Type

import fastavro

from .base import Serializer
from ..data.models import (
    Claim, EDI835, Gender, Passport, Person,
    PoliceRecord, ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
)


def _dt_to_ms(dt: datetime.datetime) -> int:
    return int(calendar.timegm(dt.utctimetuple()) * 1000 + dt.microsecond // 1000)


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

_TYPE_NAMES: Dict[Type[Any], str] = {
    Person: "Person",
    SimpleObject: "SimpleObject",
    StringArrayObject: "StringArray",
    TelemetryData: "Telemetry",
    EDI835: "EDI_835",
}


class AvroSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "native"  # schemaless_writer writes directly to the stream

    def __init__(self) -> None:
        super().__init__()
        self._schema: Any = None
        self._td_name: str | None = None
        self._ser_buf = io.BytesIO()

    @property
    def name(self) -> str:
        return "avro"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name not in ("ObjectGraph", "Integer") and test_data_name in _PARSERS

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._td_name = test_data_name
        self._schema = _PARSERS[test_data_name]
        self._ser_buf = io.BytesIO()

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return _to_avro(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        buf = self._ser_buf
        buf.seek(0)
        buf.truncate(0)
        fastavro.schemaless_writer(buf, self._schema, obj)
        return buf.getvalue()

    def deserialize_bytes(self, data: bytes) -> Any:
        return fastavro.schemaless_reader(io.BytesIO(data), self._schema)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        fastavro.schemaless_writer(stream, self._schema, obj)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return fastavro.schemaless_reader(stream, self._schema)


def _to_avro(obj: Any) -> Any:
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
        return {"Id": obj.Id, "CrimeCode": obj.CrimeCode}

    if isinstance(obj, SimpleObject):
        return {
            "Id": obj.Id,
            "Name": obj.Name,
            "Timestamp": _dt_to_ms(obj.Timestamp),
            "IsActive": obj.IsActive,
        }

    if isinstance(obj, StringArrayObject):
        return {"Items": obj.Items}

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

    raise TypeError(f"Unsupported type for Avro conversion: {type(obj)}")
