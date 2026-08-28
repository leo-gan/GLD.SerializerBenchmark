<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

final class MsgpackPeclSer extends BytesSer
{
    public static function available(): bool
    {
        return function_exists('msgpack_pack');
    }

    public function name(): string
    {
        return 'msgpack-pecl';
    }

    public function version(): string
    {
        return phpversion('msgpack') ?: 'msgpack';
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
        return msgpack_pack($value);
    }

    public function deserializeBytes(string $data): mixed
    {
        return msgpack_unpack($data);
    }
}
