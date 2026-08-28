<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

/** PHP-only serialize/unserialize. Other languages cannot read these bytes. */
final class NativeSerializeSer implements Serializer
{
    public function name(): string
    {
        return 'serialize';
    }

    public function version(): string
    {
        return PHP_VERSION;
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function prepare(mixed $value): void
    {
    }

    public function serializeBytes(mixed $value): string
    {
        return serialize($value);
    }

    public function deserializeBytes(string $data): mixed
    {
        return unserialize($data, ['allowed_classes' => false]);
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
            throw new \RuntimeException('serialize stream read failed');
        }
        return $this->deserializeBytes($data);
    }
}
