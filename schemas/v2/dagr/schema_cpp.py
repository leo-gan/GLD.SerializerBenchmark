"""The C++ target of the Dagr rows — the same 20 graphs as schema.py (five suite types in
four node layouts), emitted for C++ by `dagr build --schema schema_cpp.py --receipt
dagr_cpp.lock.json`.

A library of its own because the C++ target (Dagr spec/41) is newer than the dagr-cli
release the other languages are built with: building it from Dagr's main branch here
regenerates nothing else and leaves dagr.lock.json alone. Fold the `Cpp(...)` target into
schema.py once a dagr-cli release ships it.
"""

from dagr.config import Cpp, Library

from schema import ALL_GRAPHS

library = Library(
    'BenchmarkV2',
    schemas=ALL_GRAPHS,
    # Header-only: include/benchmark_v2/<graph>{,_arena,_direct}.hpp + the runtime
    # include/dagr/*.hpp; cpp/CMakeLists.txt adds the include directory.
    targets=[Cpp(out="../../../cpp/dagr_gen", namespace="benchmark_v2")],
    wire_format_version=1,
)
