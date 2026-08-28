<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

final class IgbinarySer extends BytesSer
{
    public static function available(): bool
    {
        return function_exists('igbinary_serialize');
    }

    public function name(): string
    {
        return 'igbinary';
    }

    public function version(): string
    {
        return phpversion('igbinary') ?: 'igbinary';
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
        $out = igbinary_serialize($value);
        if ($out === false) {
            throw new \RuntimeException('igbinary_serialize failed');
        }
        return $out;
    }

    public function deserializeBytes(string $data): mixed
    {
        return igbinary_unserialize($data);
    }
}
