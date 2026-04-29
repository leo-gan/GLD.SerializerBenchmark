import datetime
import json
import os
import random
import uuid
from typing import Any, List, Optional

from .models import (
    Claim, EDI835, Gender, GraphNode, Passport, Person,
    PoliceRecord, ServiceLine, SimpleObject, StringArrayObject, TelemetryData,
)


class Randomizer:
    _POOL_UPPER = "QWERTYUIOPASDFGHJKLZXCVBNM"
    _POOL_LOWER = "qwertyuiopasdfghjklzxcvbnm"
    _POOL_PUNCT = "                    ,,,,...!?--:;"
    
    settings = {
        "StringOptions": {
            "MinWordLength": 3, "MaxWordLength": 10,
            "MinPhraseLength": 2, "MaxPhraseLength": 6,
            "MinIdLength": 8, "MaxIdLength": 12,
            "DuplicationFactor": 0.1
        },
        "CollectionOptions": {
            "PersonPoliceRecordsCount": 5,
            "TelemetryMeasurementsCount": 100,
            "StringArrayCount": 100,
            "EdiClaimsCount": 5,
            "EdiLinesPerClaimCount": 3
        },
        "RandomSeed": 42
    }
    _string_pool: List[str] = []

    @classmethod
    def initialize(cls):
        config_path = cls._find_config()
        if config_path and os.path.exists(config_path):
            try:
                import re
                with open(config_path, 'r') as f:
                    content = f.read()
                # Strip // and /* */ comments
                content = re.sub(r"//.*|/\*[\s\S]*?\*/", "", content)
                cls.settings = json.loads(content)
                random.seed(cls.settings.get("RandomSeed", 42))
            except Exception as e:
                print(f"Error loading config: {e}")
        else:
            random.seed(cls.settings["RandomSeed"])

    @classmethod
    def _find_config(cls) -> Optional[str]:
        search_paths = [
            "../../schemas/test_data_config.json",
            "../schemas/test_data_config.json",
            "schemas/test_data_config.json",
            "../../../schemas/test_data_config.json"
        ]
        # Current file is in python/src/benchmark/data/generator.py
        # Root is ../../../../
        base_dir = os.path.dirname(os.path.abspath(__file__))
        for p in search_paths:
            full_path = os.path.abspath(os.path.join(base_dir, "../../../..", p))
            if os.path.exists(full_path):
                return full_path
            # Also try relative to CWD
            if os.path.exists(p):
                return p
        return None

    @classmethod
    def try_get_duplicate(cls) -> Optional[str]:
        if cls._string_pool and random.random() < cls.settings["StringOptions"]["DuplicationFactor"]:
            return random.choice(cls._string_pool)
        return None

    @classmethod
    def add_to_pool(cls, s: str):
        if len(cls._string_pool) < 1000:
            cls._string_pool.append(s)
        else:
            cls._string_pool[random.randint(0, 999)] = s

    @classmethod
    def name(cls) -> str:
        s = cls.try_get_duplicate()
        if s: return s
        res = random.choice(cls._POOL_UPPER) + cls.word()
        cls.add_to_pool(res)
        return res

    @classmethod
    def word(cls) -> str:
        s = cls.try_get_duplicate()
        if s: return s
        opts = cls.settings["StringOptions"]
        length = random.randint(opts["MinWordLength"], opts["MaxWordLength"])
        res = "".join(random.choice(cls._POOL_LOWER) for _ in range(length))
        cls.add_to_pool(res)
        return res

    @classmethod
    def id_str(cls) -> str:
        s = cls.try_get_duplicate()
        if s: return s
        opts = cls.settings["StringOptions"]
        length = random.randint(opts["MinIdLength"], opts["MaxIdLength"])
        res = "".join(random.choice("0123456789") for _ in range(length))
        cls.add_to_pool(res)
        return res

    @classmethod
    def phrase(cls) -> str:
        s = cls.try_get_duplicate()
        if s: return s
        opts = cls.settings["StringOptions"]
        length = random.randint(opts["MinPhraseLength"], opts["MaxPhraseLength"])
        parts = [cls.name()]
        for _ in range(length):
            parts.append(cls.word() + random.choice(cls._POOL_PUNCT))
        res = " ".join(parts)
        cls.add_to_pool(res)
        return res


# Initialize on load
Randomizer.initialize()


def _datetime_now() -> datetime.datetime:
    return datetime.datetime.utcnow()


def _datetime_future(days: int = 1000) -> datetime.datetime:
    return datetime.datetime.utcnow() + datetime.timedelta(days=days)


def generate_person() -> Person:
    return Person(
        FirstName=Randomizer.name(),
        LastName=Randomizer.name(),
        Age=random.randint(0, 120),
        Gender=Gender.Male if random.randint(0, 1) == 0 else Gender.Female,
        Passport=Passport(
            Authority=Randomizer.phrase(),
            ExpirationDate=_datetime_future(),
            Number=Randomizer.id_str(),
        ),
        PoliceRecords=[
            PoliceRecord(Id=i, CrimeCode=Randomizer.name())
            for i in range(Randomizer.settings["CollectionOptions"]["PersonPoliceRecordsCount"])
        ],
    )


def generate_simple_object() -> SimpleObject:
    return SimpleObject(
        Id=12345,
        Name="Simple Benchmark Object",
        Timestamp=_datetime_now(),
        IsActive=True,
    )


def generate_string_array(count: Optional[int] = None) -> StringArrayObject:
    if count is None:
        count = Randomizer.settings["CollectionOptions"]["StringArrayCount"]
    return StringArrayObject(
        Items=[Randomizer.phrase() for _ in range(count)]
    )


def generate_telemetry(measurements_number: Optional[int] = None) -> TelemetryData:
    if measurements_number is None:
        measurements_number = Randomizer.settings["CollectionOptions"]["TelemetryMeasurementsCount"]
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
    opts = Randomizer.settings["CollectionOptions"]
    doc = EDI835(
        PayerName="BlueCross BlueShield",
        PayeeName="General Hospital",
        PaymentDate=datetime.datetime.now() - datetime.timedelta(days=1),
        TotalActualAmount=1500.50,
        TransactionControlNumber="TRN-99887766",
    )
    for i in range(opts["EdiClaimsCount"]):
        claim = Claim(
            ClaimId=f"CLP-{i}",
            PatientName=f"Patient {i}",
            TotalCharge=300.00,
            PaymentAmount=250.00,
        )
        for j in range(opts["EdiLinesPerClaimCount"]):
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
    "Telemetry": generate_telemetry,
    "EDI_835": generate_edi_835,
    "ObjectGraph": generate_object_graph,
    "Integer": generate_integer,
}


def generate_test_data(name: str) -> Any:
    gen = _TEST_DATA_GENERATORS.get(name)
    if gen is None:
        raise ValueError(f"Unknown test data: {name}")
    return gen()

