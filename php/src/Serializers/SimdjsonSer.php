<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

/**
 * Encode is stdlib json_encode. Decode is ext-simdjson.
 * Same honesty rule as the C++ simdjson row: the encode is not SIMDJSON.
 */
final class SimdjsonSer extends BytesSer
{
    public static function available(): bool
    {
        return function_exists('simdjson_decode');
    }

    public function name(): string
    {
        return 'simdjson';
    }

    public function version(): string
    {
        return phpversion('simdjson') ?: 'simdjson';
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
        return json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
    }

    public function deserializeBytes(string $data): mixed
    {
        return simdjson_decode($data, true);
    }
}
