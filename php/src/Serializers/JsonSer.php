<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

final class JsonSer implements Serializer
{
    public function name(): string
    {
        return 'json';
    }

    public function version(): string
    {
        return PHP_VERSION;
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
        return json_decode($data, true, 512, JSON_THROW_ON_ERROR);
    }

    public function serializeStream(mixed $value, $out): int
    {
        $bytes = $this->serializeBytes($value);
        fwrite($out, $bytes);
        return strlen($bytes);
    }

    public function deserializeStream($in): mixed
    {
        $data = stream_get_contents($in);
        if ($data === false) {
            throw new \RuntimeException('json stream read failed');
        }
        return $this->deserializeBytes($data);
    }
}
