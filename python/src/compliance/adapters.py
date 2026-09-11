"""Decode/encode adapters over libraries already in the Python runner."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

DecodeFn = Callable[[bytes], Any]
EncodeFn = Callable[[Any], bytes]


def _package_version(distribution_name: str) -> str:
    if not distribution_name:
        return ""
    if distribution_name == "stdlib":
        import sys

        return sys.version.split()[0]
    try:
        from importlib.metadata import PackageNotFoundError, version

        return version(distribution_name)
    except PackageNotFoundError:
        return ""
    except Exception:
        return ""


@dataclass(frozen=True)
class Adapter:
    name: str
    format: str
    decode: DecodeFn
    encode: EncodeFn | None = None
    notes: str = ""
    package_name: str = ""

    @property
    def version(self) -> str:
        return _package_version(self.package_name)


def _json_stdlib_decode(data: bytes) -> Any:
    import json

    return json.loads(data)


def _json_stdlib_encode(obj: Any) -> bytes:
    import json

    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode(
        "utf-8"
    )


def _orjson_decode(data: bytes) -> Any:
    import orjson

    return orjson.loads(data)


def _orjson_encode(obj: Any) -> bytes:
    import orjson

    return orjson.dumps(obj)


def _msgspec_json_decode(data: bytes) -> Any:
    import msgspec

    return msgspec.json.decode(data)


def _msgspec_json_encode(obj: Any) -> bytes:
    import msgspec

    return msgspec.json.encode(obj)


def _rapidjson_decode(data: bytes) -> Any:
    import rapidjson

    return rapidjson.loads(data)


def _rapidjson_encode(obj: Any) -> bytes:
    import rapidjson

    return rapidjson.dumps(obj, ensure_ascii=False).encode("utf-8")


def _yaml_decode(data: bytes) -> Any:
    import yaml

    return yaml.safe_load(data)


def _yaml_encode(obj: Any) -> bytes:
    import yaml

    return yaml.safe_dump(obj, allow_unicode=True, default_flow_style=False, sort_keys=False).encode(
        "utf-8"
    )


def _toml_decode(data: bytes) -> Any:
    import tomllib

    return tomllib.loads(data.decode("utf-8"))


def _cbor2_decode(data: bytes) -> Any:
    import cbor2

    return cbor2.loads(data)


def _cbor2_encode(obj: Any) -> bytes:
    import cbor2

    return cbor2.dumps(obj)


def _msgpack_decode(data: bytes) -> Any:
    import msgpack

    return msgpack.unpackb(data, raw=False, strict_map_key=False)


def _msgpack_encode(obj: Any) -> bytes:
    import msgpack

    return msgpack.packb(obj, use_bin_type=True)


def _msgspec_msgpack_decode(data: bytes) -> Any:
    import msgspec

    return msgspec.msgpack.decode(data)


def _msgspec_msgpack_encode(obj: Any) -> bytes:
    import msgspec

    return msgspec.msgpack.encode(obj)


_PROTO_CLS = None


def _proto_doc_class():
    global _PROTO_CLS
    if _PROTO_CLS is not None:
        return _PROTO_CLS
    from google.protobuf import descriptor_pb2, descriptor_pool, message_factory

    file_proto = descriptor_pb2.FileDescriptorProto()
    file_proto.name = "compliance_doc.proto"
    file_proto.package = "cmp"
    file_proto.syntax = "proto3"
    msg = file_proto.message_type.add()
    msg.name = "Doc"
    for name, number, typ in (("n", 1, 5), ("s", 2, 9), ("ok", 3, 8), ("tags", 4, 5)):
        field = msg.field.add()
        field.name = name
        field.number = number
        field.type = typ
        field.label = 3 if name == "tags" else 1
    pool = descriptor_pool.DescriptorPool()
    pool.Add(file_proto)
    _PROTO_CLS = message_factory.GetMessageClass(pool.FindMessageTypeByName("cmp.Doc"))
    return _PROTO_CLS


def _protobuf_decode(data: bytes) -> Any:
    from .context import current_schema

    schema = current_schema.get()
    cls = _proto_doc_class()
    if schema == "json":
        from google.protobuf.json_format import Parse

        msg = cls()
        Parse(data.decode("utf-8"), msg)
        return {"n": msg.n, "s": msg.s, "ok": msg.ok, "tags": list(msg.tags)}
    msg = cls()
    msg.ParseFromString(data)
    return {"n": msg.n, "s": msg.s, "ok": msg.ok, "tags": list(msg.tags)}


def _avro_decode(data: bytes) -> Any:
    import io

    import fastavro

    from .context import current_schema

    schema = current_schema.get() or "int"
    return fastavro.schemaless_reader(io.BytesIO(data), schema)


def _bson_decode(data: bytes) -> Any:
    try:
        import bson
    except ImportError as exc:
        raise ImportError("bson") from exc
    if hasattr(bson, "decode"):
        return bson.decode(data)
    return bson.BSON(data).decode()


def _flexbuffers_decode(data: bytes) -> Any:
    from flatbuffers import flexbuffers

    root = flexbuffers.GetRoot(bytearray(data))
    return root.Value


def builtin_adapters() -> list[Adapter]:
    """Adapters that can be constructed; missing optional imports are skipped."""
    specs: list[tuple[str, str, DecodeFn, EncodeFn | None, str, str]] = [
        ("json", "json", _json_stdlib_decode, _json_stdlib_encode, "Python stdlib json", "stdlib"),
        ("orjson", "json", _orjson_decode, _orjson_encode, "orjson", "orjson"),
        ("msgspec", "json", _msgspec_json_decode, _msgspec_json_encode, "msgspec.json", "msgspec"),
        ("rapidjson", "json", _rapidjson_decode, _rapidjson_encode, "python-rapidjson", "python-rapidjson"),
        ("yaml", "yaml", _yaml_decode, _yaml_encode, "PyYAML safe_load (YAML 1.1)", "PyYAML"),
        ("tomllib", "toml", _toml_decode, None, "Python 3.11+ tomllib (TOML 1.0)", "stdlib"),
        ("cbor2", "cbor", _cbor2_decode, _cbor2_encode, "cbor2", "cbor2"),
        ("msgpack", "msgpack", _msgpack_decode, _msgpack_encode, "msgpack (use_bin_type=True)", "msgpack"),
        (
            "msgspec-msgpack",
            "msgpack",
            _msgspec_msgpack_decode,
            _msgspec_msgpack_encode,
            "msgspec.msgpack",
            "msgspec",
        ),
        ("protobuf", "protobuf", _protobuf_decode, None, "google.protobuf wire / JSON mapping", "protobuf"),
        ("fastavro", "avro", _avro_decode, None, "fastavro schemaless binary", "fastavro"),
        ("bson", "bson", _bson_decode, None, "pymongo bson", "pymongo"),
        (
            "flexbuffers",
            "flatbuffers",
            _flexbuffers_decode,
            None,
            "flatbuffers.flexbuffers",
            "flatbuffers",
        ),
    ]
    out: list[Adapter] = []
    for name, fmt, dec, enc, notes, package in specs:
        try:
            # Probe decode with empty input so import errors surface here.
            dec(b"")
        except Exception as exc:  # noqa: BLE001 — probe only
            if isinstance(exc, (ImportError, ModuleNotFoundError)):
                continue
        out.append(
            Adapter(
                name=name,
                format=fmt,
                decode=dec,
                encode=enc,
                notes=notes,
                package_name=package,
            )
        )
    return out
