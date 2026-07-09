"""
Pydantic v2 benchmark wrapper.

Uses library-native BaseModel / TypeAdapter paths. prepare_data converts shared
dataclasses into Pydantic models (untimed). Timed path is dump_json / validate_json.
"""

from __future__ import annotations

import io
from datetime import datetime
from typing import Any, Dict, List, Optional, Type

from pydantic import BaseModel, ConfigDict, TypeAdapter

from .base import Serializer
from ..data.models import (
    GRAPH_NULL,
    Claim,
    EDI835,
    Gender as GenderEnum,
    GraphNodeData,
    ObjectGraph,
    Passport,
    Person,
    PoliceRecord,
    ServiceLine,
    SimpleObject,
    StringArrayObject,
    TelemetryData,
)


class _Cfg(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class PassportModel(_Cfg):
    Number: str = ""
    Authority: str = ""
    ExpirationDate: datetime


class PoliceRecordModel(_Cfg):
    Id: int = 0
    CrimeCode: str = ""


class PersonModel(_Cfg):
    # Annotation must not be named `Gender` in the same scope as the field
    # (Pydantic treats that as a name clash). Import alias GenderEnum avoids it.
    FirstName: str = ""
    LastName: str = ""
    Age: int = 0
    Gender: GenderEnum = GenderEnum.Male
    Passport: Optional[PassportModel] = None
    PoliceRecords: List[PoliceRecordModel] = []


class SimpleObjectModel(_Cfg):
    Id: int = 0
    Name: str = ""
    Timestamp: datetime
    IsActive: bool = False


class StringArrayObjectModel(_Cfg):
    Items: List[str] = []


class TelemetryDataModel(_Cfg):
    Id: str = ""
    DataSource: str = ""
    TimeStamp: datetime
    Param1: int = 0
    Param2: int = 0
    Measurements: List[float] = []
    AssociatedProblemID: int = 0
    AssociatedLogID: int = 0
    WasProcessed: bool = False


class ServiceLineModel(_Cfg):
    ServiceCode: str = ""
    ChargeAmount: float = 0.0
    AdjudicatedAmount: float = 0.0


class ClaimModel(_Cfg):
    ClaimId: str = ""
    PatientName: str = ""
    TotalCharge: float = 0.0
    PaymentAmount: float = 0.0
    Lines: List[ServiceLineModel] = []


class EDI835Model(_Cfg):
    PayerName: str = ""
    PayeeName: str = ""
    PaymentDate: datetime
    TotalActualAmount: float = 0.0
    TransactionControlNumber: str = ""
    Claims: List[ClaimModel] = []


class GraphNodeDataModel(_Cfg):
    Name: str = ""
    Parent: int = GRAPH_NULL
    Related: int = GRAPH_NULL
    Children: List[int] = []


class ObjectGraphModel(_Cfg):
    root: int = 0
    nodes: List[GraphNodeDataModel] = []


_MODEL_MAP: Dict[Type[Any], Type[BaseModel]] = {
    Person: PersonModel,
    SimpleObject: SimpleObjectModel,
    StringArrayObject: StringArrayObjectModel,
    TelemetryData: TelemetryDataModel,
    EDI835: EDI835Model,
    Claim: ClaimModel,
    ServiceLine: ServiceLineModel,
    Passport: PassportModel,
    PoliceRecord: PoliceRecordModel,
    GraphNodeData: GraphNodeDataModel,
    ObjectGraph: ObjectGraphModel,
}


class PydanticSerializer(Serializer):
    native_kind = "model"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._adapter: TypeAdapter[Any] | None = None
        self._model_cls: Type[BaseModel] | None = None
        self._is_scalar = False

    @property
    def name(self) -> str:
        return "pydantic"

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        model_cls = _MODEL_MAP.get(test_data_type)
        if model_cls is not None:
            self._model_cls = model_cls
            self._adapter = TypeAdapter(model_cls)
            self._is_scalar = False
        else:
            # int / other scalars
            self._model_cls = None
            self._adapter = TypeAdapter(test_data_type)
            self._is_scalar = True

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        if self._is_scalar:
            return obj
        assert self._model_cls is not None
        return self._model_cls.model_validate(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        assert self._adapter is not None
        return self._adapter.dump_json(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        assert self._adapter is not None
        return self._adapter.validate_json(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
