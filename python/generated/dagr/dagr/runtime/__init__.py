"""dagr/runtime — the pure-Python reflective Dagr runtime (Fork A of "27 Python Codegen
Plan.md").

A single hand-written, schema-interpreting runtime: byte-exact `restore` (bytes → a
plain Python object graph) and `serialize` (object graph → bytes) that consume a live
`dagr_dsl.DataGraph` by *walking the schema* — no per-schema code emission for the
core. Doubles as an in-process oracle for the other targets (read a Swift/Rust golden
and assert values, no compiler in the loop) and as a notebook data-access layer.

Phase 0 (this pass): the wire primitives (`dagr_reader`, `dagr_writer`). Eager
reflective restore + serialize land in Phases 1–2.
"""
from .dagr_reader import DagrError   # noqa: F401
