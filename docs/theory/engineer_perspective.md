# Engineer Perspective

A practitioner-oriented tour of major serialization **formats** and design trade-offs—text, schemaless binary, schema-driven, and language-native—with short historical notes and illustrative snippets.

This page is conceptual. Libraries and timings **in this suite** are on language **Overview** / **Results** pages and under [Benchmarks](../analysis/index.md) (including [Serialization Categories](../analysis/serialization_categories.md)).

We group formats the same way as the suite categories: **text (JSON family)**, **schemaless binary**, **schema-driven**, and **language-native**.

## Text-based formats

Early interchange used simple text (CSV, INI-like key–value). Need for structured, self-describing data produced richer text formats.

### XML (1996)

Developed under the W3C (Tim Bray, Jean Paoli, C. M. Sperberg-McQueen, and others) for document markup. Verbose, schema-optional, tree-shaped. Widely used for configuration and RPC (SOAP). Trade-offs: strong structure and tooling; size and parse cost are high compared with later formats.

### JSON (2001)

Specified and popularized by Douglas Crockford (with earlier ideas circulating in the JS community) for lightweight browser–server messaging. Human-readable objects and arrays derived from JavaScript syntax—no closing tags, compact relative to XML, optional schema (e.g. JSON Schema). Trade-offs: easy to parse and ubiquitous; no first-class binary or date types; schema is optional discipline, not built into the format.

```python
# Conceptual use of the standard library encoder (CPython json module style)
import json

payload = {"name": "Alice", "scores": [95, 87]}
text = json.dumps(payload, separators=(",", ":"), sort_keys=True)
obj = json.loads(text)
```

### YAML (2001–2004)

Clark Evans, Brian “Ingy” Ingerson, and Oren Ben-Kiki designed YAML as a human-friendly superset of JSON ideas—indentation-based structure, anchors/aliases, configs written by hand (Docker Compose, Kubernetes manifests). Trade-offs: highly readable; parsers are complex; careless loading of untrusted YAML has historically been a security risk.

```python
# Example with a modern YAML library (ruamel.yaml / ruyaml-style API)
from ruyaml import YAML
import sys

data = {
    "servers": [
        {"ip": "10.0.0.1", "role": "db"},
        {"ip": "10.0.0.2", "role": "web"},
    ]
}
yaml = YAML()
yaml.dump(data, sys.stdout)
```

### Other text formats

**TOML** (Tom Preston-Werner, 2013) for explicit config; classic **INI**; **EDN** (Clojure, Rich Hickey). Trend: reduce verbosity while staying human-editable; all pay text-parse cost and handle binary awkwardly (often base64).

## Schemaless binary formats

Text pays for characters and scanning. Distributed systems, caches, and IoT often prefer **binary** encodings of JSON-like values without a mandatory IDL.

### ASN.1 and XDR (1980s)

ASN.1 (telecom / ITU-T) and Sun **XDR** (NFS, RPC) defined binary structured encodings with explicit type/length conventions long before JSON. Powerful and portable across endianness when libraries comply; historically complex.

### MessagePack (2008)

Sadayuki Furuhashi’s “JSON but fast and small”: maps, arrays, numbers, strings, binaries with type tags and no field-name quotes. Wide language support. Trade-offs: compact and fast vs JSON; still schemaless (validation is your job).

```python
import msgpack

packed = msgpack.packb({"nums": [1, 2, 3]})
print(msgpack.unpackb(packed))  # {'nums': [1, 2, 3]}
```

### BSON (2009)

MongoDB’s Binary JSON (Dwight Merriman, Eliot Horowitz, et al.): length prefixes and extra types (binary, Date). Trade-offs: natural for document DBs; still carries field names, so not minimal.

### CBOR (2013)

IETF **RFC 7049 / 8949** (Carsten Bormann, Paul Hoffman): concise binary objects for constrained code size and extensibility (tags for dates, etc.). Trade-offs: similar niche to MessagePack with a standards track and richer typing tags.

### Other schemaless binary

UBJSON, Smile, and various RPC binary protocols. General theme: drop human readability for size and speed; remain dynamic unless you add schemas elsewhere.

## Schema-driven formats

Microservices, RPC, and durable storage often use an **IDL or schema**, codegen, and compact binary layouts.

### Protocol Buffers (open-sourced 2008)

Google’s IDL + codegen (design lineage including Sanjay Ghemawat, Jeff Dean, Kenton Varda, and many others). Fields tagged by number; no field names on the wire. Trade-offs: very efficient; requires schema discipline and careful evolution.

```python
# After protoc generates addressbook_pb2 (illustrative)
import addressbook_pb2

person = addressbook_pb2.Person()
person.id = 1234
person.name = "Alice"
data = person.SerializeToString()
person2 = addressbook_pb2.Person()
person2.ParseFromString(data)
```

### Apache Thrift (2007)

Facebook → Apache: IDL, codegen, and pluggable transports/protocols (binary, compact, JSON). Built with RPC in mind. Trade-offs: flexible stack; historical unevenness across language implementations.

### Apache Avro (~2009)

Doug Cutting and the Hadoop ecosystem: JSON schemas, compact binary data, schema often embedded in container files or registries—strong story for **schema evolution** in data pipelines. Trade-offs: schema management is central; excellent for row-oriented big-data interchange.

### Cap’n Proto (2013) and FlatBuffers (2014)

Kenton Varda’s Cap’n Proto and Wouter van Oortmerssen’s FlatBuffers (Google) pursue **zero-copy / low-parse** access with IDL-defined layouts. Trade-offs: excellent read performance and memory characteristics; mutation and tooling differ from classic Protobuf-style builders.

### Other schema-oriented systems

SBE (finance), Amazon Ion, and related designs balance size, speed, and flexibility differently. Static schemas generally buy efficiency and compatibility rules at the cost of upfront design.

## Language-native serializers

Portable formats aside, many runtimes ship **native** object graphs:

| Ecosystem | Example | Notes |
|-----------|---------|--------|
| Python | `pickle` / `cloudpickle` | Very flexible; **unsafe** on untrusted data; not cross-language |
| Java | `Serializable`, Kryo, etc. | Convenience within the JVM; long-term storage needs care |
| .NET | BinaryFormatter (legacy), etc. | Runtime-coupled; prefer portable formats for interchange |
| Others | Ruby Marshal, Erlang ETF, … | Same-process / same-stack use cases |

Trade-offs: convenience and rich graphs vs trust boundaries, version coupling, and poor multi-language interoperability. Prefer explicit portable formats when data leaves the trust or language boundary.

## Key contributors and timeline (selected)

| Who / org | Contribution |
|-----------|----------------|
| Tim Bray et al. | XML (W3C) |
| Douglas Crockford | JSON popularization / specification |
| Evans, Ingerson, Ben-Kiki | YAML |
| Sadayuki Furuhashi | MessagePack |
| Bormann & Hoffman | CBOR (IETF) |
| Ghemawat, Dean, Varda, et al. | Protocol Buffers; Varda later Cap’n Proto |
| Facebook / Apache | Thrift |
| Doug Cutting / Hadoop | Avro |
| Wouter van Oortmerssen | FlatBuffers |
| Standards bodies & vendors | ASN.1, XDR, Ion, SBE, … |

Many others in IETF, ECMA, and industry labs shaped encodings for specific constraints (telecom, web, big data, games).

## References

- Crockford / RFCs on JSON (e.g. RFC 8259)
- YAML 1.0 and later specs (Evans, Ingerson, Ben-Kiki, et al.)
- MessagePack specification and implementations
- CBOR: RFC 7049, RFC 8949
- Protocol Buffers documentation and open-source history (Google)
- Apache Thrift and Apache Avro project docs
- Cap’n Proto and FlatBuffers project documentation
- Language docs for pickle, Java serialization, etc.

For suite-specific inventories and measured performance, use [Serialization Categories](../analysis/serialization_categories.md) and language **Results**, not this page.
