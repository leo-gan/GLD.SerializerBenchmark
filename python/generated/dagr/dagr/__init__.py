"""Dagr — data-graph binary serialization: schema DSL, code generators, and tooling.

Public schema-authoring surface: ``dagr.dsl`` and ``dagr.config``.  Everything under
``dagr.codegen`` is the generator implementation; ``dagr.runtime`` is the reflective
pure-Python runtime that generated Python modules import.  This module deliberately
imports nothing so that the shipped copy of the package inside a ``dagr build --target
python`` output stays self-contained.
"""

__version__ = "2026.9.2"
