"""
Canonical Python data models mirroring the C# test data types.

These dataclasses serve as the source of truth for all serializer benchmarks.
Schema-based serializers (Protobuf, Avro) convert to/from their generated
classes; native serializers work with these objects directly.
"""

from __future__ import annotations

import datetime
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional


class Gender(Enum):
    Male = 0
    Female = 1


@dataclass
class Passport:
    Number: str = ""
    Authority: str = ""
    ExpirationDate: datetime.datetime = field(default_factory=datetime.datetime.utcnow)


@dataclass
class PoliceRecord:
    Id: int = 0
    CrimeCode: str = ""


@dataclass
class Person:
    FirstName: str = ""
    LastName: str = ""
    Age: int = 0
    Gender: Gender = Gender.Male
    Passport: Optional[Passport] = None
    PoliceRecords: List[PoliceRecord] = field(default_factory=list)


@dataclass
class SimpleObject:
    Id: int = 0
    Name: str = ""
    Timestamp: datetime.datetime = field(default_factory=datetime.datetime.utcnow)
    IsActive: bool = False


@dataclass
class StringArrayObject:
    Items: List[str] = field(default_factory=list)


@dataclass
class TelemetryData:
    Id: str = ""
    DataSource: str = ""
    TimeStamp: datetime.datetime = field(default_factory=datetime.datetime.utcnow)
    Param1: int = 0
    Param2: int = 0
    Measurements: List[float] = field(default_factory=list)
    AssociatedProblemID: int = 0
    AssociatedLogID: int = 0
    WasProcessed: bool = False


@dataclass
class ServiceLine:
    ServiceCode: str = ""
    ChargeAmount: float = 0.0
    AdjudicatedAmount: float = 0.0


@dataclass
class Claim:
    ClaimId: str = ""
    PatientName: str = ""
    TotalCharge: float = 0.0
    PaymentAmount: float = 0.0
    Lines: List[ServiceLine] = field(default_factory=list)


@dataclass
class EDI835:
    PayerName: str = ""
    PayeeName: str = ""
    PaymentDate: datetime.datetime = field(default_factory=datetime.datetime.utcnow)
    TotalActualAmount: float = 0.0
    TransactionControlNumber: str = ""
    Claims: List[Claim] = field(default_factory=list)


@dataclass
class GraphNode:
    Name: str = ""
    Parent: Optional[GraphNode] = None
    Children: List[GraphNode] = field(default_factory=list)
    Related: Optional[GraphNode] = None
