# 4.3 Python: `google.protobuf` Runtime Path

## Problem Statement

Most Python developers interact with Protocol Buffers only through generated `*_pb2.py` classes, leaving three implementation questions opaque: which runtime backend actually executes serialization (`upb` vs. pure Python), how descriptor metadata maps Python attributes to wire tags, and who owns the resulting `bytes` and input buffers.

This chapter traces the full path from `.proto` compilation through `SerializeToString` and `ParseFromString` in `google.protobuf` (pinned at `protobuf>=7.34.1,<8` in `python/pyproject.toml`).[^1]

---

## Architecture: Codegen, Descriptors, and Runtime Backends

```text
  .proto ──protoc --python_out──► *_pb2.py (classes + serialized FileDescriptorProto)
                                       │
                        import-time backend resolution:
                         upb (default C core)  >  pure Python
                                       │
                  Message ──SerializeToString()──► immutable bytes (caller-owned)
                  Message ◄─ParseFromString()──── bytes / memoryview
```

At import time, `google.protobuf` selects one implementation backend:[^2]

| Backend | Implementation | Typical Role |
|---|---|---|
| **`upb`** (default) | Native C library (`upb` mini-tables and arena allocator) shipped in modern PyPI wheels | Production and steady-state benchmarks |
| **`python`** | Pure-Python reflection loops in `google.protobuf.internal` | Portable fallback when native extensions cannot load |
| **`cpp`** *(legacy)* | Older C++ wrapper extension | No longer shipped in standard PyPI wheels |

Force a specific backend for reproducible debugging or benchmarking via `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=upb` (or `python`).

---

## Client Path and API Semantics

Compile a schema into generated Python classes:

```bash
protoc -I schemas --python_out=python/generated schemas/v2/protobuf/benchmark_v2.proto
```

Python attribute names are purely language bindings; wire identity remains the integer field numbers embedded in each class's `DESCRIPTOR`. On the standalone teaching schema `mini.proto` ([4.2 Lab](lab-mini-protobuf-encoder.md)):

```python
import mini_pb2

msg = mini_pb2.MiniUser(id=1, name="Ada")
raw: bytes = msg.SerializeToString()          # b'\x08\x01\x12\x03Ada'

out = mini_pb2.MiniUser.FromString(raw)       # construct fresh + parse
```

### Replace vs. Merge Semantics

Three decoding methods look similar but carry distinct state-mutation semantics:

| Method | Semantics | Hazard if Misused |
|---|---|---|
| `msg.ParseFromString(data)` | **Replace:** clears `msg`, then parses `data` | Safe on reused objects; returns bytes parsed |
| `Cls.FromString(data)` | **Construct + Parse:** allocates fresh message | Safest default; prevents stale-field bleed |
| `msg.MergeFromString(data)` | **Merge:** preserves existing fields, appends repeated items, merges submessages | Silently duplicates repeated entries if called on a reused instance expecting replacement |

Pass `deterministic=True` to `SerializeToString(deterministic=True)` when deterministic map-key ordering is desired (note that full canonical byte-identity across library versions is still not guaranteed by the Protobuf specification).

---

## Internal Execution Trace

### Serialization (`SerializeToString`)

1. **Backend dispatch:** Python delegates to the resolved `upb` C extension (or pure-Python encoder).
2. **Descriptor-driven field walk:** The runtime iterates present fields via compiled descriptor metadata (`upb` mini-tables), skipping proto3 default scalars.
3. **Tag + payload emission:** Emits `[key][payload]` per [4.1 Protocol Buffers wire format](protobuf-wire-format.md)—varints for integers/enums/bools, 4/8-byte little-endian fixed values, and staged `LEN` frames for strings, bytes, packed arrays, and nested submessages.
4. **Immutable output materialization:** Copies the serialized arena buffer into a new Python `bytes` object owned by the caller (no reference to `msg` is retained).

### Deserialization (`ParseFromString`)

1. **Buffer view entry:** `upb` reads directly from the input `bytes` or `memoryview` buffer without an upfront input copy.
2. **Tag loop and descriptor lookup:** Reads each key varint, splits `(field_number, wire_type)`, looks up the field descriptor, decodes known payloads (enforcing UTF-8 validity on `string` fields and a recursion-depth cap on nested messages), and skips or retains unknown fields by wire type.
3. **Python object realization:** While `upb` stores scalar fields inside compact C message structs, accessing strings, lists, and submessages from Python allocates CPython wrapper objects (`str`, sequence/message proxies). That CPython boundary cost is an inherent component of Python Protobuf latency, distinct from raw wire scanning.
4. **Error handling:** Truncated varints, invalid wire types, malformed UTF-8, or recursion overflows raise `google.protobuf.message.DecodeError`. Always enforce an upfront payload byte cap before invoking `ParseFromString` ([3.2 Untrusted input](../301/untrusted-input.md)).

---

## Buffer Ownership and Suite Integration

| Object | Owner & Lifetime |
|---|---|
| Generated `Message` | Python garbage collector (C `upb` arena freed when the Python wrapper is collected) |
| Returned `bytes` | Immutable, caller-owned |
| Input `bytes` / `memoryview` | Caller must keep mutable backing buffers alive for the duration of `ParseFromString` |

In this benchmark suite (`python/src/benchmark/serializers/schema_protobuf.py`, log name `protobuf`), converting the suite's dataclass record into a generated Protobuf `Message` runs inside untimed `prepare_data`, while `serialize_bytes` and `deserialize_bytes` time only `SerializeToString` and `ParseFromString`. Inspect live measurements on the [Python Protocol Buffers Dashboard slice](../../dashboard/index.html?lang=python&standard=protobuf&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protobuf&ser=protobuf#detailed-analytics), keeping comparisons strictly within Python ([3.9 Fair benchmarking](../301/using-this-suite.md)).

---

## Exercises

1. **Merge-bug diagnosis:** A worker reuses one module-level `msg = mini_pb2.MiniUser()` across requests to avoid allocation and calls `msg.MergeFromString(req_bytes)` on every request. After two requests with `tags = [1]` and `tags = [2]`, what does `msg.tags` contain, and what is the correct fix?

??? note "Solution"
    `msg.tags` contains **`[1, 2]`** (concatenating state across unrelated requests, a severe cross-request data leak!). Call `msg.ParseFromString(req_bytes)` (which clears `msg` first) or, even safer, construct a fresh message via `mini_pb2.MiniUser.FromString(req_bytes)`.

2. **Benchmark reproducibility:** Two engineers run the same Python Protobuf benchmark on identical hardware and observe a $10\times$ speed difference. What environment check immediately explains the discrepancy?

??? note "Solution"
    Inspect `google.protobuf.internal.api_implementation.Type()` (or `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION`). One environment fell back to the **`python`** pure-Python backend while the other ran the native **`upb`** C backend.

3. **Timing boundary discipline:** Why does `schema_protobuf.py` place dataclass-to-`Message` conversion in untimed `prepare_data` rather than inside `serialize_bytes`?

??? note "Solution"
    Production services using Protocol Buffers natively populate generated `Message` objects directly rather than first constructing intermediate dataclasses. Keeping domain conversion outside the timer isolates codec serialization cost from runner-specific adapter mapping (see [Timing honesty](../../analysis/TIMING_HONESTY.md)).

---

## References

[^1]: Google Protocol Buffers Documentation. *Python Generated Code Guide and `Message` API*. <https://protobuf.dev/reference/python/python-generated/>
[^2]: Protocol Buffers Repository. *Python Runtime Backends (`upb` vs. Pure Python)*. <https://github.com/protocolbuffers/protobuf/blob/main/python/README.md>
