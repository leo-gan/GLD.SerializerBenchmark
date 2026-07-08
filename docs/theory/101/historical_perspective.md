# Historical Perspective

## The problem that never goes away

Programs hold **rich in-memory structure**: nested records, arrays, graphs of objects, different integer widths, and different byte orders. Disks, networks, and many caches only store **linear sequences of bytes**.

[Serialization](https://en.wikipedia.org/wiki/Serialization "Serialization — converting structures to a byte sequence and back")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> is the durable answer to: *how do we flatten meaning into bytes and recover it later—possibly on another machine, in another language, years later?*

Every major format is a bet on which constraints matter most at the time: human readability, portability across CPUs, schema evolution, CPU cost, memory pressure, or analytics I/O. History is the story of those bets.

---

## Era map

| Years | Era | Dominant pressure | Representative answers |
|-------|-----|-------------------|------------------------|
| 1950s–1960s | Physical & fixed records | Media limits; batch business data | [Punched cards](https://en.wikipedia.org/wiki/Punched_card "Punched card — early physical data medium")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [COBOL](https://en.wikipedia.org/wiki/COBOL "COBOL — Common Business-Oriented Language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> fixed-width records; raw memory dumps |
| 1970s–1980s | Network portability | Heterogeneous machines on one network | Network byte order; [XDR](https://en.wikipedia.org/wiki/External_Data_Representation "XDR — External Data Representation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [ASN.1](https://en.wikipedia.org/wiki/ASN.1 "ASN.1 — Abstract Syntax Notation One")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> |
| Late 1980s–1990s | Distributed objects | Object graphs; “call a method elsewhere” | [CORBA](https://en.wikipedia.org/wiki/Common_Object_Request_Broker_Architecture "CORBA — Common Object Request Broker Architecture")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> [IDL](https://en.wikipedia.org/wiki/Interface_description_language "IDL — Interface Description Language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; Java / Python native serialization |
| Mid-1990s–early 2000s | Universal documents | Web-scale multi-vendor interchange | [XML](https://en.wikipedia.org/wiki/XML "XML — Extensible Markup Language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [SOAP](https://en.wikipedia.org/wiki/SOAP "SOAP — Simple Object Access Protocol")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> stack |
| 2000s–2010s | Lightweight web data | Browser & API simplicity | [JSON](https://en.wikipedia.org/wiki/JSON "JSON — JavaScript Object Notation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [REST](https://en.wikipedia.org/wiki/REST "REST — Representational State Transfer")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-style APIs |
| Mid-2000s onward | Efficient services & storage | Datacenter cost; long-lived data | [Protobuf](https://en.wikipedia.org/wiki/Protocol_Buffers "Protocol Buffers — Google schema-driven binary format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [Thrift](https://en.wikipedia.org/wiki/Apache_Thrift "Apache Thrift — IDL and RPC framework")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [MessagePack](https://en.wikipedia.org/wiki/MessagePack "MessagePack — binary serialization of JSON-like values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />/[BSON](https://en.wikipedia.org/wiki/BSON "BSON — Binary JSON (MongoDB)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />/[CBOR](https://en.wikipedia.org/wiki/CBOR "CBOR — Concise Binary Object Representation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [Avro](https://en.wikipedia.org/wiki/Apache_Avro "Apache Avro — row-oriented binary with schemas")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> |
| 2010s onward | Analytics & zero-copy | Scan huge tables; avoid copy/[GC](https://en.wikipedia.org/wiki/Garbage_collection_%28computer_science%29 "Garbage collection — automatic memory reclamation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> | [Parquet](https://en.wikipedia.org/wiki/Apache_Parquet "Apache Parquet — columnar storage format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />/[ORC](https://en.wikipedia.org/wiki/Apache_ORC "Apache ORC — Optimized Row Columnar")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [Arrow](https://en.wikipedia.org/wiki/Apache_Arrow "Apache Arrow — in-memory columnar format")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [FlatBuffers](https://en.wikipedia.org/wiki/FlatBuffers "FlatBuffers — zero-copy serialization library")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; [Cap’n Proto](https://en.wikipedia.org/wiki/Cap%27n_Proto "Cap’n Proto — zero-copy serialization and RPC")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> |
| ~2015 onward | Validation as product | Correctness of dynamic JSON at scale | [JSON Schema](https://en.wikipedia.org/wiki/JSON#Schema_and_metadata "JSON Schema — vocabulary for annotating and validating JSON")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; typed validators (e.g. Pydantic, msgspec) |

You do not need to memorize every name. Learn the **pressure → response** pattern.

---

## 1950s–1960s: Physical media & fixed contracts

Early “serialization” was often **the medium itself**. **[Herman Hollerith](https://en.wikipedia.org/wiki/Herman_Hollerith "Herman Hollerith — inventor of punched-card tabulation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**’s punched cards (1890 census technology, still central mid-century) encoded values as hole patterns in fixed columns. The layout *was* the format.

When magnetic tape and disk arrived, two durable ideas competed:

1. **Raw memory image** — write the bytes exactly as the CPU lays them out ([FORTRAN](https://en.wikipedia.org/wiki/Fortran "Fortran — early scientific programming language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-era binary I/O). Fast on one machine; useless or wrong on another word size or [endianness](https://en.wikipedia.org/wiki/Endianness "Endianness — byte order of multi-byte values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />.
2. **Explicit record layout** — declare field widths and types once (COBOL `DATA DIVISION` fixed-width records). Any program that shares the layout can read the bytes. Interoperable, rigid: insert a field and every reader must change or mis-parse the rest of the record.

**Lesson still true today:** a format is a **writer–reader contract**. The simpler and more positional the layout, the harder it is to extend without breaking old readers.

---

## 1970s–1980s: Networks force canonical forms

Connecting incompatible architectures ([PDP-11](https://en.wikipedia.org/wiki/PDP-11 "PDP-11 — influential minicomputer architecture")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> little-endian, IBM big-endian, and later Intel vs Motorola worlds) made ad-hoc binary dumps a liability. A multi-byte integer that means `1` on one host can mean millions on another if byte order differs.

**[Danny Cohen](https://en.wikipedia.org/wiki/Danny_Cohen_%28engineer%29 "Danny Cohen — computer scientist; endianness essay")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**’s 1980 essay *On Holy Wars and a Plea for Peace* popularized “endian” as a network problem and argued for a single **network byte order** (big-endian) for interchange—arbitrary, but shared.

Three threads answered “structured data on the wire” and how to call remote code:

### 1984: ASN.1

Telecom and [ISO](https://en.wikipedia.org/wiki/International_Organization_for_Standardization "ISO — International Organization for Standardization")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> standards defined **ASN.1** (formalized mid-1980s) abstract types plus encoding rules (notably [BER](https://en.wikipedia.org/wiki/X.690 "BER/DER — ASN.1 encoding rules (X.690)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />/[DER](https://en.wikipedia.org/wiki/X.690 "DER — Distinguished Encoding Rules (ASN.1)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />). **[Type–Length–Value (TLV)](https://en.wikipedia.org/wiki/Type%E2%80%93length%E2%80%93value "TLV — Type–Length–Value encoding structure")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** encoding lets a parser skip unknown pieces—an early, powerful approach to **extensibility**. DER-encoded structures still sit under [HTTPS](https://en.wikipedia.org/wiki/HTTPS "HTTPS — HTTP over TLS")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> certificates ([X.509](https://en.wikipedia.org/wiki/X.509 "X.509 — public key certificate standard")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />) and other infrastructure.

### 1984: RPC as an idea

**Birrell & [Nelson](https://en.wikipedia.org/wiki/Bruce_Jay_Nelson "Bruce Jay Nelson — co-author of “Implementing Remote Procedure Calls”")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**’s work on remote procedure calls formalized a pattern that never left the industry: describe the interface once, **generate** marshal/unmarshal code, make the network call *feel* like a local call. CORBA, `protoc`, Thrift, and [gRPC](https://en.wikipedia.org/wiki/GRPC "gRPC — high-performance RPC framework (often with Protobuf)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> are descendants of that DNA.

### 1987: XDR

Sun’s **XDR** (External Data Representation; RFC 1014, later RFC 4506) powered [NFS](https://en.wikipedia.org/wiki/Network_File_System "NFS — Network File System")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> and Sun [RPC](https://en.wikipedia.org/wiki/Remote_procedure_call "RPC — Remote Procedure Call")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />: fixed alignment rules, big-endian integers, length-prefixed strings and arrays. Portable and efficient for its time; **not self-describing**—you needed the agreed procedure/types (often an `.x` description) to interpret the stream.

**Lesson:** networks demand a **canonical** representation and push industry toward **IDL + generated codecs**.

---

## Late 1980s–1990s: Objects & native graphs

Object-oriented runtimes introduced **graphs**: shared references, cycles, inheritance. Flat records and simple RPC structs were not enough for “save this object and restore it later in the same ecosystem.”

- **CORBA (1991)** — language-neutral IDL and binary [CDR](https://en.wikipedia.org/wiki/Common_Data_Representation "CDR — Common Data Representation (CORBA)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> on the wire; powerful, operationally heavy; declined as the web favored looser coupling.
- **Java serialization (1995)** — language work associated with **[James Gosling](https://en.wikipedia.org/wiki/James_Gosling "James Gosling — co-creator of the Java language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** and the Java platform; implement a marker interface; the runtime reflects fields. Ergonomic inside the [JVM](https://en.wikipedia.org/wiki/Java_virtual_machine "JVM — Java Virtual Machine")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />; **not portable** to other languages; versioning via `serialVersionUID` is brittle; **unsafe** on untrusted bytes (gadget chains → remote code execution).
- **Python** (created by **[Guido van Rossum](https://en.wikipedia.org/wiki/Guido_van_Rossum "Guido van Rossum — creator of Python")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**): **[pickle](https://en.wikipedia.org/wiki/Serialization#Python "pickle — Python’s built-in object serialization (see Serialization § Python)")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> (mid-1990s)** — opcode stream for a small VM; can reconstruct rich Python objects (and, with `cloudpickle`, many dynamic callables). Central to much scientific Python; **Python-only** and **unsafe** on untrusted input.

**Lesson:** language-native formats maximize convenience **inside one trust and language boundary**. They repeatedly fail as universal interchange and as a security boundary.

---

## Mid-1990s–2000s: The XML decade

The public web needed something **language-neutral, hierarchical, and human-inspectable**. **XML 1.0** ([W3C](https://en.wikipedia.org/wiki/World_Wide_Web_Consortium "W3C — World Wide Web Consortium")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, 1998; editors including **[Tim Bray](https://en.wikipedia.org/wiki/Tim_Bray "Tim Bray — co-editor of XML 1.0")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** and **[Jean Paoli](https://en.wikipedia.org/wiki/Jean_Paoli "Jean Paoli — co-editor of XML 1.0")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**, with roots in [SGML](https://en.wikipedia.org/wiki/Standard_Generalized_Markup_Language "SGML — Standard Generalized Markup Language")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />) wrapped data in named tags. Tooling exploded: [XSD](https://en.wikipedia.org/wiki/XML_Schema_%28W3C%29 "XSD — XML Schema Definition")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [XPath](https://en.wikipedia.org/wiki/XPath "XPath — query language for XML trees")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, [XSLT](https://en.wikipedia.org/wiki/XSLT "XSLT — XML transformations")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, namespaces.

Enterprise systems layered **SOAP** and the WS-\* stack on XML over [HTTP](https://en.wikipedia.org/wiki/HTTP "HTTP — Hypertext Transfer Protocol")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />: universal in theory, verbose and complex in practice. Parse cost and document weight became obvious at scale.

**Lesson:** **self-description and universality have real CPU and bandwidth costs.** The industry would spend the next decades trying to keep interoperability while shedding XML’s tax.

---

## 2000s–: JSON & the web API default

**[Douglas Crockford](https://en.wikipedia.org/wiki/Douglas_Crockford "Douglas Crockford — popularized JSON")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** named and popularized **JSON**—essentially [JavaScript](https://en.wikipedia.org/wiki/JavaScript "JavaScript — programming language of the web")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> object literal syntax as a data format—in the early 2000s (later RFC 4627 → RFC 8259 / ECMA-404). Minimal types (`null`, bool, number, string, array, object), trivial for browsers, good enough for most public APIs.

REST-style HTTP APIs (architectural style articulated by **[Roy Fielding](https://en.wikipedia.org/wiki/Roy_Fielding "Roy Fielding — co-author of HTTP/1.1; REST dissertation")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**) and mobile clients made JSON the default **public** interchange language. Limitations became part of everyday engineering:

- No standard date or binary type (conventions + [base64](https://en.wikipedia.org/wiki/Base64 "Base64 — binary-to-text encoding")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />).
- Numbers are not a full [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754 "IEEE 754 — floating-point arithmetic standard")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> taxonomy of int vs float.
- Schema is optional (later filled by **JSON Schema**, [OpenAPI](https://en.wikipedia.org/wiki/OpenAPI_Specification "OpenAPI — standard for HTTP API descriptions")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, and language validators).

**Lesson:** the “winning” format is often the one that minimizes **integration friction**, not the one that wins microbenchmarks.

---

## 2000s–2010s: Schema-driven binary efficiency

Inside large service meshes, repeating field names as text and parsing characters became a measurable **datacenter tax**.

### Early 2000s: Protocol Buffers

Google’s **Protocol Buffers** (internal early 2000s; open-sourced 2008; design lineage including work associated with **[Jeff Dean](https://en.wikipedia.org/wiki/Jeff_Dean "Jeff Dean — Google Fellow; large-scale systems")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**, **[Sanjay Ghemawat](https://en.wikipedia.org/wiki/Sanjay_Ghemawat "Sanjay Ghemawat — Google Fellow; systems co-designer")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />**, **Kenton Varda**, and many others) revived IDL + codegen with a compact binary encoding: **field numbers** instead of names, **varints**, and evolution rules centered on never reusing field numbers for different meanings. Opaque without the `.proto`; excellent for polyglot services that invest in schema discipline.

### 2007: Apache Thrift

Facebook’s **Thrift** (later Apache): IDL, multi-language codegen, pluggable protocols and transports—RPC-oriented flexibility in polyglot environments.

### ~2008–2013: Schemaless binary cousins

Not every team wanted a compiler in the loop:

| Format | Approx. | Intent |
|--------|---------|--------|
| **MessagePack** | ~2008 ([Sadayuki Furuhashi](https://en.wikipedia.org/wiki/Sadayuki_Furuhashi "Sadayuki Furuhashi — creator of MessagePack")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />) | JSON data model, binary tags, smaller/faster than text JSON |
| **BSON** | ~2009 ([MongoDB](https://en.wikipedia.org/wiki/MongoDB "MongoDB — document-oriented database")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />) | Document storage/wire types (dates, binary) with length prefixes |
| **CBOR** | 2013 (RFC 7049 / 8949) | Standards-track concise binary objects; strong [IoT](https://en.wikipedia.org/wiki/Internet_of_things "IoT — Internet of Things")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> / constrained-device story |

**Lesson:** once JSON locked the *data model* in people’s heads, the industry cloned that model into **binary** and reintroduced **schemas** where evolution and efficiency dominated.

---

## Late 2000s–2010s: Long-lived data & analytics

Batch and streaming platforms ([Hadoop](https://en.wikipedia.org/wiki/Apache_Hadoop "Apache Hadoop — distributed storage and MapReduce ecosystem")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> ecosystem and successors) needed formats that survive **years** of readers and writers coexisting.

- **Apache Avro** ([Doug Cutting](https://en.wikipedia.org/wiki/Doug_Cutting "Doug Cutting — creator of Lucene/Hadoop; Avro designer")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> et al., ~2009) — compact binary values; schema often travels with the data or lives in a **registry**; strong **schema resolution** story (defaults, reader/writer schema compatibility). Became a default mental model for event logs (e.g. [Kafka](https://en.wikipedia.org/wiki/Apache_Kafka "Apache Kafka — distributed event streaming platform")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> + registry patterns).
- **Columnar storage** — Google’s **[Dremel](https://en.wikipedia.org/wiki/Dremel_%28software%29 "Dremel — Google interactive analytic query system")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** paper (2010) popularized nested columnar layout for analytic queries that touch few columns of wide tables. **Apache Parquet** (open-sourced ~2013; Julien Le Dem, Nong Li, and community) and **ORC** made that idea the backbone of data lakes.
- **Apache Arrow** (from ~2016; [Wes McKinney](https://en.wikipedia.org/wiki/Wes_McKinney "Wes McKinney — creator of pandas; co-founder of Arrow")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> and co-founders/community) — standard **in-memory** columnar layout so systems can share tables with minimal or zero copy instead of endlessly converting.

**Lesson:** **transactional messaging** and **analytical scanning** optimize different layouts. History splits “messages on the wire” from “tables on disk / in memory.”

---

## 2010s: Zero-copy access

Even fast encode/decode still **copies** into language objects. Domains with tight latency or memory budgets (games, some telemetry, certain RPC paths) pushed further:

- **Cap’n Proto** (Kenton Varda, ~2013) — layout designed so the buffer *is* the in-memory form; encode/decode can approach a no-op for simple access patterns.
- **FlatBuffers** (Wouter van Oortmerssen, Google, ~2014) — similar zero-copy access goals with vtable-based optional fields; strong mobile/game heritage; also appears in [ML](https://en.wikipedia.org/wiki/Machine_learning "ML — Machine learning")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> runtime ecosystems.

**Trade-off theme:** less parse work often means more care around **validation**, mutability, and operational tooling (debugability, proxies, HTTP-centric infrastructure).

---

## Mid-2010s–present: Validation renaissance

Public and internal APIs stayed on JSON for reach, while teams paid for **ad-hoc validation**. The response was not a single new wire format but **schema as a product layer**:

- **JSON Schema** and **OpenAPI** — contracts and generated clients/servers for HTTP JSON.
- Runtime validators bound to language types (in Python, notably **Pydantic** and high-performance tools like **msgspec**) — treat annotations as schema, validate on the way in/out.

**Lesson:** schemaless popularity created demand for **optional, enforceable structure** without always switching the wire format.

---

## Tensions diagram

History does not converge on a single winner. It accumulates niches along recurring trade-offs:

| One pole | ↔ tension ↔ | Other pole |
|----------|-------------|------------|
| **Human-readable & universal** (JSON / XML) | | **Compact & CPU-cheap** (Protobuf / MessagePack / …) |
| **Flexible & ad hoc** (JSON / pickle / MessagePack) | | **Evolvable & explicit** (Avro / Protobuf + process) |
| **Whole-record access** (messages / documents) | | **Wide-table analytics** (Parquet / Arrow) |
| **Safe across trust boundaries** (portable + validated) | | **Max power in one runtime** (native pickle / Java serialization) |

---

## Using this history

1. When someone says “just use X,” ask **which pressure** they are optimizing (debug? polyglot? retention? scan speed? unsafe input?).
2. Prefer portable, explicit formats when data **crosses** a language or trust boundary.
3. Expect **multiple** formats in one organization: JSON at the edge, binary RPC inside, Parquet in the lake—that is historical normal, not failure.

---

## Selected references

These are entry points, not an exhaustive bibliography. Wikipedia articles for major formats appear on first mention above.

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
