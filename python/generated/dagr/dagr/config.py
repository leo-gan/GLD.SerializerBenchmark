"""
Dagr build configuration — the declarative `Library` a schema module exposes, and
the importlib loader the CLI uses to read it.

A schema module is *declarative*: it defines `DataGraph`/`DataSink` objects and a
`library = Library(...)` describing the build.  It must NOT call generators — the
CLI imports the module (which runs its top level), reads the `Library` model, and
drives generation itself.  This is the phase separation from "16 Generation
Receipts.md" §9: the module declares a model; the CLI consumes it.
"""

from __future__ import annotations
import importlib.util
import pathlib
import sys

from dagr.dsl import DataGraph, DataSink, SharedBuffer


# ── Targets ────────────────────────────────────────────────────────────────────

def _as_schema_name(x) -> str:
    """Normalize a schema selector to its name.  Accepts a schema object
    (DataGraph / DataSink / SharedBuffer — anything with a `.name`, same as
    `Library.schemas` takes) or a bare name string.  Passing the object avoids
    the string-vs-name mismatch entirely; strings stay supported because the
    receipt is JSON and rehydrates `exclude` from names."""
    return x.name if hasattr(x, "name") else x


class Target:
    """A code-generation target: a language, an output dir, and feature flags.

    ``exclude`` is an optional per-target list of schemas to omit from this
    target's output (see "spec/17-generation-receipts.md" §9.1).  Its entries may be
    schema objects (same as `Library.schemas`) or name strings — both normalize
    to the name.  The library still declares the full schema set; a target opts a
    subset out — e.g. a demo build that only wants a couple of graphs, or a
    lagging language that can't yet emit one schema.  Default (empty) keeps the
    safe behaviour: every schema goes to every target, so adding a schema
    propagates everywhere automatically.
    """

    def __init__(self, lang: str, out: str, features=None, package: str | None = None,
                 layout: str | None = None, exclude=None):
        self.lang = lang
        self.out = out
        self.features = list(features or [])
        self.package = package
        # "package" → emit a self-contained SwiftPM package (Package.swift +
        # Sources/<Module>/); "flat" → loose .swift files in `out`.
        self.layout = layout
        # Schema names this target opts out of.  Accepts schema objects or name
        # strings, both normalized to the name here — that is what the receipt
        # records and what Library.schemas_for() matches (and validates against
        # the library's import graph) on.
        self.exclude = [_as_schema_name(x) for x in (exclude or [])]

    def __repr__(self) -> str:
        extra = f", exclude={self.exclude!r}" if self.exclude else ""
        return f"Target({self.lang!r}, out={self.out!r}, features={self.features!r}{extra})"

    def to_dict(self) -> dict:
        return {"lang": self.lang, "out": self.out, "features": self.features,
                "package": self.package, "layout": self.layout, "exclude": self.exclude}

    @classmethod
    def from_dict(cls, d: dict) -> "Target":
        return cls(d["lang"], d["out"], d.get("features"), d.get("package"),
                   d.get("layout"), d.get("exclude"))


def Swift(out, features=None, package=None, layout="package", exclude=None):
    return Target("swift", out, features, package, layout, exclude)
def Rust(out, features=None, crate=None, layout="crate", exclude=None):
    return Target("rust", out, features, crate, layout, exclude)
def TypeScript(out, exclude=None):                return Target("typescript", out, exclude=exclude)
def Mojo(out, features=None, exclude=None):       return Target("mojo", out, features, exclude=exclude)
# Odin (doc 31): standalone SharedBuffer overlays (spec 20). Each SB is emitted as
# its own Odin package directory so a consumer can `import` it.
def Odin(out, features=None, exclude=None):       return Target("odin", out, features, exclude=exclude)
# Go (spec 37): a self-contained Go module — `package` is the module path (default: the
# snake_case library name); the hand-written runtime is copied in as `<module>/dagr`.
# layout "module" (default) emits every DataGraph into the module's root package;
# "package-per-graph" gives each DataGraph its own sub-package `<module>/<graph>`, for a
# library whose graphs share type names — two graphs importing one common graph each
# carry a flattened copy of its types (spec/38 §2.5).
GO_LAYOUTS = ("module", "package-per-graph")
def Go(out, features=None, package=None, layout=None, exclude=None):
    # None (what receipts written before the option record) means "module".
    if layout is not None and layout not in GO_LAYOUTS:
        raise ValueError(f"Go target: layout must be one of {GO_LAYOUTS}, got {layout!r}")
    return Target("go", out, features, package, layout, exclude)
# "spec/29-python-codegen-plan.md" Fork A: the pure-Python reflective target — typed
# @dataclass modules over the shipped dagr/runtime runtime (eager restore + serialize).
def Python(out, features=None, package=None, exclude=None):
    return Target("python", out, features, package, exclude=exclude)
# "spec/29-python-codegen-plan.md" Fork B: a self-contained Rust cdylib that projects a
# graph to normalized Arrow tables (lazy, arena-free) and exports them over the Arrow
# C Data Interface, consumed from Python via a ctypes shim (no pyo3, no maturin).
def PythonNative(out, package=None, exclude=None):
    return Target("python-native", out, None, package, "crate", exclude)


# ── Library ────────────────────────────────────────────────────────────────────

def _graph_import_names(schema) -> set:
    """Names of every graph `schema` transitively imports.  Both DataGraph and
    DataSink carry an `.imports` list of ImportedGraph, and imported graphs may
    themselves import further, so the closure is walked."""
    seen: set = set()
    stack = list(getattr(schema, "imports", None) or [])
    while stack:
        g = stack.pop().graph
        if g.name in seen:
            continue
        seen.add(g.name)
        stack.extend(getattr(g, "imports", None) or [])
    return seen


class Library:
    """The declarative description of a build: a named, ordered selection of
    schemas, the targets to emit, and the wire-format version they encode."""

    def __init__(self, name: str, schemas, targets=None, wire_format_version: int = 1):
        if not name:
            raise ValueError("Library needs a name")
        self.name = name
        self.schemas = list(schemas)
        self.targets = list(targets or [])
        self.wire_format_version = wire_format_version

    def validate(self) -> None:
        # Every target keys its output files / modules / packages on the schema name, so
        # two schemas sharing one name would silently overwrite each other's output.
        seen: dict = {}
        for s in self.schemas:
            kind = type(s).__name__
            if s.name in seen:
                raise ValueError(
                    f"Library {self.name!r}: two schemas are named {s.name!r} "
                    f"({seen[s.name]} and {kind}) — schema names must be unique within a library")
            seen[s.name] = kind
        for s in self.schemas:
            if isinstance(s, (DataGraph, SharedBuffer)):
                s.validate()   # SharedBuffer enforces its §7 fixed-layout rules
            # DataSink has no validate() yet — skipped.

    def schemas_for(self, target) -> list:
        """The schemas emitted for `target`: `self.schemas` minus `target.exclude`.

        Fail-loud (never a silent no-op), enforcing two rules from
        "spec/17-generation-receipts.md" §9.1:

          * every excluded name must match a schema in the library — a typo
            excludes nothing, which would silently ship the full set;
          * an excluded schema must not be imported (transitively) by any schema
            that *stays* in this target's output.  You can't drop a dependency out
            from under a graph that still references its types — the "can't
            exclude A" rule.  The fix is to exclude the dependent too, or not
            exclude the dependency.
        """
        exclude = set(getattr(target, "exclude", None) or [])
        if not exclude:
            return list(self.schemas)
        by_name = {s.name: s for s in self.schemas}
        unknown = exclude - set(by_name)
        if unknown:
            raise ValueError(
                f"target {target.lang!r} excludes unknown schema(s) {sorted(unknown)}; "
                f"library {self.name!r} defines {sorted(by_name)}")
        included = [s for s in self.schemas if s.name not in exclude]
        for s in included:
            clash = exclude & _graph_import_names(s)
            if clash:
                raise ValueError(
                    f"target {target.lang!r} cannot exclude {sorted(clash)}: "
                    f"still imported by included schema {s.name!r}")
        return included

    def __repr__(self) -> str:
        return (f"Library({self.name!r}, schemas={[s.name for s in self.schemas]}, "
                f"targets={self.targets})")


# ── Loader ─────────────────────────────────────────────────────────────────────

def load_schema_module(path: str):
    """Import a schema file by path and return the live module.  Runs its top
    level (the schema *is* Python, so getting the objects means executing it —
    same trust model as importing any module)."""
    p = pathlib.Path(path).resolve()
    if not p.exists():
        raise FileNotFoundError(f"schema module not found: {p}")
    sys.path.insert(0, str(p.parent))           # resolve the schema's own imports
    spec = importlib.util.spec_from_file_location("dagr_user_schema", str(p))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_library(path: str, attr: str = "library") -> Library:
    """Load a `Library` from a schema module.  Prefers an explicit `library =
    Library(...)`; falls back to a unique `Library` in the module, then to an
    implicit library wrapping every top-level DataGraph/DataSink found."""
    module = load_schema_module(path)

    explicit = getattr(module, attr, None)
    if isinstance(explicit, Library):
        return explicit

    libs = [v for v in vars(module).values() if isinstance(v, Library)]
    if len(libs) == 1:
        return libs[0]
    if len(libs) > 1:
        raise ValueError(f"multiple Library objects in {path}; mark one as `{attr}`")

    schemas = [v for v in vars(module).values()
               if isinstance(v, (DataGraph, DataSink, SharedBuffer))]
    if not schemas:
        raise ValueError(f"no Library or schema objects found in {path}")
    return Library(pathlib.Path(path).stem, schemas)
