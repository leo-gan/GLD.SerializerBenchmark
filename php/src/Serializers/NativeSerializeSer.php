<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

/** PHP-only serialize/unserialize. Other languages cannot read these bytes. */
final class NativeSerializeSer extends BytesSer
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

    public function serializeBytes(mixed $value): string
    {
        return serialize($value);
    }

    public function deserializeBytes(string $data): mixed
    {
        return unserialize($data, ['allowed_classes' => false]);
    }
}
