# Historical Perspective

**Question this page answers:** *Why do serialization formats exist in the shapes they do?*

This is Module 1 of [Serialization 101](index.md). It is a single chronological narrative—constraints, people, and paradigm shifts. It is **not** a how-to for data lakes or production services. For those, use the [data science](data_science_perspective.md) and [engineering](engineer_perspective.md) perspectives.

---

## The problem that never goes away

Programs hold **rich in-memory structure**: nested records, arrays, graphs of objects, different integer widths, and different byte orders. Disks, networks, and many caches only store **linear sequences of bytes**.

Serialization is the durable answer to: *how do we flatten meaning into bytes and recover it later—possibly on another machine, in another language, years later?*

Every major format is a bet on which constraints matter most at the time: human readability, portability across CPUs, schema evolution, CPU cost, memory pressure, or analytics I/O. History is the story of those bets.

---

## Era map (quick orientation)

| Era | Approx. | Dominant pressure | Representative answers |
|-----|---------|-------------------|------------------------|
| Physical & fixed records | 1950s–1960s | Media limits; batch business data | Punched cards; COBOL fixed-width records; raw memory dumps |
| Network portability | 1970s–1980s | Heterogeneous machines on one network | Network byte order; XDR; ASN.1 |
| Distributed objects | Late 1980s–1990s | Object graphs; “call a method elsewhere” | CORBA IDL; Java / Python native serialization |
| Universal documents | Mid-1990s–early 2000s | Web-scale multi-vendor interchange | XML; SOAP stack |
| Lightweight web data | 2000s–2010s | Browser & API simplicity | JSON; REST-style APIs |
| Efficient services & storage | Mid-2000s onward | Datacenter cost; long-lived data | Protobuf, Thrift; MessagePack/BSON/CBOR; Avro |
| Analytics & zero-copy | 2010s onward | Scan huge tables; avoid copy/GC | Parquet/ORC; Arrow; FlatBuffers; Cap’n Proto |
| Validation as product | ~2015 onward | Correctness of dynamic JSON at scale | JSON Schema; typed validators (e.g. Pydantic, msgspec) |

You do not need to memorize every name. Learn the **pressure → response** pattern.

---

## 1. Physical media and fixed contracts (1950s–1960s)

Early “serialization” was often **the medium itself**. **Herman Hollerith**’s punched cards (1890 census technology, still central mid-century) encoded values as hole patterns in fixed columns. The layout *was* the format.

When magnetic tape and disk arrived, two durable ideas competed:

1. **Raw memory image** — write the bytes exactly as the CPU lays them out (FORTRAN-era binary I/O). Fast on one machine; useless or wrong on another word size or endianness.
2. **Explicit record layout** — declare field widths and types once (COBOL `DATA DIVISION` fixed-width records). Any program that shares the layout can read the bytes. Interoperable, rigid: insert a field and every reader must change or mis-parse the rest of the record.

**Lesson still true today:** a format is a **writer–reader contract**. The simpler and more positional the layout, the harder it is to extend without breaking old readers.

---

## 2. Networks force canonical forms (1970s–1980s)

Connecting incompatible architectures (PDP-11 little-endian, IBM big-endian, and later Intel vs Motorola worlds) made ad-hoc binary dumps a liability. A multi-byte integer that means `1` on one host can mean millions on another if byte order differs.

**Danny Cohen**’s 1980 essay *On Holy Wars and a Plea for Peace* popularized “endian” as a network problem and argued for a single **network byte order** (big-endian) for interchange—arbitrary, but shared.

Two standardization traditions answered “structured data on the wire”:

### XDR (External Data Representation, 1987)

Sun’s XDR (RFC 1014, later RFC 4506) powered NFS and Sun RPC: fixed alignment rules, big-endian integers, length-prefixed strings and arrays. Portable and efficient for its time; **not self-describing**—you needed the agreed procedure/types (often an `.x` description) to interpret the stream.

### ASN.1 (mid-1980s)

Telecom and ISO standards defined **ASN.1** abstract types plus encoding rules (notably BER/DER). **Type–Length–Value (TLV)** encoding lets a parser skip unknown pieces—an early, powerful approach to **extensibility**. DER-encoded structures still sit under HTTPS certificates (X.509) and other infrastructure.

### RPC as an idea (1984)

**Birrell & Nelson**’s work on remote procedure calls formalized a pattern that never left the industry: describe the interface once, **generate** marshal/unmarshal code, make the network call *feel* like a local call. CORBA, `protoc`, Thrift, and gRPC are descendants of that DNA.

**Lesson:** networks demand a **canonical** representation and push industry toward **IDL + generated codecs**.

---

## 3. Objects and language-native graphs (late 1980s–1990s)

Object-oriented runtimes introduced **graphs**: shared references, cycles, inheritance. Flat records and simple RPC structs were not enough for “save this object and restore it later in the same ecosystem.”

- **CORBA (1991)** — language-neutral IDL and binary CDR on the wire; powerful, operationally heavy; declined as the web favored looser coupling.
- **Java serialization (1995)** — implement a marker interface; the runtime reflects fields. Ergonomic inside the JVM; **not portable** to other languages; versioning via `serialVersionUID` is brittle; **unsafe** on untrusted bytes (gadget chains → remote code execution).
- **Python `pickle` (mid-1990s)** — opcode stream for a small VM; can reconstruct rich Python objects (and, with `cloudpickle`, many dynamic callables). Central to much scientific Python; **Python-only** and **unsafe** on untrusted input.

**Lesson:** language-native formats maximize convenience **inside one trust and language boundary**. They repeatedly fail as universal interchange and as a security boundary.

---

## 4. The XML decade (mid-1990s–early 2000s)

The public web needed something **language-neutral, hierarchical, and human-inspectable**. **XML 1.0** (W3C, 1998; editors including **Tim Bray** and **Jean Paoli**, with roots in SGML) wrapped data in named tags. Tooling exploded: XSD, XPath, XSLT, namespaces.

Enterprise systems layered **SOAP** and the WS-\* stack on XML over HTTP: universal in theory, verbose and complex in practice. Parse cost and document weight became obvious at scale.

**Lesson:** **self-description and universality have real CPU and bandwidth costs.** The industry would spend the next decades trying to keep interoperability while shedding XML’s tax.

---

## 5. JSON and the web API default (2000s–)

**Douglas Crockford** named and popularized **JSON**—essentially JavaScript object literal syntax as a data format—in the early 2000s (later RFC 4627 → RFC 8259 / ECMA-404). Minimal types (`null`, bool, number, string, array, object), trivial for browsers, good enough for most public APIs.

REST-style HTTP APIs and mobile clients made JSON the default **public** interchange language. Limitations became part of everyday engineering:

- No standard date or binary type (conventions + base64).
- Numbers are not a full IEEE taxonomy of int vs float.
- Schema is optional (later filled by **JSON Schema**, OpenAPI, and language validators).

**Lesson:** the “winning” format is often the one that minimizes **integration friction**, not the one that wins microbenchmarks.

---

## 6. Datacenter efficiency and schema-driven binary (2000s–2010s)

Inside large service meshes, repeating field names as text and parsing characters became a measurable **datacenter tax**.

### Protocol Buffers

Google’s **Protocol Buffers** (internal early 2000s; open-sourced 2008; design lineage including work associated with **Jeff Dean**, **Sanjay Ghemawat**, **Kenton Varda**, and many others) revived IDL + codegen with a compact binary encoding: **field numbers** instead of names, **varints**, and evolution rules centered on never reusing field numbers for different meanings. Opaque without the `.proto`; excellent for polyglot services that invest in schema discipline.

### Apache Thrift (2007)

Facebook’s **Thrift** (later Apache): IDL, multi-language codegen, pluggable protocols and transports—RPC-oriented flexibility in polyglot environments.

### Schemaless binary “JSON cousins”

Not every team wanted a compiler in the loop:

| Format | Approx. | Intent |
|--------|---------|--------|
| **MessagePack** | ~2008 (Sadayuki Furuhashi) | JSON data model, binary tags, smaller/faster than text JSON |
| **BSON** | ~2009 (MongoDB) | Document storage/wire types (dates, binary) with length prefixes |
| **CBOR** | 2013 (RFC 7049 / 8949) | Standards-track concise binary objects; strong IoT / constrained-device story |

**Lesson:** once JSON locked the *data model* in people’s heads, the industry cloned that model into **binary** and reintroduced **schemas** where evolution and efficiency dominated.

---

## 7. Long-lived data and analytics (late 2000s–2010s)

Batch and streaming platforms (Hadoop ecosystem and successors) needed formats that survive **years** of readers and writers coexisting.

- **Apache Avro** (Doug Cutting et al., ~2009) — compact binary values; schema often travels with the data or lives in a **registry**; strong **schema resolution** story (defaults, reader/writer schema compatibility). Became a default mental model for event logs (e.g. Kafka + registry patterns).
- **Columnar storage** — Google’s **Dremel** paper (2010) popularized nested columnar layout for analytic queries that touch few columns of wide tables. **Apache Parquet** (open-sourced ~2013; Julien Le Dem, Nong Li, and community) and **ORC** made that idea the backbone of data lakes.
- **Apache Arrow** (from ~2016; Wes McKinney and co-founders/community) — standard **in-memory** columnar layout so systems can share tables with minimal or zero copy instead of endlessly converting.

**Lesson:** **transactional messaging** and **analytical scanning** optimize different layouts. History splits “messages on the wire” from “tables on disk / in memory.”

---

## 8. Zero-copy access (2010s)

Even fast encode/decode still **copies** into language objects. Domains with tight latency or memory budgets (games, some telemetry, certain RPC paths) pushed further:

- **Cap’n Proto** (Kenton Varda, ~2013) — layout designed so the buffer *is* the in-memory form; encode/decode can approach a no-op for simple access patterns.
- **FlatBuffers** (Wouter van Oortmerssen, Google, ~2014) — similar zero-copy access goals with vtable-based optional fields; strong mobile/game heritage; also appears in ML runtime ecosystems.

**Trade-off theme:** less parse work often means more care around **validation**, mutability, and operational tooling (debugability, proxies, HTTP-centric infrastructure).

---

## 9. Validation renaissance (mid-2010s–present)

Public and internal APIs stayed on JSON for reach, while teams paid for **ad-hoc validation**. The response was not a single new wire format but **schema as a product layer**:

- **JSON Schema** and **OpenAPI** — contracts and generated clients/servers for HTTP JSON.
- Runtime validators bound to language types (in Python, notably **Pydantic** and high-performance tools like **msgspec**) — treat annotations as schema, validate on the way in/out.

**Lesson:** schemaless popularity created demand for **optional, enforceable structure** without always switching the wire format.

---

## One diagram of the tensions

History does not converge on a single winner. It accumulates niches:

```text
Human-readable & universal     ←—— tension ——→     Compact & CPU-cheap
        JSON / XML                                    Protobuf / msgpack / …

Flexible & ad hoc              ←—— tension ——→     Evolvable & explicit
     JSON / pickle / msgpack                          Avro / Protobuf + process

Whole-record access            ←—— tension ——→     Wide-table analytics
     messages / documents                             Parquet / Arrow

Safe across trust boundaries   ←—— tension ——→     Max power in one runtime
     portable + validated                             native pickle / Java ser.
```

---

## How to use this history in practice

1. When someone says “just use X,” ask **which pressure** they are optimizing (debug? polyglot? retention? scan speed? unsafe input?).
2. Prefer portable, explicit formats when data **crosses** a language or trust boundary.
3. Expect **multiple** formats in one organization: JSON at the edge, binary RPC inside, Parquet in the lake—that is historical normal, not failure.
4. For *what to pick for data/ML* or *how to ship services*, leave this page:
   - [Data science perspective](data_science_perspective.md)
   - [Engineering perspective](engineer_perspective.md)
   - [Serialization categories](../analysis/serialization_categories.md) (suite taxonomy)
   - [Benchmarks](../analysis/index.md) (measured behavior)

---

## Selected references

These are entry points, not an exhaustive bibliography.

1. Cohen, D. (1980). “On Holy Wars and a Plea for Peace.” *IEEE Computer*.
2. Sun Microsystems / IETF. *XDR* — RFC 1014; RFC 4506.
3. ITU-T / ISO. *ASN.1* (e.g. X.680 and related encoding rules).
4. Birrell, A. D., & Nelson, B. J. (1984). “Implementing Remote Procedure Calls.” *ACM TOCS*.
5. Bray, T., et al. *Extensible Markup Language (XML) 1.0*. W3C.
6. Bray, T. (Ed.). *The JavaScript Object Notation (JSON) Data Interchange Format* — RFC 8259.
7. Fielding, R. T. (2000). *Architectural Styles and the Design of Network-Based Software Architectures* (REST).
8. Google Protocol Buffers documentation and open-source history.
9. Slee, M., Agarwal, A., & Kwiatkowski, M. (2007). *Thrift* white paper; Apache Thrift project.
10. Apache Avro, Parquet, and Arrow project documentation.
11. Bormann, C., & Hoffman, P. *CBOR* — RFC 7049; RFC 8949.
12. Cap’n Proto and FlatBuffers project documentation.
13. Kleppmann, M. (2017). *Designing Data-Intensive Applications*. O’Reilly. (Formats in real systems.)
14. MessagePack specification; MongoDB BSON specification.

---

**Next:** choose your applied lens — [data science](data_science_perspective.md) or [engineering](engineer_perspective.md) — or return to the [course home](index.md).
