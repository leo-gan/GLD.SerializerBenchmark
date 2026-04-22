import sys
import os
import pytest
from generated import benchmark_data_pb2

def load_data(file_name, proto_class):
    data_path = os.path.join(os.path.dirname(__file__), "..", "data", file_name)
    with open(data_path, "rb") as f:
        data = f.read()

    obj = proto_class()
    obj.ParseFromString(data)
    return obj

# Pre-load data to ensure we benchmark only serialization/deserialization, not disk I/O
person_obj = load_data("Person.bin", benchmark_data_pb2.Person)
person_bytes = person_obj.SerializeToString()

simple_obj = load_data("SimpleObject.bin", benchmark_data_pb2.SimpleObject)
simple_bytes = simple_obj.SerializeToString()

string_array_obj = load_data("StringArray.bin", benchmark_data_pb2.StringArrayObject)
string_array_bytes = string_array_obj.SerializeToString()

telemetry_obj = load_data("Telemetry.bin", benchmark_data_pb2.TelemetryData)
telemetry_bytes = telemetry_obj.SerializeToString()

edi_obj = load_data("EDI_835.bin", benchmark_data_pb2.EDI835)
edi_bytes = edi_obj.SerializeToString()

def serialize(obj):
    return obj.SerializeToString()

def deserialize(proto_class, data):
    obj = proto_class()
    obj.ParseFromString(data)
    return obj

# --- Pytest Benchmarks ---

def test_person_serialize(benchmark):
    benchmark(serialize, person_obj)

def test_person_deserialize(benchmark):
    benchmark(deserialize, benchmark_data_pb2.Person, person_bytes)

def test_simple_object_serialize(benchmark):
    benchmark(serialize, simple_obj)

def test_simple_object_deserialize(benchmark):
    benchmark(deserialize, benchmark_data_pb2.SimpleObject, simple_bytes)

def test_string_array_serialize(benchmark):
    benchmark(serialize, string_array_obj)

def test_string_array_deserialize(benchmark):
    benchmark(deserialize, benchmark_data_pb2.StringArrayObject, string_array_bytes)

def test_telemetry_serialize(benchmark):
    benchmark(serialize, telemetry_obj)

def test_telemetry_deserialize(benchmark):
    benchmark(deserialize, benchmark_data_pb2.TelemetryData, telemetry_bytes)

def test_edi_serialize(benchmark):
    benchmark(serialize, edi_obj)

def test_edi_deserialize(benchmark):
    benchmark(deserialize, benchmark_data_pb2.EDI835, edi_bytes)

if __name__ == "__main__":
    pytest.main(["-v", "benchmark.py"])
