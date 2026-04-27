"""
Data generators matching the C# Randomizer logic.
"""

import datetime
import random
import uuid
from typing import Any

from .models import (
    Claim, EDI835, Gender, GraphNode, Passport, Person,
    PoliceRecord, ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
)


def _phrase() -> str:
    words = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta"]
    return " ".join(random.sample(words, k=random.randint(2, 4)))


def _name() -> str:
    first = ["John", "Jane", "Alex", "Maria", "Robert", "Lisa", "David", "Sarah"]
    last = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller"]
    return f"{random.choice(first)} {random.choice(last)}"


def _id_str() -> str:
    return uuid.uuid4().hex[:12].upper()


def _datetime_now() -> datetime.datetime:
    return datetime.datetime.utcnow()


def _datetime_future(days: int = 1000) -> datetime.datetime:
    return datetime.datetime.utcnow() + datetime.timedelta(days=days)


def generate_person() -> Person:
    return Person(
        FirstName=_name().split()[0],
        LastName=_name().split()[1],
        Age=random.randint(0, 120),
        Gender=Gender.Male if random.randint(0, 1) == 0 else Gender.Female,
        Passport=Passport(
            Authority=_phrase(),
            ExpirationDate=_datetime_future(),
            Number=_id_str(),
        ),
        PoliceRecords=[
            PoliceRecord(Id=i, CrimeCode=_name())
            for i in range(20)
        ],
    )


def generate_simple_object() -> SimpleObject:
    return SimpleObject(
        Id=12345,
        Name="Simple Benchmark Object",
        Timestamp=_datetime_now(),
        IsActive=True,
    )


def generate_string_array(count: int = 100) -> StringArrayObject:
    return StringArrayObject(
        Items=[f"Item_{i}_{uuid.uuid4().hex[:8]}" for i in range(count)]
    )


def generate_telemetry(measurements_number: int = 100) -> TelemetryData:
    return TelemetryData(
        Id=str(uuid.uuid4()),
        DataSource=str(uuid.uuid4()),
        TimeStamp=datetime.datetime.now(),
        Param1=random.randint(-2_147_483_648, 2_147_483_647),
        Param2=random.randint(0, 4_294_967_295),
        Measurements=[random.random() for _ in range(measurements_number)],
        AssociatedProblemID=123,
        AssociatedLogID=89032,
        WasProcessed=True,
    )


def generate_edi_835() -> EDI835:
    doc = EDI835(
        PayerName="BlueCross BlueShield",
        PayeeName="General Hospital",
        PaymentDate=datetime.datetime.now() - datetime.timedelta(days=1),
        TotalActualAmount=1500.50,
        TransactionControlNumber="TRN-99887766",
    )
    for i in range(5):
        claim = Claim(
            ClaimId=f"CLP-{i}",
            PatientName=f"Patient {i}",
            TotalCharge=300.00,
            PaymentAmount=250.00,
        )
        for j in range(3):
            claim.Lines.append(ServiceLine(
                ServiceCode=f"9921{j}",
                ChargeAmount=100.00,
                AdjudicatedAmount=80.00,
            ))
        doc.Claims.append(claim)
    return doc


def generate_object_graph() -> GraphNode:
    """Builds a small graph with circular references."""
    root = GraphNode(Name="Root")
    child1 = GraphNode(Name="Child1", Parent=root)
    child2 = GraphNode(Name="Child2", Parent=root)
    root.Children = [child1, child2]
    # Circularity: cross-reference siblings
    child1.Related = child2
    child2.Related = child1
    return root


def generate_integer() -> int:
    return 2_147_483_647 - 123


_TEST_DATA_GENERATORS = {
    "Person": generate_person,
    "SimpleObject": generate_simple_object,
    "StringArray": generate_string_array,
    "Telemetry": lambda: generate_telemetry(100),
    "EDI_835": generate_edi_835,
    "ObjectGraph": generate_object_graph,
    "Integer": generate_integer,
}


def generate_test_data(name: str) -> Any:
    gen = _TEST_DATA_GENERATORS.get(name)
    if gen is None:
        raise ValueError(f"Unknown test data: {name}")
    return gen()
