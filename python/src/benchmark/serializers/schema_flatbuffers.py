"""
FlatBuffers benchmark wrapper (flatc-generated tables under generated/flatbuffers_gen).

FlatBuffers has no pre-built Python message object like protobuf: the timed
serialize path *is* the Builder construction + Finish. prepare() selects the
root type and reuses a Builder buffer. Deserialize uses GetRootAs and projects
fields into a dict (PascalCase keys) so the semantic comparer can validate
without treating method objects as values.

Schema: src/benchmark/schemas/flatbuffers/benchmark.fbs
Regenerate:
  flatc --python -o generated/flatbuffers_gen src/benchmark/schemas/flatbuffers/benchmark.fbs
"""

from __future__ import annotations

import calendar
import datetime
import io
import sys
from pathlib import Path
from typing import Any, Callable, Dict, Type

import flatbuffers

from .base import Serializer
from ..data.models import (
    Claim,
    EDI835,
    Gender,
    Passport,
    Person,
    PoliceRecord,
    ServiceLine,
    SimpleObject,
    StringArrayObject,
    TelemetryData,
)

_GEN = Path(__file__).resolve().parents[3] / "generated" / "flatbuffers_gen"
if str(_GEN) not in sys.path:
    sys.path.insert(0, str(_GEN))

import BenchmarkFB.Claim as FBClaim  # noqa: E402
import BenchmarkFB.EDI835 as FBEDI835  # noqa: E402
import BenchmarkFB.Gender as FBGender  # noqa: E402
import BenchmarkFB.Passport as FBPassport  # noqa: E402
import BenchmarkFB.Person as FBPerson  # noqa: E402
import BenchmarkFB.PoliceRecord as FBPoliceRecord  # noqa: E402
import BenchmarkFB.ServiceLine as FBServiceLine  # noqa: E402
import BenchmarkFB.SimpleObject as FBSimpleObject  # noqa: E402
import BenchmarkFB.StringArrayObject as FBStringArrayObject  # noqa: E402
import BenchmarkFB.TelemetryData as FBTelemetryData  # noqa: E402


def _dt_to_ms(dt: datetime.datetime) -> int:
    return int(calendar.timegm(dt.utctimetuple()) * 1000 + dt.microsecond // 1000)


def _ms_to_dt(ms: int) -> datetime.datetime:
    return datetime.datetime.utcfromtimestamp(ms / 1000.0)


class FlatBuffersSerializer(Serializer):
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._builder = flatbuffers.Builder(1024)
        self._encode: Callable[[Any], bytes] | None = None
        self._decode: Callable[[bytes], Any] | None = None

    @property
    def name(self) -> str:
        return "flatbuffers"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name not in ("ObjectGraph", "Integer")

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._builder = flatbuffers.Builder(1024)
        encoders = {
            Person: (_encode_person, _decode_person),
            SimpleObject: (_encode_simple, _decode_simple),
            StringArrayObject: (_encode_string_array, _decode_string_array),
            TelemetryData: (_encode_telemetry, _decode_telemetry),
            EDI835: (_encode_edi835, _decode_edi835),
        }
        pair = encoders.get(test_data_type)
        if pair is None:
            raise TypeError(f"No FlatBuffers mapping for {test_data_type}")
        self._encode, self._decode = pair

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        # FlatBuffers build starts from the canonical dataclass (no Message type).
        return obj

    def serialize_bytes(self, obj: Any) -> bytes:
        assert self._encode is not None
        return self._encode(self._builder, obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        assert self._decode is not None
        return self._decode(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


# ---------------------------------------------------------------------------
# Encoders (builder helpers)
# ---------------------------------------------------------------------------


def _reset(builder: flatbuffers.Builder) -> None:
    builder.Clear()


def _encode_passport(builder: flatbuffers.Builder, obj: Passport) -> int:
    number = builder.CreateString(obj.Number)
    authority = builder.CreateString(obj.Authority)
    FBPassport.Start(builder)
    FBPassport.AddNumber(builder, number)
    FBPassport.AddAuthority(builder, authority)
    FBPassport.AddExpirationDate(builder, _dt_to_ms(obj.ExpirationDate))
    return FBPassport.End(builder)


def _encode_police(builder: flatbuffers.Builder, obj: PoliceRecord) -> int:
    code = builder.CreateString(obj.CrimeCode)
    FBPoliceRecord.Start(builder)
    FBPoliceRecord.AddId(builder, obj.Id)
    FBPoliceRecord.AddCrimeCode(builder, code)
    return FBPoliceRecord.End(builder)


def _encode_person(builder: flatbuffers.Builder, obj: Person) -> bytes:
    _reset(builder)
    first = builder.CreateString(obj.FirstName)
    last = builder.CreateString(obj.LastName)
    passport = _encode_passport(builder, obj.Passport) if obj.Passport else None
    rec_offs = [_encode_police(builder, r) for r in obj.PoliceRecords]
    if rec_offs:
        FBPerson.StartPoliceRecordsVector(builder, len(rec_offs))
        for off in reversed(rec_offs):
            builder.PrependUOffsetTRelative(off)
        records = builder.EndVector()
    else:
        records = None
    FBPerson.Start(builder)
    FBPerson.AddFirstName(builder, first)
    FBPerson.AddLastName(builder, last)
    FBPerson.AddAge(builder, obj.Age)
    FBPerson.AddGender(
        builder,
        FBGender.Gender.Male if obj.Gender == Gender.Male else FBGender.Gender.Female,
    )
    if passport is not None:
        FBPerson.AddPassport(builder, passport)
    if records is not None:
        FBPerson.AddPoliceRecords(builder, records)
    root = FBPerson.End(builder)
    builder.Finish(root)
    return bytes(builder.Output())


def _encode_simple(builder: flatbuffers.Builder, obj: SimpleObject) -> bytes:
    _reset(builder)
    name = builder.CreateString(obj.Name)
    FBSimpleObject.Start(builder)
    FBSimpleObject.AddId(builder, obj.Id)
    FBSimpleObject.AddName(builder, name)
    FBSimpleObject.AddTimestamp(builder, _dt_to_ms(obj.Timestamp))
    FBSimpleObject.AddIsActive(builder, obj.IsActive)
    root = FBSimpleObject.End(builder)
    builder.Finish(root)
    return bytes(builder.Output())


def _encode_string_array(builder: flatbuffers.Builder, obj: StringArrayObject) -> bytes:
    _reset(builder)
    item_offs = [builder.CreateString(s) for s in obj.Items]
    FBStringArrayObject.StartItemsVector(builder, len(item_offs))
    for off in reversed(item_offs):
        builder.PrependUOffsetTRelative(off)
    items = builder.EndVector()
    FBStringArrayObject.Start(builder)
    FBStringArrayObject.AddItems(builder, items)
    root = FBStringArrayObject.End(builder)
    builder.Finish(root)
    return bytes(builder.Output())


def _encode_telemetry(builder: flatbuffers.Builder, obj: TelemetryData) -> bytes:
    _reset(builder)
    id_s = builder.CreateString(obj.Id)
    src = builder.CreateString(obj.DataSource)
    FBTelemetryData.StartMeasurementsVector(builder, len(obj.Measurements))
    for v in reversed(obj.Measurements):
        builder.PrependFloat64(v)
    measurements = builder.EndVector()
    FBTelemetryData.Start(builder)
    FBTelemetryData.AddId(builder, id_s)
    FBTelemetryData.AddDataSource(builder, src)
    FBTelemetryData.AddTimeStamp(builder, _dt_to_ms(obj.TimeStamp))
    FBTelemetryData.AddParam1(builder, obj.Param1)
    FBTelemetryData.AddParam2(builder, obj.Param2)
    FBTelemetryData.AddMeasurements(builder, measurements)
    FBTelemetryData.AddAssociatedProblemId(builder, obj.AssociatedProblemID)
    FBTelemetryData.AddAssociatedLogId(builder, obj.AssociatedLogID)
    FBTelemetryData.AddWasProcessed(builder, obj.WasProcessed)
    root = FBTelemetryData.End(builder)
    builder.Finish(root)
    return bytes(builder.Output())


def _encode_service_line(builder: flatbuffers.Builder, obj: ServiceLine) -> int:
    code = builder.CreateString(obj.ServiceCode)
    FBServiceLine.Start(builder)
    FBServiceLine.AddServiceCode(builder, code)
    FBServiceLine.AddChargeAmount(builder, obj.ChargeAmount)
    FBServiceLine.AddAdjudicatedAmount(builder, obj.AdjudicatedAmount)
    return FBServiceLine.End(builder)


def _encode_claim(builder: flatbuffers.Builder, obj: Claim) -> int:
    cid = builder.CreateString(obj.ClaimId)
    patient = builder.CreateString(obj.PatientName)
    line_offs = [_encode_service_line(builder, line) for line in obj.Lines]
    if line_offs:
        FBClaim.StartLinesVector(builder, len(line_offs))
        for off in reversed(line_offs):
            builder.PrependUOffsetTRelative(off)
        lines = builder.EndVector()
    else:
        lines = None
    FBClaim.Start(builder)
    FBClaim.AddClaimId(builder, cid)
    FBClaim.AddPatientName(builder, patient)
    FBClaim.AddTotalCharge(builder, obj.TotalCharge)
    FBClaim.AddPaymentAmount(builder, obj.PaymentAmount)
    if lines is not None:
        FBClaim.AddLines(builder, lines)
    return FBClaim.End(builder)


def _encode_edi835(builder: flatbuffers.Builder, obj: EDI835) -> bytes:
    _reset(builder)
    payer = builder.CreateString(obj.PayerName)
    payee = builder.CreateString(obj.PayeeName)
    tcn = builder.CreateString(obj.TransactionControlNumber)
    claim_offs = [_encode_claim(builder, c) for c in obj.Claims]
    if claim_offs:
        FBEDI835.StartClaimsVector(builder, len(claim_offs))
        for off in reversed(claim_offs):
            builder.PrependUOffsetTRelative(off)
        claims = builder.EndVector()
    else:
        claims = None
    FBEDI835.Start(builder)
    FBEDI835.AddPayerName(builder, payer)
    FBEDI835.AddPayeeName(builder, payee)
    FBEDI835.AddPaymentDate(builder, _dt_to_ms(obj.PaymentDate))
    FBEDI835.AddTotalActualAmount(builder, obj.TotalActualAmount)
    FBEDI835.AddTransactionControlNumber(builder, tcn)
    if claims is not None:
        FBEDI835.AddClaims(builder, claims)
    root = FBEDI835.End(builder)
    builder.Finish(root)
    return bytes(builder.Output())


# ---------------------------------------------------------------------------
# Decoders → dict with canonical PascalCase field names
# ---------------------------------------------------------------------------


def _decode_person(data: bytes) -> dict:
    root = FBPerson.Person.GetRootAs(data, 0)
    passport = None
    p = root.Passport()
    if p is not None:
        passport = {
            "Number": p.Number().decode() if isinstance(p.Number(), (bytes, bytearray)) else p.Number(),
            "Authority": p.Authority().decode() if isinstance(p.Authority(), (bytes, bytearray)) else p.Authority(),
            "ExpirationDate": _ms_to_dt(p.ExpirationDate()),
        }
    records = []
    for i in range(root.PoliceRecordsLength()):
        r = root.PoliceRecords(i)
        code = r.CrimeCode()
        if isinstance(code, (bytes, bytearray)):
            code = code.decode()
        records.append({"Id": r.Id(), "CrimeCode": code})
    first = root.FirstName()
    last = root.LastName()
    if isinstance(first, (bytes, bytearray)):
        first = first.decode()
    if isinstance(last, (bytes, bytearray)):
        last = last.decode()
    return {
        "FirstName": first,
        "LastName": last,
        "Age": root.Age(),
        "Gender": Gender.Male if root.Gender() == FBGender.Gender.Male else Gender.Female,
        "Passport": passport,
        "PoliceRecords": records,
    }


def _decode_simple(data: bytes) -> dict:
    root = FBSimpleObject.SimpleObject.GetRootAs(data, 0)
    name = root.Name()
    if isinstance(name, (bytes, bytearray)):
        name = name.decode()
    return {
        "Id": root.Id(),
        "Name": name,
        "Timestamp": _ms_to_dt(root.Timestamp()),
        "IsActive": root.IsActive(),
    }


def _decode_string_array(data: bytes) -> dict:
    root = FBStringArrayObject.StringArrayObject.GetRootAs(data, 0)
    items = []
    for i in range(root.ItemsLength()):
        s = root.Items(i)
        if isinstance(s, (bytes, bytearray)):
            s = s.decode()
        items.append(s)
    return {"Items": items}


def _decode_telemetry(data: bytes) -> dict:
    root = FBTelemetryData.TelemetryData.GetRootAs(data, 0)
    id_s = root.Id()
    src = root.DataSource()
    if isinstance(id_s, (bytes, bytearray)):
        id_s = id_s.decode()
    if isinstance(src, (bytes, bytearray)):
        src = src.decode()
    measurements = [root.Measurements(i) for i in range(root.MeasurementsLength())]
    return {
        "Id": id_s,
        "DataSource": src,
        "TimeStamp": _ms_to_dt(root.TimeStamp()),
        "Param1": root.Param1(),
        "Param2": root.Param2(),
        "Measurements": measurements,
        "AssociatedProblemID": root.AssociatedProblemId(),
        "AssociatedLogID": root.AssociatedLogId(),
        "WasProcessed": root.WasProcessed(),
    }


def _decode_edi835(data: bytes) -> dict:
    root = FBEDI835.EDI835.GetRootAs(data, 0)

    def _s(v: Any) -> Any:
        return v.decode() if isinstance(v, (bytes, bytearray)) else v

    claims = []
    for i in range(root.ClaimsLength()):
        c = root.Claims(i)
        lines = []
        for j in range(c.LinesLength()):
            line = c.Lines(j)
            lines.append({
                "ServiceCode": _s(line.ServiceCode()),
                "ChargeAmount": line.ChargeAmount(),
                "AdjudicatedAmount": line.AdjudicatedAmount(),
            })
        claims.append({
            "ClaimId": _s(c.ClaimId()),
            "PatientName": _s(c.PatientName()),
            "TotalCharge": c.TotalCharge(),
            "PaymentAmount": c.PaymentAmount(),
            "Lines": lines,
        })
    return {
        "PayerName": _s(root.PayerName()),
        "PayeeName": _s(root.PayeeName()),
        "PaymentDate": _ms_to_dt(root.PaymentDate()),
        "TotalActualAmount": root.TotalActualAmount(),
        "TransactionControlNumber": _s(root.TransactionControlNumber()),
        "Claims": claims,
    }
