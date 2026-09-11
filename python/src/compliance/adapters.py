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
