---
title: "PHP"
---

PHP
===

PHP’s suite rows cover **stdlib JSON**, **native `serialize`**, optional **PECL** binaries (igbinary, MessagePack, LibYAML, SIMDJSON, MongoDB BSON), **official google/protobuf**, **Symfony** and **JMS** JSON (plus Symfony XML), **Avro**, **CBOR**, and **pure-PHP MessagePack / YAML** as userland baselines.

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
| json | JSON | php-json | text_on_stream | `json_encode` / `json_decode` |
| simdjson | JSON | ext-simdjson | text_on_stream | **Decode only** is SIMDJSON; encode is `json_encode` |
| serialize | Binary | php-serialize | adapted | PHP-only |
| igbinary | Binary | ext-igbinary | adapted | PECL; skip if missing |
| msgpack-pecl | Binary | ext-msgpack | adapted | PECL; skip if missing |
| rybakit-msgpack | Binary | rybakit/msgpack | adapted | Pure PHP MessagePack |
| protobuf | Schema | google/protobuf | adapted | Official generated messages; `+ext` vs `+php` in version |
| symfony-json | JSON | symfony/serializer | text_on_stream | Serializer JSON encoder |
| symfony-xml | Text | symfony/serializer | text_on_stream | Serializer XML encoder |
| jms-json | JSON | jms/serializer | text_on_stream | JMS JSON |
| bson | Binary | ext-mongodb | adapted | Official BSON; skip if missing |
| avro | Schema | flix-tech/avro-php | adapted | Binary Avro (no object container) |
| cbor | Binary | spomky-labs/cbor-php | adapted | RFC 8949 |
| yaml | Text | symfony/yaml | text_on_stream | Pure PHP YAML |
| yaml-pecl | Text | ext-yaml | text_on_stream | LibYAML; skip if missing |

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
