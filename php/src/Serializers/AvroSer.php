<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use AvroIOBinaryDecoder;
use AvroIOBinaryEncoder;
use AvroIODatumReader;
use AvroIODatumWriter;
use AvroSchema;
use AvroStringIO;
use Benchmark\ProtoBridge;

final class AvroSer extends BytesSer
{
    private AvroSchema $schema;
    private AvroIODatumWriter $writer;
    private AvroIODatumReader $reader;

    public function name(): string
    {
        return 'avro';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('flix-tech/avro-php') ?? 'flix-tech/avro-php';
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function prepare(mixed $value): void
    {
        [$kind, $batch] = ProtoBridge::detect($value);
        $inner = self::schemaJson($kind);
        $json = $batch ? '{"type":"array","items":' . $inner . '}' : $inner;
        $this->schema = AvroSchema::parse($json);
        $this->writer = new AvroIODatumWriter($this->schema);
        $this->reader = new AvroIODatumReader($this->schema);
    }

    public function serializeBytes(mixed $value): string
    {
        $io = new AvroStringIO();
        $this->writer->write($value, new AvroIOBinaryEncoder($io));
        return $io->string();
    }

    public function deserializeBytes(string $data): mixed
    {
        $io = new AvroStringIO($data);
        return $this->reader->read(new AvroIOBinaryDecoder($io));
    }

    private static function schemaJson(string $kind): string
    {
        return match ($kind) {
            'message' => '{"type":"record","name":"Message","fields":['
                . '{"name":"f_bool","type":"boolean"},'
                . '{"name":"f_int32","type":"int"},'
                . '{"name":"f_int64","type":"long"},'
                . '{"name":"f_float64","type":"double"},'
                . '{"name":"f_string","type":"string"},'
                . '{"name":"f_bool_2","type":"boolean"},'
                . '{"name":"f_int32_2","type":"int"},'
                . '{"name":"f_string_2","type":"string"}]}',
            'document' => '{"type":"record","name":"Document","fields":['
                . '{"name":"id","type":"string"},'
                . '{"name":"status","type":"int"},'
                . '{"name":"meta","type":{"type":"record","name":"DocumentMeta","fields":['
                . '{"name":"region","type":"string"},{"name":"version","type":"int"}]}},'
                . '{"name":"items","type":{"type":"array","items":{"type":"record","name":"DocumentItem","fields":['
                . '{"name":"sku","type":"string"},{"name":"qty","type":"int"},{"name":"price_minor","type":"long"}]}}}]}',
            'telemetry' => '{"type":"record","name":"Telemetry","fields":['
                . '{"name":"source","type":"string"},'
                . '{"name":"ts","type":"long"},'
                . '{"name":"tags","type":{"type":"array","items":"string"}},'
                . '{"name":"values","type":{"type":"array","items":"double"}}]}',
            'strings' => '{"type":"record","name":"Strings","fields":['
                . '{"name":"items","type":{"type":"array","items":"string"}}]}',
            'event' => '{"type":"record","name":"Event","fields":['
                . '{"name":"event_id","type":"string"},'
                . '{"name":"event_type","type":"string"},'
                . '{"name":"occurred_at","type":"long"},'
                . '{"name":"producer","type":"string"},'
                . '{"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":['
                . '{"name":"key","type":"string"},{"name":"value","type":"string"}]}}}]}',
            default => throw new \InvalidArgumentException($kind),
        };
    }
}
