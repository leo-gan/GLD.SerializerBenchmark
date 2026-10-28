"""Score Kiln wire v2 with the installed gld-kiln package.

The dashboard cell matches the Mojo scorer: a reject case passes when decode
raises, and an accept case passes when the projected value matches ``decoded``.
``stricter_failed`` counts cases that would fail the library's own oracle
(error code or canonical re-encode) even if the dashboard cell passes.
"""

from __future__ import annotations

import math
from typing import Any

from kiln import KilnError, decode, decode_framed, encode, encode_framed, type_hash
from kiln import __version__ as KILN_VERSION
from kiln.schema import schema_from_case


def _project(value: Any) -> Any:
    if isinstance(value, dict) and "tensors" in value and "block_length" in value:
        return {
            "version": value["version"],
            "flags": value["flags"],
            "tensors": [
                {
                    "name": item["name"],
                    "dtype": item["dtype"],
                    "shape": list(item["shape"]),
                    "quant_scheme": item["quant_scheme"],
                    "data_hex": bytes(item["data"]).hex(),
                }
                for item in value["tensors"]
            ],
            "block_length": value["block_length"],
        }
    if isinstance(value, dict):
        return {key: _project(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_project(item) for item in value]
    return value


def _same(got: Any, want: Any) -> bool:
    if isinstance(want, float) and isinstance(got, float):
        if math.isnan(want) and math.isnan(got):
            return True
        return got == want
    if isinstance(want, dict) and isinstance(got, dict):
        return set(want) <= set(got) and all(_same(got[key], item) for key, item in want.items())
    if isinstance(want, list) and isinstance(got, list):
        return len(want) == len(got) and all(_same(a, b) for a, b in zip(got, want))
    return got == want


def score_case(case: dict) -> dict:
    raw = bytes.fromhex(case["input"])
    schema = schema_from_case(case["schema"])
    framed = case["schema"] == "frame"
    stricter = ""
    try:
        value = decode_framed(schema, raw) if framed else decode(schema, raw)
    except KilnError as exc:
        if case["expect"] != "reject":
            return {
                "id": case["id"],
                "outcome": "fail",
                "observed": "reject",
                "detail": f"{exc.code}: {exc}",
                "stricter": "reject",
            }
        if exc.code != case.get("error"):
            stricter = f"error {exc.code}, catalog {case.get('error')}"
        return {
            "id": case["id"],
            "outcome": "pass",
            "observed": "reject",
            "detail": stricter,
            "stricter": stricter,
        }
    if case["expect"] == "reject":
        return {
            "id": case["id"],
            "outcome": "fail",
            "observed": "accept",
            "detail": "decoded a buffer the catalog rejects",
            "stricter": "accepted",
        }
    if "decoded" in case:
        want = case["decoded"]
        if framed:
            got_hash = type_hash(schema)
            if int(want["hash"]) != int(got_hash):
                return {
                    "id": case["id"],
                    "outcome": "fail",
                    "observed": "accept",
                    "detail": f"type hash {got_hash} != {want['hash']}",
                    "stricter": "hash",
                }
            want = {"id": want["id"], "batch": want["batch"]}
        got = _project(value)
        if not _same(got, want):
            return {
                "id": case["id"],
                "outcome": "fail",
                "observed": "accept",
                "detail": "decoded value does not match",
                "stricter": "value",
            }
    try:
        again = encode_framed(schema, value) if framed else encode(schema, value)
    except KilnError as exc:
        stricter = f"re-encode {exc.code}"
    else:
        if again != raw:
            stricter = "re-encode mismatch"
    return {
        "id": case["id"],
        "outcome": "pass",
        "observed": "ok",
        "detail": stricter,
        "stricter": stricter,
    }


def score_document(corpus: dict) -> dict:
    cases = [score_case(case) for case in corpus["cases"]]
    return {
        "language": "python",
        "serializer": "gld-kiln",
        "serializer_version": str(KILN_VERSION),
        "pin": f"installed gld-kiln {KILN_VERSION}",
        "passed": sum(1 for case in cases if case["outcome"] == "pass"),
        "failed": sum(1 for case in cases if case["outcome"] != "pass"),
        "stricter_failed": sum(1 for case in cases if case.get("stricter")),
        "cases": cases,
    }
