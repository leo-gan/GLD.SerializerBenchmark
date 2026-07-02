"""
FlatBuffers benchmark wrapper (flatc-generated tables under generated/flatbuffers_gen).

Performance reality (Python binding)
------------------------------------
* **Serialize is inherently slow here.** The official ``flatbuffers`` package
  builds tables with a pure-Python ``Builder`` (vtable writes, many small
  method calls). That is typically 100–200× slower than ``protobuf``'s C++
  ``SerializeToString`` on the same fixture — not a harness bug.
* **Deserialize is zero-copy root setup.** Timed deserialize only runs
  ``GetRootAs`` and returns a thin view. Field reads (strings, nested tables)
  happen when the application / semantic comparer accesses attributes, which
  is *outside* the ser/des timers (same model as FlatBuffers' design).

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
# Zero-copy views (PascalCase attributes for the semantic comparer)
# Timed deserialize only constructs these wrappers + GetRootAs.
# ---------------------------------------------------------------------------


def _fb_str(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return value.decode()
    return value


class _PassportView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def Number(self) -> Any:
        return _fb_str(self._r.Number())

    @property
    def Authority(self) -> Any:
        return _fb_str(self._r.Authority())

    @property
    def ExpirationDate(self) -> datetime.datetime:
        return _ms_to_dt(self._r.ExpirationDate())


class _PoliceView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def Id(self) -> int:
        return self._r.Id()

    @property
    def CrimeCode(self) -> Any:
        return _fb_str(self._r.CrimeCode())


class _PersonView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def FirstName(self) -> Any:
        return _fb_str(self._r.FirstName())

    @property
    def LastName(self) -> Any:
        return _fb_str(self._r.LastName())

    @property
    def Age(self) -> int:
        return self._r.Age()

    @property
    def Gender(self) -> Gender:
        return Gender.Male if self._r.Gender() == FBGender.Gender.Male else Gender.Female

    @property
    def Passport(self) -> Any:
        p = self._r.Passport()
        return _PassportView(p) if p is not None else None

    @property
    def PoliceRecords(self) -> list:
        r = self._r
        return [_PoliceView(r.PoliceRecords(i)) for i in range(r.PoliceRecordsLength())]


class _SimpleView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def Id(self) -> int:
        return self._r.Id()

    @property
    def Name(self) -> Any:
        return _fb_str(self._r.Name())

    @property
    def Timestamp(self) -> datetime.datetime:
        return _ms_to_dt(self._r.Timestamp())

    @property
    def IsActive(self) -> bool:
        return self._r.IsActive()


class _StringArrayView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def Items(self) -> list:
        r = self._r
        return [_fb_str(r.Items(i)) for i in range(r.ItemsLength())]


class _TelemetryView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def Id(self) -> Any:
        return _fb_str(self._r.Id())

    @property
    def DataSource(self) -> Any:
        return _fb_str(self._r.DataSource())

    @property
    def TimeStamp(self) -> datetime.datetime:
        return _ms_to_dt(self._r.TimeStamp())

    @property
    def Param1(self) -> int:
        return self._r.Param1()

    @property
    def Param2(self) -> int:
        return self._r.Param2()

    @property
    def Measurements(self) -> list:
        r = self._r
        return [r.Measurements(i) for i in range(r.MeasurementsLength())]

    @property
    def AssociatedProblemID(self) -> int:
        return self._r.AssociatedProblemId()

    @property
    def AssociatedLogID(self) -> int:
        return self._r.AssociatedLogId()

    @property
    def WasProcessed(self) -> bool:
        return self._r.WasProcessed()


class _ServiceLineView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def ServiceCode(self) -> Any:
        return _fb_str(self._r.ServiceCode())

    @property
    def ChargeAmount(self) -> float:
        return self._r.ChargeAmount()

    @property
    def AdjudicatedAmount(self) -> float:
        return self._r.AdjudicatedAmount()


class _ClaimView:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def ClaimId(self) -> Any:
        return _fb_str(self._r.ClaimId())

    @property
    def PatientName(self) -> Any:
        return _fb_str(self._r.PatientName())

    @property
    def TotalCharge(self) -> float:
        return self._r.TotalCharge()

    @property
    def PaymentAmount(self) -> float:
        return self._r.PaymentAmount()

    @property
    def Lines(self) -> list:
        r = self._r
        return [_ServiceLineView(r.Lines(i)) for i in range(r.LinesLength())]


class _EDI835View:
    __slots__ = ("_r",)

    def __init__(self, root: Any) -> None:
        self._r = root

    @property
    def PayerName(self) -> Any:
        return _fb_str(self._r.PayerName())

    @property
    def PayeeName(self) -> Any:
        return _fb_str(self._r.PayeeName())

    @property
    def PaymentDate(self) -> datetime.datetime:
        return _ms_to_dt(self._r.PaymentDate())

    @property
    def TotalActualAmount(self) -> float:
        return self._r.TotalActualAmount()

    @property
    def TransactionControlNumber(self) -> Any:
        return _fb_str(self._r.TransactionControlNumber())

    @property
    def Claims(self) -> list:
        r = self._r
        return [_ClaimView(r.Claims(i)) for i in range(r.ClaimsLength())]


def _decode_person(data: bytes) -> _PersonView:
    return _PersonView(FBPerson.Person.GetRootAs(data, 0))


def _decode_simple(data: bytes) -> _SimpleView:
    return _SimpleView(FBSimpleObject.SimpleObject.GetRootAs(data, 0))


def _decode_string_array(data: bytes) -> _StringArrayView:
    return _StringArrayView(FBStringArrayObject.StringArrayObject.GetRootAs(data, 0))


def _decode_telemetry(data: bytes) -> _TelemetryView:
    return _TelemetryView(FBTelemetryData.TelemetryData.GetRootAs(data, 0))


def _decode_edi835(data: bytes) -> _EDI835View:
    return _EDI835View(FBEDI835.EDI835.GetRootAs(data, 0))
