---
title: "PHP"
---

# PHP

PHP serialization contrasts built-in C extensions (`ext-json`, native `serialize`), optional PECL C extensions (`igbinary`, `ext-msgpack`, `ext-yaml`, `ext-simdjson`, `ext-mongodb`), and pure-PHP Composer packages (`google/protobuf`, `Symfony`, `JMS`, `Avro`, `CBOR`, `TOON`, and pure-PHP MessagePack/YAML/Arrow/Ion).

## Runtime & Environment

The PHP runner executes as a single long-lived **CLI** process on the Zend opcode virtual machine rather than request-scoped PHP-FPM or Apache workers. Memory is managed by the Zend allocator with reference counting plus a cyclic garbage collector. Because C extensions bypass opcode execution in the Zend VM, PECL rows typically outperform pure-PHP packages by an order of magnitude or more. Language semantics follow the [PHP Language Reference](https://www.php.net/manual/en/langref.php).

| Property | Configuration |
|---|---|
| Language / spec | PHP 8.2+ (`composer.json`; install script provides static PHP 8.3 CLI) |
| Build & toolchain | Composer (`composer install`); protobuf stubs via `php/scripts/generate-protobuf.sh` |
| Memory model | Zend reference counting + cyclic garbage collector |
| Runner & logs | `php/scripts/run-benchmarks.sh` → `logs/php/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`php/src/Serializers/Registry.php`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/php/src/Serializers/Registry.php) |
| Data sets | `suite` |

## Registered Serializers

Optional PECL rows register only when their corresponding C extension is loaded in the host PHP binary.

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [avro](https://github.com/flix-tech/avro-php) | `avro` | `suite` | `adapted` | `flix-tech/avro-php` binary datum (no object container file) |
| [bson](https://github.com/mongodb/mongo-php-driver) | `bson` | `suite` (optional) | `adapted` | Official `ext-mongodb` BSON (PECL; skipped if unloaded) |
| [cbor](https://github.com/Spomky-Labs/cbor-php) | `cbor` | `suite` | `adapted` | `spomky-labs/cbor-php` RFC 8949 encoder/decoder |
| [gld-arrow](https://github.com/leo-gan/gld-arrow-php) | `arrow` | `suite` | `adapted` | `leo-gan/gld-arrow-php` 0.2.0 Arrow IPC stream |
| [gld-ion](https://github.com/leo-gan/gld-ion-php) | `ion` | `suite` | `adapted` | `leo-gan/gld-ion-php` 0.2.0 Ion 1.0 binary encode/decode |
| [igbinary](https://github.com/igbinary/igbinary) | `custom` | `suite` (optional) | `adapted` | `ext-igbinary` compact PHP binary (PECL; skipped if unloaded) |
| [jms-json](https://github.com/schmittjoh/serializer) | `json` | `suite` | `text_on_stream` | `jms/serializer` annotation-driven JSON encoder |
| [json](https://github.com/php/php-src/tree/master/ext/json) | `json` | `suite` | `text_on_stream` | Bundled C `ext-json` (`json_encode` / `json_decode`) |
| [msgpack-pecl](https://github.com/msgpack/msgpack-php) | `msgpack` | `suite` (optional) | `adapted` | `ext-msgpack` C extension (PECL; skipped if unloaded) |
| [protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite` | `adapted` | Official `google/protobuf` generated messages; version reports `+ext` vs. `+php` |
| [rybakit-msgpack](https://github.com/rybakit/msgpack.php) | `msgpack` | `suite` | `adapted` | Pure-PHP `rybakit/msgpack` userland baseline |
| [serialize](https://github.com/php/php-src) | `custom` | `suite` | `adapted` | Bundled PHP `serialize` / `unserialize` (PHP-only; unsafe on untrusted input) |
| [simdjson](https://github.com/crazyxman/simdjson_php) | `json` | `suite` (optional) | `text_on_stream` | `ext-simdjson` decode only; encode uses `json_encode` (PECL; skipped if unloaded) |
| [symfony-json](https://github.com/symfony/serializer) | `json` | `suite` | `text_on_stream` | `symfony/serializer` JSON encoder |
| [symfony-xml](https://github.com/symfony/serializer) | `custom` | `suite` | `text_on_stream` | `symfony/serializer` XML encoder |
| [toon](https://github.com/HelgeSverre/toon-php) | `toon` | `suite` | `adapted` | `helgesverre/toon` configured for TOON spec 4.4 (package default is 3.3); size in UTF-8 bytes |
| [yaml](https://github.com/symfony/yaml) | `yaml` | `suite` | `text_on_stream` | Pure-PHP `symfony/yaml` |
| [yaml-pecl](https://github.com/php/pecl-file_formats-yaml) | `yaml` | `suite` (optional) | `text_on_stream` | `ext-yaml` LibYAML C binding (PECL; skipped if unloaded) |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[avro](https://github.com/flix-tech/avro-php)** — flix-tech/avro-php is a PHP implementation of Apache Avro. Avro exists for compact, schema-driven records. This row times binary Avro (not the object container file format).
    - **[bson](https://github.com/mongodb/mongo-php-driver)** — BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.
    - **[cbor](https://github.com/Spomky-Labs/cbor-php)** — spomky-labs/cbor-php implements RFC 8949 CBOR in PHP. CBOR is the IETF binary JSON-like format. The library is a PHP encoder/decoder of that RFC.
    - **[gld-arrow](https://github.com/leo-gan/gld-arrow-php)** — gld-arrow-php (leo-gan) is a pure-PHP Apache Arrow IPC stream encoder and decoder supporting the five suite data types.
    - **[gld-ion](https://github.com/leo-gan/gld-ion-php)** — gld-ion-php (leo-gan) is a pure-PHP Amazon Ion 1.0 binary encoder and decoder supporting the five suite data types.
    - **[igbinary](https://github.com/igbinary/igbinary)** — igbinary is a PECL replacement for PHP `serialize` with a more compact binary. The problem was PHP's verbose native serializer in caches and sessions. igbinary drops duplicate strings and uses a denser layout.
    - **[jms-json](https://github.com/schmittjoh/serializer)** — JMS Serializer was created for PHP applications that needed annotation-driven object serialization (especially APIs). The problem was mapping rich object graphs to JSON. This row times the JSON encoder.
    - **[json](https://github.com/php/php-src/tree/master/ext/json)** — PHP's `json_encode` / `json_decode` are the language's standard JSON APIs. They exist so PHP can speak the web's data format without a package. This row times the bundled ext-json.
    - **[msgpack-pecl](https://github.com/msgpack/msgpack-php)** — ext-msgpack is the official PECL MessagePack extension for PHP. MessagePack exists as compact binary JSON. The C extension is the fast path versus userland MessagePack.
    - **[protobuf](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[rybakit-msgpack](https://github.com/rybakit/msgpack.php)** — rybakit/msgpack is a pure-PHP MessagePack implementation. MessagePack exists as compact binary JSON. This package is the userland baseline versus the PECL extension.
    - **[serialize](https://github.com/php/php-src)** — PHP `serialize` / `unserialize` is the language's native object format. It exists so PHP can persist values across requests. It is PHP-only and unsafe for untrusted input.
    - **[simdjson](https://github.com/crazyxman/simdjson_php)** — ext-simdjson binds the simdjson parser to PHP. simdjson was created to parse JSON at memory-bandwidth speeds. This row uses SIMD only for decode; encode is `json_encode`.
    - **[symfony-json](https://github.com/symfony/serializer)**, **[symfony-xml](https://github.com/symfony/serializer)** — The Symfony Serializer component was created so Symfony apps had a normalizer/encoder pipeline for JSON, XML, and more. The problem was ad-hoc `json_encode` of domain objects. This suite times the JSON and XML encoders.
    - **[toon](https://github.com/HelgeSverre/toon-php)** — helgesverre/toon encodes and decodes TOON in PHP. The package default wire version is 3.3. This row selects specification 4.4. The timed path is Toon::encode and Toon::decode. The Size column is the UTF-8 byte length.
    - **[yaml](https://github.com/symfony/yaml)** — The Symfony YAML component is a pure-PHP YAML parser/dumper. YAML exists as a human-friendly config language. Symfony YAML is the common userland implementation in PHP apps.
    - **[yaml-pecl](https://github.com/php/pecl-file_formats-yaml)** — ext-yaml is the PECL binding to LibYAML. YAML exists as a human-friendly config language. The extension is the C-speed path versus Symfony's pure-PHP YAML.

## Measurement Caveats

- **Static CLI host without PECL:** The default host install script provides a static PHP 8.3 CLI built without PECL extensions (`igbinary`, `msgpack`, `yaml`, `simdjson`, `mongodb`). Those five rows are therefore absent from default Dashboard snapshots until run on a PHP build with those extensions enabled. Similarly, `google/protobuf` appends `+ext` or `+php` to `SerializerVersion` to distinguish the C extension from the pure-PHP runtime.
- **`simdjson` split path:** When loaded, `ext-simdjson` accelerates decode only; timed encode falls back to `json_encode`.
- **Excluded candidates:** RPC framers (`Goridge`/`RoadRunner`), closure serializers (`opis/closure`, `laravel/serializable-closure`), decode-only parsers (`salsify/jsonstreamingparser`), line-delimited streams (`clue/ndjson`), flat CSV (`Symfony CSV`), framework hydrators (`laravel-data`, `PDO`), and ungenerated IDL targets (`Cap'n Proto`, `FlatBuffers`, `Thrift`) are excluded.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (PHP)](../dashboard/index.html?lang=php&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (PHP)](../dashboard/index.html#compliance)
- **Source-level analyses:** [PHP: `json` vs. `google/protobuf`](../analysis/call-sites/php-json-vs-protobuf.md)
- **Build & run guide:** [`php/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/php/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
