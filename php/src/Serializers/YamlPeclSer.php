<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

final class YamlPeclSer extends BytesSer
{
    public static function available(): bool
    {
        return function_exists('yaml_emit');
    }

    public function name(): string
    {
        return 'yaml-pecl';
    }

    public function version(): string
    {
        return phpversion('yaml') ?: 'yaml';
    }

    public function streamMode(): string
    {
        return 'text_on_stream';
    }

    public function prepare(mixed $value): void
    {
    }

    public function serializeBytes(mixed $value): string
    {
        return yaml_emit($value);
    }

    public function deserializeBytes(string $data): mixed
    {
        return yaml_parse($data);
    }
}
