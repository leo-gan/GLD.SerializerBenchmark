"""High-performance JSON for Mojo.

- **Python-like API:** `loads`, `dumps`, `load`, `dump`.
- **Pure Mojo, zero FFI on the hot path.** The default CPU parser is
  a 64-byte branchless SIMD two-pass walker (PSHUFB-style classifier
  with prefix-XOR escape tracking) that emits a packed `Document`
  tape. The simdjson FFI shim is opt-in via `target='cpu-simdjson'`.
- **One representation across CPU and GPU.** Every backend writes
  into the same tape-backed `Document`. `Value` is a stable index
  into that tape, so iteration is a tape walk rather than a re-parse,
  and nested mutation propagates through the parent
  (`doc["a"]["b"].set(...)` is observed by `doc`).
- **GPU acceleration.** `target='gpu'` runs natively on NVIDIA, AMD,
  and Apple Metal under one lean pipeline (fused structural-bitmap
  kernel plus positions-only stream compaction). Only worth it for
  files >100 MB on discrete cards.
- **Reflection serde with no boilerplate.** `serialize_json(struct)`
  and `deserialize_json[T](json)` walk struct fields at compile time;
  override one type with `JsonSerializable` / `JsonDeserializable`
  without abandoning reflection for the rest.
- **RFC-compliant queries.** JSONPath (RFC 9535), JSON Patch
  (RFC 6902), JSON Merge Patch (RFC 7396), JSON Schema validation.

See the [API reference](https://ehsanmok.github.io/json/) for the
full public surface; benchmark numbers and the `pixi` task list
live in the project [README](https://github.com/ehsanmok/json#readme).

```mojo
from json import loads, dumps, load, dump

var data = loads('{"name": "Alice", "scores": [95, 87, 92]}')
print(data["name"].string_value())      # Alice
print(data["scores"][0].int_value())    # 95

var fast = loads[target="cpu-simdjson"]('{"x": 1}')   # simdjson FFI
var big  = load[target="gpu"]("huge.json")            # GPU (>100 MB)

print(dumps(data, indent="  "))         # pretty print
```

Notes:
- `Value` is a view over a tape-backed `Document`; mutation is
  copy-on-write, so nested `set` / `append` propagates correctly.
- The default CPU parser is the two-pass stage 1 + stage 2 walker
  (`json.cpu.parse_cpu_native_tape`).
- `loads[target='gpu']` emits a raw structural bitmap on the GPU
  and applies the in-string filter on the CPU side in
  `gpu/tape_adapter.mojo`, so NVIDIA / AMD / Apple Metal share one
  pipeline.
- Typed NDJSON file load: `load[format='ndjson'](path) -> List[Value]`.
- Configured parsing / serialisation use the two-arg overloads:
  `loads(s, config)` and `dumps(v, config)`.
"""

# Core API.
from .parser import loads, load
from .serialize import dumps, dump
from .config import ParserConfig, SerializerConfig

# Value type.
from .value import Value, Null

# Manual ser/de traits.
from .serialize import to_json_value, to_json_string, Serializable, serialize
from .deserialize import (
    get_string,
    get_int,
    get_bool,
    get_float,
    Deserializable,
    deserialize,
)

# Reflection serde (zero boilerplate).
from .reflection import (
    serialize_json,
    serialize_value,
    deserialize_json,
    deserialize_value,
    try_deserialize_json,
    JsonSerializable,
    JsonDeserializable,
)

# RFCs and queries.
from .patch import apply_patch, merge_patch, create_merge_patch
from .jsonpath import jsonpath_query, jsonpath_one
from .schema import validate, is_valid, ValidationResult, ValidationError

# Streaming/lazy parsing (CPU only).
from .lazy import LazyValue
from .streaming import StreamingParser, ArrayStreamingParser
