---
title: "PHP"
---

PHP
===

PHP’s suite rows cover **stdlib JSON**, **native `serialize`**, optional **PECL** binaries (igbinary, MessagePack, LibYAML, SIMDJSON, MongoDB BSON), **official google/protobuf**, **Symfony** and **JMS** JSON (plus Symfony XML), **Avro**, **CBOR**, and **pure-PHP MessagePack / YAML** as userland baselines.

## Runtime

### What it is

PHP is often described as a language for web pages. This suite runs the **CLI** (command-line) binary, not PHP-FPM or Apache. The engine is **Zend**. It compiles a script to opcodes, which are an intermediate instruction set, and then executes those opcodes. The short, request-scoped life cycle of a web page does not apply here. One process runs many timed repetitions.

| | This suite |
|---|---|
| Language | PHP **8.2 or newer** (`composer.json`). The install script offers a static **8.3** CLI. |
| Packages | Composer (`composer install`) |
| Prepare | `./scripts/install-host-requirements.sh php` installs into `~/.local/php` |
| Run | `php/scripts/run-benchmarks.sh` |
| Memory | Zend allocator, plus a garbage collector for cyclic structures |

### What this suite runs

The install script’s static CLI is built **without PECL extensions**. PECL is the usual way to add C extensions such as `igbinary`, `msgpack`, `yaml`, `simdjson`, and `mongodb` to PHP. Those rows register only when the matching extension is actually loaded. A missing row on the Dashboard often means this PHP binary was built without that extension. It does not mean the library is slow.

### What changes the numbers

PECL and other C extensions are typically much faster than pure-PHP packages such as `rybakit/msgpack` and `symfony/yaml`. `google/protobuf` reports `+ext` or `+php` in the version column, depending on which implementation loaded. The built-in `serialize` format works only in PHP.

### Suite-specific gotchas

A host that has the PECL rows and a host that does not are not the same matrix. Compare them only after you know which extensions were loaded.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`php/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/php/README.md). The language overview is [What is PHP?](https://www.php.net/manual/en/intro-whatis.php).

## Benchmark runner

- Directory: `php/` (repository root)
- Output: `logs/php/YYYY-MM-DD-HHMMSS.csv` (`Language=php`, times in **nanoseconds**)
- Runner: `php/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: `php/src/Serializers/Registry.php`
- Protobuf classes: `php/scripts/generate-protobuf.sh` (from `schemas/v2/protobuf/benchmark_v2.proto`)

PECL rows register only when the extension is loaded. This host’s static PHP CLI has none of those extensions, so those rows stay dark until `igbinary` / `msgpack` / `yaml` / `simdjson` / `mongodb` are present.

## Serializers

| Name | Category | Package | Stream | Notes |
|------|----------|---------|--------|-------|
| [json](https://github.com/php/php-src/tree/master/ext/json) | JSON | php-json | text_on_stream | `json_encode` / `json_decode` |
| [simdjson](https://github.com/crazyxman/simdjson_php) | JSON | ext-simdjson | text_on_stream | **Decode only** is SIMDJSON; encode is `json_encode` |
| [serialize](https://github.com/php/php-src) | Binary | php-serialize | adapted | PHP-only |
| [igbinary](https://github.com/igbinary/igbinary) | Binary | ext-igbinary | adapted | PECL; skip if missing |
| [msgpack-pecl](https://github.com/msgpack/msgpack-php) | Binary | ext-msgpack | adapted | PECL; skip if missing |
| [rybakit-msgpack](https://github.com/rybakit/msgpack.php) | Binary | rybakit/msgpack | adapted | Pure PHP MessagePack |
| [protobuf](https://github.com/protocolbuffers/protobuf) | Schema | google/protobuf | adapted | Official generated messages; `+ext` vs `+php` in version |
| [symfony-json](https://github.com/symfony/serializer) | JSON | symfony/serializer | text_on_stream | Serializer JSON encoder |
| [symfony-xml](https://github.com/symfony/serializer) | Text | symfony/serializer | text_on_stream | Serializer XML encoder |
| [jms-json](https://github.com/schmittjoh/serializer) | JSON | jms/serializer | text_on_stream | JMS JSON |
| [bson](https://github.com/mongodb/mongo-php-driver) | Binary | ext-mongodb | adapted | Official BSON; skip if missing |
| [avro](https://github.com/flix-tech/avro-php) | Schema | flix-tech/avro-php | adapted | Binary Avro (no object container) |
| [cbor](https://github.com/Spomky-Labs/cbor-php) | Binary | spomky-labs/cbor-php | adapted | RFC 8949 |
| [yaml](https://github.com/symfony/yaml) | Text | symfony/yaml | text_on_stream | Pure PHP YAML |
| [yaml-pecl](https://github.com/php/pecl-file_formats-yaml) | Text | ext-yaml | text_on_stream | LibYAML; skip if missing |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [json](https://github.com/php/php-src/tree/master/ext/json) · `8.3.19`

PHP's `json_encode` / `json_decode` are the language's standard JSON APIs. They exist so PHP can speak the web's data format without a package. This row times the bundled ext-json.

#### [simdjson](https://github.com/crazyxman/simdjson_php)

ext-simdjson binds the simdjson parser to PHP. simdjson was created to parse JSON at memory-bandwidth speeds. This row uses SIMD only for decode; encode is `json_encode`.

#### [serialize](https://github.com/php/php-src) · `8.3.19`

PHP `serialize` / `unserialize` is the language's native object format. It exists so PHP can persist values across requests. It is PHP-only and unsafe for untrusted input.

#### [igbinary](https://github.com/igbinary/igbinary)

igbinary is a PECL replacement for PHP `serialize` with a more compact binary. The problem was PHP's verbose native serializer in caches and sessions. igbinary drops duplicate strings and uses a denser layout.

#### [msgpack-pecl](https://github.com/msgpack/msgpack-php)

ext-msgpack is the official PECL MessagePack extension for PHP. MessagePack exists as compact binary JSON. The C extension is the fast path versus userland MessagePack.

#### [rybakit-msgpack](https://github.com/rybakit/msgpack.php) · `v0.9.2`

rybakit/msgpack is a pure-PHP MessagePack implementation. MessagePack exists as compact binary JSON. This package is the userland baseline versus the PECL extension.

#### [protobuf](https://github.com/protocolbuffers/protobuf) · `v4.33.6+php`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [symfony-json](https://github.com/symfony/serializer) · `v7.4.18`

The Symfony Serializer component was created so Symfony apps had a normalizer/encoder pipeline for JSON, XML, and more. The problem was ad-hoc `json_encode` of domain objects. This suite times the JSON and XML encoders.

#### [symfony-xml](https://github.com/symfony/serializer) · `v7.4.18`

The Symfony Serializer component was created so Symfony apps had a normalizer/encoder pipeline for JSON, XML, and more. The problem was ad-hoc `json_encode` of domain objects. This suite times the JSON and XML encoders.

#### [jms-json](https://github.com/schmittjoh/serializer) · `3.32.9`

JMS Serializer was created for PHP applications that needed annotation-driven object serialization (especially APIs). The problem was mapping rich object graphs to JSON. This row times the JSON encoder.

#### [bson](https://github.com/mongodb/mongo-php-driver)

BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.

#### [avro](https://github.com/flix-tech/avro-php) · `5.2.0`

flix-tech/avro-php is a PHP implementation of Apache Avro. Avro exists for compact, schema-driven records. This row times binary Avro (not the object container file format).

#### [cbor](https://github.com/Spomky-Labs/cbor-php) · `3.4.1`

spomky-labs/cbor-php implements RFC 8949 CBOR in PHP. CBOR is the IETF binary JSON-like format. The library is a PHP encoder/decoder of that RFC.

#### [yaml](https://github.com/symfony/yaml) · `v7.4.18`

The Symfony YAML component is a pure-PHP YAML parser/dumper. YAML exists as a human-friendly config language. Symfony YAML is the common userland implementation in PHP apps.

#### [yaml-pecl](https://github.com/php/pecl-file_formats-yaml)

ext-yaml is the PECL binding to LibYAML. YAML exists as a human-friendly config language. The extension is the C-speed path versus Symfony's pure-PHP YAML.

## Not in this suite (and why)

These candidates from the intake lists are **not** rows:

| Candidate | Why not |
|-----------|---------|
| Goridge / RoadRunner | RPC framing, not a fixture codec |
| opis/closure, laravel/serializable-closure | Packs executable closures — not suite data, and a security surface |
| salsify/jsonstreamingparser | Decode-only SAX parser |
| clue/ndjson | Line-delimited stream, different payload |
| Symfony CSV | Nested fixtures are not a CSV table |
| Spatie laravel-data / Laravel serialization | Framework hydrators, not a wire format |
| YAS PHP / AMQP codecs | No official PHP codec for this suite’s fixtures |
| Cap’n Proto PHP | No official PHP runtime |
| FlatBuffers / Thrift PHP | No generated PHP tables in-tree yet (can be added like protobuf) |
| PDO / custom hydrators | Object mapping, not encode/decode of bytes |

[Dashboard](../dashboard/?lang=php&data=document@n=1&mode=bytes)
